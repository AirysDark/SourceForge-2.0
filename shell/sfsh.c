// sfsh.c - SourceForge 2.0 minimal shell (stub). Replace with your full implementation.
#include <stdio.h>
#include <string.h>

int main(void){
  char buf[256];
  puts("SourceForge 2.0 Shell (sfsh) v1.0");
  puts("Type 'version' or 'exit'");
  while (1){
    printf("[SF2.0] $ ");
    fflush(stdout);
    if(!fgets(buf, sizeof(buf), stdin)) break;
    if(strncmp(buf,"exit",4)==0) break;
    if(strncmp(buf,"version",7)==0){ puts("SourceForge 2.0 Shell"); continue; }
    if(strncmp(buf,"echo ",5)==0){ printf("%s", buf+5); continue; }
  }
  return 0;
}
