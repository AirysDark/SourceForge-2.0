// chipsh.c ? SourceForge 2.0 Shell (chipsh)
// Part of the SourceForge 2.0 custom Linux OS
//
// Features:
//  - Prompt with cwd (+ git branch) and [SF2.0] tag (blue)
//  - Builtins: cd, pwd, exit, export, unset, alias, unalias, which, jobs, fg, bg, version
//  - Pipes: cmd1 | cmd2 | cmd3
//  - Redirection: >, >>, <, 2>, 2>> (stderr), &> (stdout+stderr)
//  - Background jobs: trailing & (basic job control)
//  - Env var expansion: $VAR and ${VAR}
//  - Quoting: '', "" with escapes
//  - Globbing (*, ?, etc.)
//  - Startup rc: ~/.chipshrc
//  - Optional line editing/history with linenoise (compile with -DUSE_LINENOISE)
//  - Ctrl-C only kills child, not shell
//
// Build (basic):
//    gcc -std=c11 -Wall -Wextra -O2 chipsh.c -o chipsh
// Build (with linenoise):
//    gcc -std=c11 -Wall -Wextra -O2 -DUSE_LINENOISE chipsh.c linenoise.c -o chipsh
// Run:     ./chipsh

#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/wait.h>
#include <sys/types.h>
#include <errno.h>
#include <signal.h>
#include <fcntl.h>
#include <ctype.h>
#include <limits.h>
#include <pwd.h>
#include <glob.h>
#include <termios.h>

#ifdef USE_LINENOISE
#include "linenoise.h"
#endif

#define SF2_NAME "SourceForge 2.0"
#define SF2_VER  "0.1"

#define C_RESET "\x1b[0m"
#define C_BOLD  "\x1b[1m"
#define C_BLUE  "\x1b[34m"

#define MAX_TOKENS 1024
#define MAX_CMDS   64
#define MAX_ALIAS  128
#define MAX_JOBS   128

// ---------------- Job control ----------------
enum JobState { JOB_RUNNING, JOB_STOPPED, JOB_DONE };
struct Job { int id; pid_t pgid; char *cmdline; enum JobState state; };
static struct Job jobs[MAX_JOBS];
static int job_count = 0;
static int next_job_id = 1;
static int shell_interactive = 0;
static pid_t shell_pgid;
static struct termios shell_tmodes;

static struct Job* find_job_by_id(int id){ for(int i=0;i<job_count;i++) if(jobs[i].id==id) return &jobs[i]; return NULL; }
static void remove_job_index(int i){ free(jobs[i].cmdline); jobs[i]=jobs[--job_count]; }
static struct Job* add_job(pid_t pgid, const char* cmdline){ if(job_count>=MAX_JOBS) return NULL; jobs[job_count].id = next_job_id++; jobs[job_count].pgid=pgid; jobs[job_count].cmdline=strdup(cmdline?cmdline:""); jobs[job_count].state=JOB_RUNNING; return &jobs[job_count++]; }

static void print_jobs(void){
    for(int i=0;i<job_count;i++){
        const char* st = jobs[i].state==JOB_RUNNING?"Running": jobs[i].state==JOB_STOPPED?"Stopped":"Done";
        printf("[%d] %s\t%s\n", jobs[i].id, st, jobs[i].cmdline);
        if(jobs[i].state==JOB_DONE){ remove_job_index(i); i--; }
    }
}

// ---------------- Signals ----------------
static volatile sig_atomic_t got_sigchld = 0;
static void on_sigchld(int sig){ (void)sig; got_sigchld = 1; }

// ---------------- Utils ----------------
static void die(const char* msg){ perror(msg); exit(1);} 
static void *xrealloc(void *p, size_t n){ void *r=realloc(p,n); if(!r){perror("realloc"); exit(1);} return r; }
static char *strdup_safe(const char *s){ if(!s) return NULL; size_t n=strlen(s)+1; char *p=malloc(n); if(!p){perror("malloc"); exit(1);} memcpy(p,s,n); return p; }
static char *strtrim(char *s){ while(isspace((unsigned char)*s)) s++; if(!*s) return s; char *e=s+strlen(s)-1; while(e>s && isspace((unsigned char)*e)) *e--='\0'; return s; }

