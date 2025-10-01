# SourceForge 2.0 Shell build
CC       ?= gcc
CFLAGS   ?= -std=c11 -Wall -Wextra -O2
SRC       = sfsh.c
BIN       = sfsh
OVERLAY_BIN = ../overlay/usr/local/bin

all: $(BIN)

$(BIN): $(SRC)
	$(CC) $(CFLAGS) $(SRC) -o $(BIN)

install: $(BIN)
	@mkdir -p $(OVERLAY_BIN)
	@cp -f $(BIN) $(OVERLAY_BIN)/$(BIN)
	@chmod 0755 $(OVERLAY_BIN)/$(BIN)
	@printf '%s\n' '#!/bin/sh' 'exec /usr/local/bin/sfsh "$$@"' > $(OVERLAY_BIN)/chipsh
	@chmod 0755 $(OVERLAY_BIN)/chipsh
	@echo "Installed: $(OVERLAY_BIN)/sfsh and chipsh"

clean:
	@rm -f $(BIN)

distclean: clean
	@rm -f $(OVERLAY_BIN)/sfsh $(OVERLAY_BIN)/chipsh || true

test: install
	@if [ -x ./test_sfsh.sh ]; then ./test_sfsh.sh; else echo "No test_sfsh.sh present; skipping local tests"; fi
