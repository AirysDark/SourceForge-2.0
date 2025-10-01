#!/usr/bin/env bash
# Build a DietPi-based custom image by injecting the OS Pack into the boot partition.
# Requires: xz-utils kpartx dosfstools parted unzip curl
set -euo pipefail

OUTDIR="${1:-dist}"
mkdir -p "$OUTDIR"

: "${DIETPI_IMAGE_URL:=https://dietpi.com/downloads/images/DietPi_RPi-ARMv8-Bookworm.img.xz}"

WORK="$(mktemp -d)"
cleanup() {
  set +e
  if mountpoint -q "$WORK/boot"; then sudo umount "$WORK/boot"; fi
  if [[ -n "${LOOPDEV:-}" ]]; then
    sudo kpartx -d "$LOOPDEV" || true
    sudo losetup -d "$LOOPDEV" || true
  fi
  rm -rf "$WORK"
}
trap cleanup EXIT

echo "[*] Downloading DietPi image: $DIETPI_IMAGE_URL"
IMGXZ="$WORK/dietpi.img.xz"
curl -L "$DIETPI_IMAGE_URL" -o "$IMGXZ"

echo "[*] Decompressing image"
unxz "$IMGXZ"
IMG="${IMGXZ%.xz}"

echo "[*] Mapping partitions"
LOOPDEV=$(sudo losetup --show -fP "$IMG")
sudo kpartx -av "$LOOPDEV" > "$WORK/map.txt"

# Find boot partition (first mapper device ending with 'p1')
MP=$(basename "$LOOPDEV" | sed 's|/dev/||')
BOOT_PART="/dev/mapper/${MP}p1"
mkdir -p "$WORK/boot"
sudo mount "$BOOT_PART" "$WORK/boot"

echo "[*] Injecting OS Pack files into /boot"
sudo cp -r os-pack/* "$WORK/boot/"

# Ensure scripts are executable
sudo chmod +x "$WORK/boot/rootfs/usr/local/sf20/provision.sh" || true
sudo chmod +x "$WORK/boot/rootfs/etc/rc.local" || true

echo "[*] Unmounting and cleaning up"
sudo umount "$WORK/boot"
sudo kpartx -d "$LOOPDEV"
sudo losetup -d "$LOOPDEV"

OUT_IMG="$OUTDIR/sourceforge20-dietpi.img"
mv "$IMG" "$OUT_IMG"

echo "[*] Compressing to .img.xz"
xz -T0 "$OUT_IMG"

echo "[*] Done: ${OUT_IMG}.xz"