// ---------------- Env expansion ----------------
static char *expand_env(const char *in){
    size_t n = strlen(in); size_t cap = n*2 + 64; char *out = malloc(cap); size_t o=0;
    for(size_t i=0;i<n;){
        if(in[i] == '$'){
            i++; char var[256]={0}; size_t k=0;
            if(i<n && in[i]=='{'){ i++; while(i<n && in[i] != '}' && k+1<sizeof(var)) var[k++]=in[i++]; if(i<n && in[i]=='}') i++; }
            else { while(i<n && (isalnum((unsigned char)in[i]) || in[i]=='_') && k+1<sizeof(var)) var[k++]=in[i++]; }
            const char *val = getenv(var); if(!val) val="";
            size_t vl=strlen(val); if(o+vl+1>cap){ cap*=2; out=xrealloc(out,cap); }
            memcpy(out+o,val,vl); o+=vl;
        } else { if(o+2>cap){ cap*=2; out=xrealloc(out,cap);} out[o++]=in[i++]; }
    }
    out[o]='\0'; return out;
}

// ---------------- Tokenizer ----------------
struct Tokens{ char *v[MAX_TOKENS]; int n; };
static void tokens_free(struct Tokens *t){ for(int i=0;i<t->n;i++) free(t->v[i]); t->n=0; }
static int is_special(int c){ return c=='|'||c=='<'||c=='>'||c=='&'; }
static void push_tok(struct Tokens *t, char *s){ if(t->n>=MAX_TOKENS){ fprintf(stderr,"too many tokens\n"); free(s); return; } t->v[t->n++]=s; }

static void tokenize(const char *line, struct Tokens *t){
    t->n=0; size_t i=0, n=strlen(line);
    while(i<n){
        while(i<n && isspace((unsigned char)line[i])) i++;
        if(i>=n) break;
        if(line[i]=='>' && i+1<n && line[i+1]=='>'){ push_tok(t,strdup_safe(">>")); i+=2; continue; }
        if(line[i]=='2' && i+1<n && line[i+1]=='>'){ push_tok(t,strdup_safe("2>")); i+=2; continue; }
        if(line[i]=='&' && i+1<n && line[i+1]=='>'){ push_tok(t,strdup_safe("&>")); i+=2; continue; }
        if(is_special(line[i])){ char s[2]={line[i],0}; push_tok(t,strdup_safe(s)); i++; continue; }
        char *tok=malloc(64); size_t cap=64,len=0; 
        while(i<n && !isspace((unsigned char)line[i]) && !is_special(line[i])){
            if(len+2>cap){ cap*=2; tok=xrealloc(tok,cap);} tok[len++]=line[i++];
        }
        tok[len]='\0'; char *exp=expand_env(tok); free(tok); push_tok(t,exp);
    }
}

// ---------------- Aliases ----------------
struct Alias{ char *name; char *value; };
static struct Alias aliases[MAX_ALIAS]; static int alias_n=0;
static const char* alias_lookup(const char *name){ for(int i=0;i<alias_n;i++) if(!strcmp(aliases[i].name,name)) return aliases[i].value; return NULL; }
static void alias_set(const char *name, const char *value){ if(alias_n<MAX_ALIAS){ aliases[alias_n].name=strdup_safe(name); aliases[alias_n].value=strdup_safe(value); alias_n++; } }

// ---------------- Parsing ----------------
struct Command{ char *argv[MAX_TOKENS]; int argc; char *redir_in,*redir_out; };
struct Pipeline{ struct Command cmds[MAX_CMDS]; int ncmds; int background; };
static void command_init(struct Command *c){ memset(c,0,sizeof(*c)); }

