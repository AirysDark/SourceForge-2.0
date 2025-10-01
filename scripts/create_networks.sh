#!/usr/bin/env bash
set -euo pipefail
docker network create frontend || true
docker network create backend || true
