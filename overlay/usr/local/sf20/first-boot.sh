#!/usr/bin/env bash
set -euo pipefail
MARKER=/var/lib/sf20/firstboot.done
if [ -f "$MARKER" ]; then
  exit 0
fi
mkdir -p /var/lib/sf20
# first boot tasks go here
touch "$MARKER"
