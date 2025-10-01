#!/bin/bash
# SourceForge 2.0 login hook

# One-time autologin cleanup after first boot
if [ -f /etc/systemd/system/getty@tty1.service.d/override.conf ]; then
  mkdir -p /var/lib/sf20
  if [ ! -f /var/lib/sf20/autologin.cleaned ]; then
    rm -f /etc/systemd/system/getty@tty1.service.d/override.conf
    systemctl daemon-reexec || true
    touch /var/lib/sf20/autologin.cleaned
  fi
fi

# Launch SourceForge menu at login
if [ -z "$SF20_MENU_SHOWN" ]; then
  export SF20_MENU_SHOWN=1
  /usr/local/bin/sourceforge-term
fi
