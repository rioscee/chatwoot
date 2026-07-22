#!/usr/bin/env bash
# ==============================================================================
# Chatwoot PostgreSQL Automated Monthly Backup to Google Drive (via rclone)
# ==============================================================================
# Usage:
#   1. Install rclone on server: sudo curl https://rclone.org/install.sh | sudo bash
#   2. Configure rclone remote: rclone config (name the remote 'gdrive_chatwoot')
#   3. Make script executable: chmod +x bin/backup_to_gdrive.sh
#   4. Add to crontab: 0 2 1 * * /path/to/chatwoot/bin/backup_to_gdrive.sh >> /var/log/chatwoot_backup.log 2>&1
# ==============================================================================

set -euo pipefail

# Configuration
RCLONE_REMOTE="${RCLONE_REMOTE:-gdrive_chatwoot}"
RCLONE_FOLDER="${RCLONE_FOLDER:-Backups_Chatwoot}"
RETENTION_MONTHS="${RETENTION_MONTHS:-12}"
BACKUP_DIR="${BACKUP_DIR:-/tmp/chatwoot_db_backups}"
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
BACKUP_FILENAME="chatwoot_db_${TIMESTAMP}.sql.gz"
BACKUP_FILEPATH="${BACKUP_DIR}/${BACKUP_FILENAME}"

echo "[$(date)] Starting Chatwoot PostgreSQL backup process..."

# Ensure backup directory exists
mkdir -p "${BACKUP_DIR}"

# 1. Perform PostgreSQL dump
# Auto-detect if running inside Docker container or native PostgreSQL
if command -v docker >/dev/null 2>&1 && docker ps | grep -q "postgres"; then
    POSTGRES_CONTAINER=$(docker ps --filter "name=postgres" --format "{{.ID}}" | head -n 1)
    if [ -z "${POSTGRES_CONTAINER}" ]; then
        POSTGRES_CONTAINER=$(docker ps --filter "ancestor=postgres" --format "{{.ID}}" | head -n 1)
    fi
    echo "[$(date)] Dumping PostgreSQL database from Docker container (${POSTGRES_CONTAINER})..."
    docker exec "${POSTGRES_CONTAINER}" pg_dumpall -U postgres | gzip > "${BACKUP_FILEPATH}"
else
    echo "[$(date)] Dumping PostgreSQL database from host..."
    pg_dumpall -U postgres | gzip > "${BACKUP_FILEPATH}"
fi

# Check backup file size
FILE_SIZE=$(du -h "${BACKUP_FILEPATH}" | cut -f1)
echo "[$(date)] Database backup created successfully: ${BACKUP_FILENAME} (${FILE_SIZE})"

# 2. Upload to Google Drive via rclone
echo "[$(date)] Uploading to Google Drive (${RCLONE_REMOTE}:${RCLONE_FOLDER})..."
rclone copy "${BACKUP_FILEPATH}" "${RCLONE_REMOTE}:${RCLONE_FOLDER}/" --stats 1m

# 3. Clean local temporary backup file
rm -f "${BACKUP_FILEPATH}"
echo "[$(date)] Local temporary file cleaned up."

# 4. Enforce Google Drive retention policy (delete backups older than RETENTION_MONTHS)
RETENTION_DAYS=$((RETENTION_MONTHS * 30))
echo "[$(date)] Enforcing retention policy: Deleting backups older than ${RETENTION_DAYS} days from Google Drive..."
rclone delete "${RCLONE_REMOTE}:${RCLONE_FOLDER}/" --min-age "${RETENTION_DAYS}d"

echo "[$(date)] Backup process completed successfully!"
