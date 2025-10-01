// sfsh.c - SourceForge 2.0 Shell (sfsh)
// Minimal interactive shell for SourceForge 2.0 OS.
#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <signal.h>
#include <errno.h>
#include <ctype.h>
#include <limits.h>
#include <sys/wait.h>

#ifndef SF_VERSION
#define SF_VERSION "SourceForge 2.0 Shell (sfsh) v1.0"
#endif

static int interactive = 1;

static void trim(char *s){
    size_t n = strlen(s);
    while(n>0 && (s[n-1]=='\n' || s[n-1]=='\r')) s[--n] = '\0';
    size_t i=0; while(s[i] && isspace((unsigned char)s[i])) i++;
    if(i>0) memmove(s, s+i, strlen(s+i)+1);
    n = strlen(s);
    while(n>0 && isspace((unsigned char)s[n-1])) s[--n] = '\0';
}

static void print_prompt(void){
    if(!interactive) return;
    char cwd[PATH_MAX];
    if(!getcwd(cwd, sizeof(cwd))) strcpy(cwd, "?");
    fprintf(stdout, "[SF2.0] %s$ ", cwd);
    fflush(stdout);
}

static int is_blank(const char *s){
    while(*s){
        if(!isspace((unsigned char)*s)) return 0;
        s++;
    }
    return 1;
}

static int builtin_echo(char *args){
    if(args && *args){
        puts(args);
    } else {
        putchar('\n');
    }
    return 0;
}

static int builtin_cd(char *args){
    const char *path = args && *args ? args : getenv("HOME");
    if(!path) path = "/";
    if(chdir(path) != 0){
        fprintf(stderr, "cd: %s: %s\n", path, strerror(errno));
        return 1;
    }
    return 0;
}

static int builtin_pwd(void){
    char cwd[PATH_MAX];
    if(getcwd(cwd, sizeof(cwd))) puts(cwd);
    else perror("pwd");
    return 0;
}

static int run_system(char *cmd){
    pid_t pid = fork();
    if(pid < 0){
        perror("fork");
        return 1;
    }
    if(pid == 0){
        execl("/bin/sh", "sh", "-c", cmd, (char*)NULL);
        perror("execl");
        _exit(127);
    }
    int status = 0;
    if(waitpid(pid, &status, 0) < 0){
        perror("waitpid");
        return 1;
    }
    if(WIFEXITED(status)) return WEXITSTATUS(status);
    return 1;
}

static void ignore_sigint(int sig){ (void)sig; }

int main(int argc, char **argv){
    (void)argc; (void)argv;
    interactive = isatty(STDIN_FILENO) ? 1 : 0;
    setvbuf(stdout, NULL, _IOLBF, 0);
    signal(SIGINT, ignore_sigint);

    if(interactive){
        puts(SF_VERSION);
        puts("Part of SourceForge 2.0 OS");
    }

    char *line = NULL;
    size_t cap = 0;
    for(;;){
        print_prompt();
        ssize_t n = getline(&line, &cap, stdin);
        if(n < 0){
            break;
        }
        trim(line);
        if(is_blank(line)) continue;

        char *cmd = line;
        char *rest = line;
        while(*rest && !isspace((unsigned char)*rest)) rest++;
        if(*rest){ *rest = '\0'; rest++; while(*rest && isspace((unsigned char)*rest)) rest++; }

        if(strcmp(cmd, "exit")==0 || strcmp(cmd, "quit")==0){
            break;
        } else if(strcmp(cmd, "version")==0){
            puts(SF_VERSION);
        } else if(strcmp(cmd, "echo")==0){
            builtin_echo(rest);
        } else if(strcmp(cmd, "cd")==0){
            builtin_cd(rest);
        } else if(strcmp(cmd, "pwd")==0){
            builtin_pwd();
        } else {
            run_system(line);
        }
    }
    free(line);
    return 0;
}
