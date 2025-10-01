#!/usr/bin/env bash
set -euo pipefail
: "${RESTIC_REPOSITORY:?Set RESTIC_REPOSITORY}"
: "${RESTIC_PASSWORD:?Set RESTIC_PASSWORD}"
: "${DATA_DIR:?Set DATA_DIR}"

DB_DUMP=/tmp/db-$(date +%F).sql
docker exec -i $(docker ps -qf name=mariadb) sh -c 'exec mysqldump --all-databases -uroot -p"$MARIADB_ROOT_PASSWORD"' > "$DB_DUMP"

restic backup \  "$DB_DUMP" \  "${DATA_DIR}/gitea" \  "${DATA_DIR}/runner" \  "${DATA_DIR}/workspaces"

restic forget --keep-daily 7 --keep-weekly 4 --keep-monthly 6 --prune
rm -f "$DB_DUMP"
