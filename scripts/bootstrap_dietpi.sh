#!/usr/bin/env bash
set -euo pipefail

apt-get update -y
apt-get install -y ca-certificates curl gnupg git jq unzip btrfs-progs ufw fail2ban

# Docker
curl -fsSL https://get.docker.com | sh
systemctl enable --now docker

# Compose v2
mkdir -p /usr/local/lib/docker/cli-plugins
curl -SL https://github.com/docker/compose/releases/download/v2.29.7/docker-compose-linux-aarch64 -o /usr/local/lib/docker/cli-plugins/docker-compose
chmod +x /usr/local/lib/docker/cli-plugins/docker-compose

# Log2RAM
if ! command -v log2ram >/dev/null; then
  curl -s https://raw.githubusercontent.com/azlux/log2ram/master/install.sh | bash
fi

# Firewall
ufw default deny incoming || true
ufw default allow outgoing || true
ufw allow 22/tcp || true
ufw allow 80,443/tcp || true
ufw --force enable || true

# Directories
set +e
source .env
set -e
mkdir -p ${DATA_DIR}/caddy/data ${DATA_DIR}/caddy/config ${DATA_DIR}/runner ${DATA_DIR}/workspaces

# Pre-pull images
make pull || true
