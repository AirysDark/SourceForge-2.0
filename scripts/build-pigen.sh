#!/usr/bin/env bash
set -euo pipefail

# ===== user inputs =====
MODEL="pi4"       # pi3|pi4|pi5 (we'll force arm64 for all)
VARIANT="lite"    # lite|full
OUTDIR="dist"
NO_GPG="false"    # if "true", pass --no-check-gpg to debootstrap (last resort for CI mirror flakiness)

while [[ $# -gt 0 ]]; do
  case "$1" in
    --model)   MODEL="$2"; shift 2;;
    --variant) VARIANT="$2"; shift 2;;
    --outdir)  OUTDIR="$2"; shift 2;;
    --no-gpg)  NO_GPG="$2"; shift 2;;
    *) echo "Unknown arg $1"; exit 1;;
  esac
done

# ===== 64-bit only =====
TARGET_ARCH="arm64"   # force 64-bit for pi3/pi4/pi5
mkdir -p "$OUTDIR"

# ===== deterministic pi-gen env =====
export DEBIAN_FRONTEND=noninteractive
export USE_QEMU=1
export RELEASE="bookworm"
export TARGET_ARCH
# Debian + RPi mirrors
export APT_MIRROR="https://deb.debian.org/debian"
export APT_MIRROR_SECURITY="https://security.debian.org/debian-security"
export RASPBERRYPI_MIRROR="https://archive.raspberrypi.org/debian"

# Optional: disable GPG checks if CI hits "Invalid Release signature"
if [[ "${NO_GPG}" == "true" ]]; then
  export DEBOOTSTRAP_EXTRA_FLAGS="--no-check-gpg"
fi

# Image metadata
export IMG_NAME="sourceforge20-${MODEL}-${VARIANT}-arm64"
export TARGET_HOSTNAME="sf20"
export LOCALE_DEFAULT="en_AU.UTF-8"
export KEYBOARD_KEYMAP="us"
export TIMEZONE_DEFAULT="Australia/Sydney"

# Minimal stages for base image
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

# ===== fetch & configure pi-gen =====
if [[ ! -d pi-gen ]]; then
  git clone --depth=1 https://github.com/RPi-Distro/pi-gen.git
fi
cp "$CFG" pi-gen/config

# ===== build (Docker mode) =====
pushd pi-gen >/dev/null
set +e
./build-docker.sh
status=$?
set -e
if [[ $status -ne 0 ]]; then
  echo "::warning::pi-gen build failed; attempting to print debootstrap logs"
  # new work tree names differ by IMG_NAME; list any logs
  find work -type f -name 'debootstrap.log' -print -exec tail -n +200 {} \; || true
  exit $status
fi
popd >/dev/null

# ===== collect artifacts =====
mkdir -p "${OUTDIR}"
shopt -s nullglob
for f in pi-gen/deploy/*.{img,zip,xz}; do
  cp "$f" "${OUTDIR}/"
done
echo "Image(s) placed in ${OUTDIR}"