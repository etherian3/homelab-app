#!/usr/bin/env bash

set -euo pipefail

BACKUP_DIR="/opt/backups/postgres"
REMOTE_HOST="ether@192.168.1.110"
REMOTE_DIR="/opt/backups/homelab/postgres"
SSH_KEY="/home/ether/.ssh/postgres_backup"

CONTAINER="homelab-postgres"
DATABASE="homelab"
USER="homelab"

TIMESTAMP="$(date '+%Y-%m-%d_%H-%M-%S')"
BACKUP_FILE="${BACKUP_DIR}/backup-${TIMESTAMP}.sql.gz"

mkdir -p "$BACKUP_DIR"

echo "Starting PostgreSQL backup..."

docker exec "$CONTAINER" \
    pg_dump -U "$USER" -d "$DATABASE" \
    | gzip > "$BACKUP_FILE"

if [[ ! -s "$BACKUP_FILE" ]]; then
    echo "ERROR: Backup file is empty."
    rm -f "$BACKUP_FILE"
    exit 1
fi

echo "Backup created:"
echo "  $BACKUP_FILE"

echo "Backup size:"
du -h "$BACKUP_FILE"

echo "Verifying gzip archive..."

gzip -t "$BACKUP_FILE"

echo "Backup verification successful."

echo "Copying backup to remote storage..."

scp \
    -i "$SSH_KEY" \
    -o IdentitiesOnly=yes \
    "$BACKUP_FILE" \
    "${REMOTE_HOST}:${REMOTE_DIR}/"

echo "Remote backup uploaded successfully."

echo "Verifying remote backup..."

ssh \
    -i "$SSH_KEY" \
    -o IdentitiesOnly=yes \
    "$REMOTE_HOST" \
    "gzip -t '${REMOTE_DIR}/$(basename "$BACKUP_FILE")'"

echo "Remote backup verification successful."

echo "Removing local backups older than 7 days..."

find "$BACKUP_DIR" \
    -type f \
    -name 'backup-*.sql.gz' \
    -mtime +7 \
    -delete

echo "Removing remote backups older than 14 days..."

ssh \
    -i "$SSH_KEY" \
    -o IdentitiesOnly=yes \
    "$REMOTE_HOST" \
    "find '$REMOTE_DIR' -type f -name 'backup-*.sql.gz' -mtime +14 -delete"

echo "Local backups:"
ls -lh "$BACKUP_DIR"

echo "Remote backups:"
ssh \
    -i "$SSH_KEY" \
    -o IdentitiesOnly=yes \
    "$REMOTE_HOST" \
    "ls -lh '$REMOTE_DIR'"

echo "PostgreSQL backup completed successfully."
