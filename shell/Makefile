CC?=cc
CFLAGS?=-std=c11 -Wall -Wextra -O2
all: sfsh
sfsh: sfsh.c
	$(CC) $(CFLAGS) sfsh.c -o sfsh
install: sfsh
	mkdir -p ../overlay/usr/local/bin
	cp -f sfsh ../overlay/usr/local/bin/sfsh
	chmod +x ../overlay/usr/local/bin/sfsh
clean:
	rm -f sfsh
