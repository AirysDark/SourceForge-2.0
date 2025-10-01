# SourceForge 2.0 Infra

DietPi-based platform bringing up: Gitea + MariaDB + Runner, OpenVSCode Server, Caddy+Authelia, MinIO, Redis, Prometheus/Grafana/Loki, Restic backups.

## Quickstart
1. Flash DietPi (64-bit) to USB SSD. Boot device as `sf20`.
2. SSH in and run:
   ```bash
   sudo -i
   apt-get update -y && apt-get install -y curl git
   git clone <THIS REPO> /opt/sourceforge20-infra
   cd /opt/sourceforge20-infra
   cp .env.example .env && nano .env
   ./scripts/bootstrap_dietpi.sh
   make up
   ```
3. Visit `https://gitea.${DOMAIN}` after DNS/hosts is set.
