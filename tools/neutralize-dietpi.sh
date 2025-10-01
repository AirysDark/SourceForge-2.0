#!/usr/bin/env bash
set -euxo pipefail
ROOT="${ROOT:-/mnt/imgroot}"
BOOT="${BOOT:-/mnt/imgboot}"

echo "== [SF20] Mask DietPi boot pipeline =="
for svc in dietpi-preboot dietpi-boot dietpi-firstboot dietpi-postboot dietpi-wifi-monitor dietpi-wait-for-network; do
  if [[ -f "$ROOT/etc/systemd/system/${svc}.service" || -f "$ROOT/lib/systemd/system/${svc}.service" ]]; then
    systemctl --root="$ROOT" disable "${svc}" || true
    ln -sf /dev/null "$ROOT/etc/systemd/system/${svc}.service" || true
    echo "masked ${svc}"
  fi
done

echo "== [SF20] Own tty1 =="
systemctl --root="$ROOT" disable getty@tty1.service || true
ln -sf /dev/null "$ROOT/etc/systemd/system/getty@tty1.service" || true
systemctl --root="$ROOT" enable sf20-terminal-tty1.service || true

echo "== [SF20] Make sfsh the root shell =="
if [[ -f "$ROOT/etc/passwd" ]]; then
  cp "$ROOT/etc/passwd" "$ROOT/etc/passwd.sf20.bak"
  awk -F: 'BEGIN{OFS=":"} $1=="root"{ $7="/usr/local/bin/sfsh" } {print}' "$ROOT/etc/passwd.sf20.bak" >"$ROOT/etc/passwd.tmp"
  mv "$ROOT/etc/passwd.tmp" "$ROOT/etc/passwd"
fi

echo "== [SF20] Remove DietPi branding =="
rm -f "$ROOT/etc/update-motd.d/"*dietpi* 2>/dev/null || true
echo "SourceForge 2.0 OS" > "$ROOT/etc/issue"
echo "SourceForge 2.0 OS" > "$ROOT/etc/issue.net"
rm -f "$ROOT/etc/profile.d/"*dietpi* 2>/dev/null || true
rm -f "$BOOT/dietpi.txt" "$BOOT/dietpi-wifi.txt" 2>/dev/null || true

echo "== [SF20] Ensure binaries are executable =="
chmod +x "$ROOT/usr/local/bin/sourceforge-term" || true
chmod +x "$ROOT/usr/local/bin/sfsh" || true

echo "== [SF20] Set Plymouth theme (if present) =="
if [[ -f "$ROOT/usr/share/plymouth/themes/sourceforge/sourceforge.plymouth" ]]; then
  mkdir -p "$ROOT/etc/plymouth"
  cat > "$ROOT/etc/plymouth/plymouthd.conf" <<EOF
[Daemon]
Theme=sourceforge
EOF
fi

echo "== [SF20] Summary =="
grep '^root:' "$ROOT/etc/passwd" || true
systemctl --root="$ROOT" list-unit-files | grep -E 'sf20|dietpi|getty@tty1' || true