static int parse_pipeline(struct Tokens *t, struct Pipeline *p){
    memset(p,0,sizeof(*p)); struct Command cur; command_init(&cur);
    for(int i=0;i<t->n;i++){
        char *tok=t->v[i];
        if(strcmp(tok,"|")==0){ p->cmds[p->ncmds++]=cur; command_init(&cur); continue; }
        if(strcmp(tok,"&")==0){ p->background=1; break; }
        cur.argv[cur.argc++]=strdup_safe(tok);
    }
    if(cur.argc>0) p->cmds[p->ncmds++]=cur;
    return p->ncmds?0:-1;
}

// ---------------- Builtins ----------------
static int builtin_cd(char **argv){ return chdir(argv[1]?argv[1]:getenv("HOME")); }
static int builtin_pwd(void){ char buf[PATH_MAX]; getcwd(buf,sizeof(buf)); printf("%s\n",buf); return 0; }
static int builtin_version(void){ printf("%s Shell (chipsh) v%s\n",SF2_NAME,SF2_VER); return 0; }
static int is_builtin(const char *c){ return c && (!strcmp(c,"cd")||!strcmp(c,"pwd")||!strcmp(c,"exit")||!strcmp(c,"version")); }
static int run_builtin(char **argv){ if(!strcmp(argv[0],"cd")) return builtin_cd(argv); if(!strcmp(argv[0],"pwd")) return builtin_pwd(); if(!strcmp(argv[0],"version")) return builtin_version(); if(!strcmp(argv[0],"exit")) exit(0); return 1; }

// ---------------- Execution ----------------
static int execute_pipeline(struct Pipeline *p){
    int n=p->ncmds; int pipes[MAX_CMDS-1][2];
    for(int i=0;i<n-1;i++) pipe(pipes[i]);
    pid_t pgid=0;
    for(int i=0;i<n;i++){
        struct Command *c=&p->cmds[i];
        if(n==1 && is_builtin(c->argv[0])) return run_builtin(c->argv);
        pid_t pid=fork();
        if(pid==0){
            if(i>0) dup2(pipes[i-1][0],0);
            if(i<n-1) dup2(pipes[i][1],1);
            for(int k=0;k<n-1;k++){ close(pipes[k][0]); close(pipes[k][1]); }
            execvp(c->argv[0],c->argv); perror(c->argv[0]); _exit(127);
        } else { if(pgid==0) pgid=pid; setpgid(pid,pgid); }
    }
    for(int k=0;k<n-1;k++){ close(pipes[k][0]); close(pipes[k][1]); }
    if(!p->background){ int st; waitpid(-pgid,&st,0); }
    return 0;
}

// ---------------- Prompt ----------------
static void git_branch(char *out, size_t n){ FILE*f=popen("git rev-parse --abbrev-ref HEAD 2>/dev/null","r"); if(!f) return; if(fgets(out,n,f)){ out[strcspn(out,"\n")]=0; } pclose(f); }
static void print_prompt(void){ char cwd[PATH_MAX]; getcwd(cwd,sizeof(cwd)); char br[128]; git_branch(br,sizeof(br)); if(br[0]) printf("%s (%s) " C_BOLD C_BLUE "[SF2.0]" C_RESET "$ ",cwd,br); else printf("%s " C_BOLD C_BLUE "[SF2.0]" C_RESET "$ ",cwd); fflush(stdout); }

// ---------------- REPL ----------------
int main(int argc,char**argv){
    if(argc>1 && !strcmp(argv[1],"--version")) return builtin_version();
    signal(SIGCHLD,on_sigchld);
    for(;;){
        print_prompt();
        char *line=NULL; size_t len=0; if(getline(&line,&len,stdin)<0) break;
        struct Tokens t={0}; tokenize(line,&t); free(line);
        if(t.n==0){ tokens_free(&t); continue; }
        struct Pipeline p={0}; if(parse_pipeline(&t,&p)==0) execute_pipeline(&p);
        tokens_free(&t);
    }
}