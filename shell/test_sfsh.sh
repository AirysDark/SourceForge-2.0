#!/usr/bin/env bash
set -euo pipefail

BIN="../overlay/usr/local/bin/sfsh"
[[ -x "$BIN" ]] || { echo "sfsh not found at $BIN"; exit 1; }

echo "✅ sfsh binary exists"

# Check 'version' builtin
out="$(printf "version\n" | "$BIN" 2>/dev/null || true)"
if grep -q "SourceForge 2.0 Shell" <<<"$out"; then
  echo "✅ version builtin OK"
else
  echo "❌ version builtin failed"
  echo "$out"
  exit 1
fi

# Check simple command execution
out="$(printf "echo hello\n" | "$BIN" 2>/dev/null || true)"
if grep -q "^hello$" <<<"$out"; then
  echo "✅ echo OK"
else
  echo "❌ echo failed"
  echo "$out"
  exit 1
fi

echo "All sfsh tests passed ✅"