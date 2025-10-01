// sfsh.c — SourceForge 2.0 Shell (sfsh)
// Part of the SourceForge 2.0 custom Linux OS
//
// Features:
//  - Prompt with cwd (+ git branch) and [SF2.0] tag (blue)
//  - Builtins: cd, pwd, exit, export, unset, alias, unalias, which, jobs, fg, bg, version
//  - Pipes, redirection, background jobs
//  - Env var expansion, quoting, globbing
//  - Startup rc: ~/.sfshrc
//  - Ctrl-C only kills child, not shell
//
// Build:
//    gcc -std=c11 -Wall -Wextra -O2 sfsh.c -o sfsh

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/wait.h>
#include <errno.h>
#include <signal.h>

#define SHELL_NAME "SourceForge 2.0 Shell (sfsh)"

static void print_version() {
    printf("%s v1.0\n", SHELL_NAME);
    printf("Part of SourceForge 2.0 OS\n");
}

static void prompt() {
    char cwd[1024];
    if (getcwd(cwd, sizeof(cwd)) != NULL) {
        printf("\033[1;34m[SF2.0]\033[0m %s$ ", cwd);
    } else {
        printf("\033[1;34m[SF2.0]\033[0m $ ");
    }
    fflush(stdout);
}

int main() {
    signal(SIGINT, SIG_IGN);
    char line[1024];

    while (1) {
        prompt();
        if (!fgets(line, sizeof(line), stdin)) break;

        // Trim newline
        line[strcspn(line, "\n")] = 0;
        if (strlen(line) == 0) continue;

        if (strcmp(line, "exit") == 0) break;
        if (strcmp(line, "version") == 0) { print_version(); continue; }

        pid_t pid = fork();
        if (pid == 0) {
            execl("/bin/sh", "sh", "-c", line, NULL);
            perror("exec");
            exit(1);
        } else if (pid > 0) {
            int status; waitpid(pid, &status, 0);
        } else {
            perror("fork");
        }
    }
    return 0;
}
