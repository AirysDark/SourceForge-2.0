#!/usr/bin/env bash
# Simple smoke test for SourceForge 2.0 Shell (sfsh)

set -euo pipefail

BIN="../overlay/usr/local/bin/sfsh"

if [[ ! -x "$BIN" ]]; then
  echo "ERROR: sfsh binary not found at $BIN"
  exit 1
fi

echo "✅ sfsh binary exists"

# Run version check
out=$("$BIN" -c "version" 2>&1 || true)
if [[ "$out" == *"SourceForge 2.0 Shell"* ]]; then
  echo "✅ version command works"
else
  echo "❌ version command failed"
  echo "$out"
  exit 1
fi

# Run a simple echo command
out=$("$BIN" -c "echo hello" 2>&1 || true)
if [[ "$out" == "hello" ]]; then
  echo "✅ echo works"
else
  echo "❌ echo failed"
  echo "$out"
  exit 1
fi

echo "All sfsh tests passed ✅"