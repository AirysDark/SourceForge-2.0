# SourceForge 2.0 Shell build
# Location: repo-root/shell/Makefile
# Usage:
#   make            # build sfsh locally
#   make install    # put sfsh + chipsh wrapper into overlay/usr/local/bin
#   make clean      # remove local build artifacts
#   make distclean  # also remove installed overlay binaries

# --- Config ---
CC       ?= gcc
CFLAGS   ?= -std=c11 -Wall -Wextra -O2
SRC       = sfsh.c
BIN       = sfsh

# Overlay install target inside repo
OVERLAY_BIN = ../overlay/usr/local/bin

# --- Rules ---
all: $(BIN)
test: install
	./test_sfsh.sh

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