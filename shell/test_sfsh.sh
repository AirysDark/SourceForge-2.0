#!/usr/bin/env bash
set -euo pipefail
BIN="../overlay/usr/local/bin/sfsh"
[[ -x "$BIN" ]] || { echo "sfsh not found at $BIN"; exit 1; }

out="$(printf 'version\nexit\n' | "$BIN" 2>/dev/null || true)"
echo "$out" | tr -d '\r' | grep -q "SourceForge 2.0 Shell" || { echo "version test failed"; exit 1; }

out2="$(printf 'echo __SF_OK__\nexit\n' | "$BIN" 2>/dev/null || true)"
echo "$out2" | tr -d '\r' | grep -q '__SF_OK__' || { echo "echo test failed"; exit 1; }

echo "Local sfsh tests passed"
