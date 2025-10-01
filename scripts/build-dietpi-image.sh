#!/usr/bin/env bash
# Build a DietPi-based custom image by injecting the OS Pack into the boot partition.
# Uses local base images in dietpi-base/ instead of downloading.
# Requires: xz-utils kpartx dosfstools parted unzip

set -euo pipefail

MODEL="${1:-pi4}"     # pi3/pi4 or pi5
OUTDIR="${2:-dist}"
mkdir -p "$OUTDIR"

case "$MODEL" in
  pi3|pi4)
    BASE_IMG="dietpi-base/DietPi_RPi234-ARMv8-Trixie.img.xz"
    ;;
  pi5)
    BASE_IMG="dietpi-base/DietPi_RPi5-ARMv8-Trixie.img.xz"
    ;;
  *)
    echo "Unknown model: $MODEL (use pi3, pi4, or pi5)"
    exit 1
    ;;
esac

if [ ! -f "$BASE_IMG" ]; then
  echo "Base image not found: $BASE_IMG"
  exit 1
fi

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

echo "[*] Copying base image $BASE_IMG"
IMGXZ="$WORK/dietpi.img.xz"
cp "$BASE_IMG" "$IMGXZ"

echo "[*] Decompressing image"
unxz "$IMGXZ"
IMG="${IMGXZ%.xz}"

echo "[*] Mapping partitions"
LOOPDEV=$(sudo losetup --show -fP "$IMG")
sudo kpartx -av "$LOOPDEV" > "$WORK/map.txt"

# Boot partition = first partition (p1)
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

OUT_IMG="$OUTDIR/sourceforge20-${MODEL}-dietpi.img"
mv "$IMG" "$OUT_IMG"

echo "[*] Compressing to .img.xz"
xz -T0 "$OUT_IMG"

echo "[*] Done: ${OUT_IMG}.xz"