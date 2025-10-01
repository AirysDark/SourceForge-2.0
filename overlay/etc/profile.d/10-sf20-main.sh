#!/bin/sh
# Print SF20 banner if present
if [ -f /usr/local/sf20/banner.txt ]; then
  cat /usr/local/sf20/banner.txt
fi
