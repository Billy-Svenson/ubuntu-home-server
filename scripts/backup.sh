#!/bin/bash
###########################################################
# Vaultwarden Backup Script
# Backs up to router via SCP and Google Drive via rclone
# Add to cron: 0 2 * * * /home/USER/vaultwarden/backup.sh >> /home/USER/vaultwarden/backup.log 2>&1
###########################################################

set -euo pipefail

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="/home/USER/vaultwarden-backups"
BACKUP_FILE="$BACKUP_DIR/vaultwarden_$TIMESTAMP.tar.gz"
ROUTER_IP="YOUR_ROUTER_IP"
ROUTER_PATH="/overlay/vaultwarden-backups"
KEEP_DAYS=30

mkdir -p "$BACKUP_DIR"

# Archive Vaultwarden data volume
docker run --rm \
  --volumes-from vaultwarden \
  -v "$BACKUP_DIR":/backup \
  alpine \
  tar czf "/backup/vaultwarden_$TIMESTAMP.tar.gz" /data

echo "[$(date)] Backup created: $BACKUP_FILE"

# Copy to router via SCP
scp -i /home/USER/.ssh/id_ed25519 \
  "$BACKUP_FILE" \
  "root@$ROUTER_IP:$ROUTER_PATH/"

echo "[$(date)] Backup copied to router"

# Copy to Google Drive via rclone
# Remote name must match exactly what you set during rclone config
rclone copy "$BACKUP_FILE" "Google Drive":vaultwarden-backups/

echo "[$(date)] Backup copied to Google Drive"

# Cleanup local backups older than 30 days
find "$BACKUP_DIR" -name "vaultwarden_*.tar.gz" -mtime +$KEEP_DAYS -delete

# Cleanup router backups
# NOTE: BusyBox find does NOT support -delete — use -exec rm instead
ssh -i /home/USER/.ssh/id_ed25519 root@$ROUTER_IP \
  "find $ROUTER_PATH -name 'vaultwarden_*.tar.gz' -mtime +$KEEP_DAYS -exec rm {} \;"
