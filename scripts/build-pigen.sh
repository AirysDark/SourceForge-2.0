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

mkdir -p "$OUTDIR"
export IMG_NAME="sourceforge20-${MODEL}-${VARIANT}"
export TARGET_HOSTNAME="sf20"
export LOCALE_DEFAULT="en_AU.UTF-8"
export KEYBOARD_KEYMAP="us"
export TIMEZONE_DEFAULT="Australia/Sydney"

# Write config to a non-conflicting file
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

# Fetch pi-gen if not already there
if [[ ! -d pi-gen ]]; then
  git clone https://github.com/RPi-Distro/pi-gen.git --depth=1
fi

# Copy config file into pi-gen
cp "$CFG" pi-gen/config

cd pi-gen
./build-docker.sh

# Collect output (img/zip/xz depending on pi-gen)
mkdir -p "../${OUTDIR}"
shopt -s nullglob
for f in deploy/*.{img,zip,xz}; do
  cp "$f" "../${OUTDIR}/"
done

echo "Image(s) placed in ${OUTDIR}"