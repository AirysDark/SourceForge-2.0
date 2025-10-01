#!/usr/bin/env bash
set -euo pipefail
: "${RESTIC_REPOSITORY:?Set RESTIC_REPOSITORY}"
: "${RESTIC_PASSWORD:?Set RESTIC_PASSWORD}"
restic snapshots
echo "Use 'restic restore <snapshotID> --target /restore' to recover files."
