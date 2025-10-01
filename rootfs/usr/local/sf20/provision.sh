#!/usr/bin/env bash
set -euo pipefail

log() { echo "[sf20] $*"; }

# Defaults
DOMAIN="${DOMAIN:-sf20.local}"
EMAIL="${EMAIL:-admin@sf20.local}"
TZ="${TZ:-Australia/Sydney}"
DATA_DIR="${DATA_DIR:-/srv/sf20}"

log "Starting provisioning..."

# Basic deps
apt-get update -y
apt-get install -y ca-certificates curl gnupg git jq unzip ufw fail2ban btrfs-progs

# Docker
if ! command -v docker >/dev/null 2>&1; then
  curl -fsSL https://get.docker.com | sh
  systemctl enable --now docker
fi

# Compose v2
mkdir -p /usr/local/lib/docker/cli-plugins
if [ ! -x /usr/local/lib/docker/cli-plugins/docker-compose ]; then
  arch="$(uname -m)"
  case "$arch" in
    aarch64) url="https://github.com/docker/compose/releases/download/v2.29.7/docker-compose-linux-aarch64" ;;
    armv7l)  url="https://github.com/docker/compose/releases/download/v2.29.7/docker-compose-linux-armv7" ;;
    x86_64)  url="https://github.com/docker/compose/releases/download/v2.29.7/docker-compose-linux-x86_64" ;;
    *) echo "Unsupported arch $arch"; exit 1 ;;
  esac
  curl -SL "$url" -o /usr/local/lib/docker/cli-plugins/docker-compose
  chmod +x /usr/local/lib/docker/cli-plugins/docker-compose
fi

# Log2RAM to reduce writes
if ! command -v log2ram >/dev/null; then
  curl -s https://raw.githubusercontent.com/azlux/log2ram/master/install.sh | bash || true
fi

# Firewall
ufw default deny incoming || true
ufw default allow outgoing || true
ufw allow 22/tcp || true
ufw allow 80,443/tcp || true
ufw --force enable || true

# Branding
install -d /etc/update-motd.d
echo "SourceForge 2.0 — DietPi Appliance" > /etc/motd
echo "Welcome to SourceForge 2.0 (sf20) — https://gitea.${DOMAIN}" > /etc/issue

# Prepare data dirs
mkdir -p ${DATA_DIR}/caddy/{data,config} ${DATA_DIR}/runner ${DATA_DIR}/workspaces

# If infra zip present on /boot, install it
BOOT_INFRA="/boot/sf20/sourceforge20-infra.zip"
DEST="/opt/sourceforge20-infra"
if [ -f "$BOOT_INFRA" ]; then
  log "Found infra zip at $BOOT_INFRA — installing..."
  rm -rf "$DEST"
  mkdir -p "$DEST"
  unzip -q "$BOOT_INFRA" -d /opt
  if [ ! -f "$DEST/.env" ] && [ -f "$DEST/.env.example" ]; then
    cp "$DEST/.env.example" "$DEST/.env"
    sed -i "s|^DOMAIN=.*|DOMAIN=${DOMAIN}|g" "$DEST/.env" || true
    sed -i "s|^EMAIL=.*|EMAIL=${EMAIL}|g" "$DEST/.env" || true
    sed -i "s|^TZ=.*|TZ=${TZ}|g" "$DEST/.env" || true
    sed -i "s|^DATA_DIR=.*|DATA_DIR=${DATA_DIR}|g" "$DEST/.env" || true
  fi
  cd "$DEST"
  # Create networks first
  ./scripts/create_networks.sh || true
  # Bootstrap + bring up
  ./scripts/bootstrap_dietpi.sh || true
  make up || true
else
  log "No infra zip found at $BOOT_INFRA. You can copy it and run: systemctl start sf20-provision"
fi

log "Provisioning complete."
