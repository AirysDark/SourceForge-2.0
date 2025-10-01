#!/usr/bin/env bash
set -euo pipefail

MODEL="pi4"       # pi3|pi4|pi5
VARIANT="lite"    # lite|full
OUTDIR="dist"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --model) MODEL="$2"; shift 2;;
    --variant) VARIANT="$2"; shift 2;;
    --outdir) OUTDIR="$2"; shift 2;;
    *) echo "Unknown arg $1"; exit 1;;
  esac
done

# Map model -> arch (default sensible)
case "$MODEL" in
  pi3)   TARGET_ARCH="armhf" ;;
  pi4|pi5) TARGET_ARCH="arm64" ;;
  *) echo "Unknown model: $MODEL (use pi3|pi4|pi5)"; exit 1 ;;
esac

mkdir -p "$OUTDIR"

# ---- pi-gen environment controls (make builds deterministic) ----
# Debian + RPi repos (https is fine; pi-gen has the right CA/keyrings)
export DEBIAN_FRONTEND=noninteractive
export USE_QEMU=1
export RELEASE="bookworm"
export TARGET_ARCH
export APT_MIRROR="https://deb.debian.org/debian"
export APT_MIRROR_SECURITY="https://security.debian.org/debian-security"
export RASPBERRYPI_MIRROR="https://archive.raspberrypi.org/debian"

# Image metadata
export IMG_NAME="sourceforge20-${MODEL}-${VARIANT}"
export TARGET_HOSTNAME="sf20"
export LOCALE_DEFAULT="en_AU.UTF-8"
export KEYBOARD_KEYMAP="us"
export TIMEZONE_DEFAULT="Australia/Sydney"

# Minimal stages for a base image; extend as needed
CFG="$(pwd)/pigen.config"
cat > "$CFG" <<EOF
IMG_NAME=${IMG_NAME}
TARGET_HOSTNAME=${TARGET_HOSTNAME}
LOCALE_DEFAULT=${LOCALE_DEFAULT}
KEYBOARD_KEYMAP=${KEYBOARD_KEYMAP}
TIMEZONE_DEFAULT=${TIMEZONE_DEFAULT}
ENABLE_SSH=1
FIRST_USER_NAME=pi
STAGE_LIST="stage0 stage1"
EOF

# Fetch pi-gen (pin master/bookworm head)
if [[ ! -d pi-gen ]]; then
  git clone --depth=1 https://github.com/RPi-Distro/pi-gen.git
fi

# Put config where pi-gen expects it
cp "$CFG" pi-gen/config

# Build (Docker mode)
pushd pi-gen >/dev/null
set +e
./build-docker.sh
status=$?
set -e

# If it failed early, try to show debootstrap logs to aid debugging
if [[ $status -ne 0 ]]; then
  echo "::warning::pi-gen build failed; attempting to print debootstrap logs"
  find work -type f -name 'debootstrap.log' -maxdepth 4 -print -exec tail -n +1 {} \; || true
  exit $status
fi
popd >/dev/null

# Collect output (img/zip/xz depending on pi-gen)
mkdir -p "${OUTDIR}"
shopt -s nullglob
for f in pi-gen/deploy/*.{img,zip,xz}; do
  cp "$f" "${OUTDIR}/"
done
echo "Image(s) placed in ${OUTDIR}"