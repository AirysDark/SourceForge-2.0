#!/usr/bin/env bash
# sf20-apply-to-rootfs.sh
# Usage: sudo ./scripts/sf20-apply-to-rootfs.sh /mnt/root /mnt/boot
set -euo pipefail

ROOT="${1:-}"
BOOT="${2:-}"

if [[ -z "$ROOT" || -z "$BOOT" ]]; then
  echo "Usage: $0 /path/to/rootfs /path/to/bootfs" >&2
  exit 1
fi

if [[ ! -d "$ROOT" || ! -d "$BOOT" ]]; then
  echo "Both ROOT and BOOT must be directories" >&2
  exit 1
fi

echo "[SF20] Applying overlay → $ROOT"
rsync -a "$(dirname "$0")/../overlay/" "$ROOT/"

echo "[SF20] Applying boot-side → $BOOT/sf20"
mkdir -p "$BOOT/sf20"
rsync -rltD --no-perms --no-owner --no-group --modify-window=2   "$(dirname "$0")/../boot-side/sf20/" "$BOOT/sf20/"

echo "[SF20] Ensuring tty1 override"
mkdir -p "$ROOT/etc/systemd/system/getty@tty1.service.d"
cat > "$ROOT/etc/systemd/system/getty@tty1.service.d/override.conf" <<EOF
[Service]
ExecStart=
ExecStart=-/usr/local/bin/sourceforge-term
EOF

echo "[SF20] Making sure launchers are executable"
chmod +x "$ROOT/usr/local/bin/sourceforge-term" || true
chmod +x "$ROOT/usr/local/bin/sfsh" || true

echo "[SF20] Done."
