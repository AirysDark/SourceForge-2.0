#!/usr/bin/env bash
set -euo pipefail
docker compose -f compose/runner.yml up -d
