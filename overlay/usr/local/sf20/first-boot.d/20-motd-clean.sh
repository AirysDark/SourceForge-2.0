#!/bin/bash
set -euo pipefail
dir="/etc/update-motd.d"
if [ -d "$dir" ]; then
  for f in "$dir"/*; do
    base="$(basename "$f")"
    case "$base" in
      00-sf20) ;;
      *) chmod -x "$f" 2>/dev/null || true ;;
    esac
  done
fi
