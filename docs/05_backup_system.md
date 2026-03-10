###########################################################
# Vaultwarden Backup System
# Daily automated backup → Flint 2 Router + Google Drive
###########################################################

################# - Architecture - ########################
# Source:       Vaultwarden Docker volume (/data)
# Local stage:  /home/USER/vaultwarden-backups/
# Destination 1: Flint 2 router → /overlay/vaultwarden-backups/
# Destination 2: Google Drive → vaultwarden-backups/ folder
# Schedule:     Daily at 2:00 AM UTC
# Retention:    30 days on both destinations
# Backup size:  ~8.7KB per backup

###########################################################
# Step 1 — Verify Router Has Space
###########################################################

ssh root@YOUR_ROUTER_IP "df -h /overlay"
# → Filesystem    Size    Used  Available  Use%  Mounted on
# → /dev/loop0    7.2G   419M       6.8G    6%   /overlay
# ✅ 6.8GB free — router uses extroot overlay, plenty of space

# Create backup directory on router:
ssh root@YOUR_ROUTER_IP "mkdir -p /overlay/vaultwarden-backups"

###########################################################
# Step 2 — Set Up SSH Key Auth to Router
###########################################################

# Generate key (skip if already exists):
ssh-keygen -t ed25519 -f /home/USER/.ssh/id_ed25519 -N ""

# Copy public key to router:
ssh-copy-id -i /home/USER/.ssh/id_ed25519.pub root@YOUR_ROUTER_IP
# → Enter router root password when prompted

# Test passwordless login:
ssh root@YOUR_ROUTER_IP
# → Should connect without password prompt ✓
exit

# Install openssh-sftp-server on router (required for SCP):
ssh root@YOUR_ROUTER_IP "opkg update && opkg install openssh-sftp-server"
# → Installing openssh-sftp-server (8.4p1-4) to root...
# → Configuring openssh-sftp-server. ✓

# NOTE: Router uses BusyBox — standard SCP fails without sftp-server
# nc (netcat) is available but openssh-sftp-server is cleaner

###########################################################
# Step 3 — Set Up rclone for Google Drive
###########################################################

rclone config
# → n (New remote)
# → name: Google Drive
# → Storage type: drive
# → client_id: (leave blank, press Enter)
# → client_secret: (leave blank, press Enter)
# → scope: 3  ← drive.file (rclone-created files only — most secure)
# → service_account_file: (leave blank, press Enter)
# → Edit advanced config: n
# → Use auto config: n  ← headless server, no browser
# → Copy the rclone authorize command shown

# On your MAIN PC (with browser), run:
rclone authorize "drive" "<paste the token string from server>"
# → Opens browser automatically
# → Sign in with Google account
# → Click: Advanced → Go to rclone (unsafe) → Allow
# → Terminal shows token JSON → copy entire output

# Back on Ubuntu server, paste token at config_token> prompt

# → Configure as Shared Drive: n
# → Keep remote: y
# → q (Quit)

# NOTE: Scope 3 (drive.file) recommended — rclone can only see/manage
# files it created itself. Cannot access any other Google Drive content.
# Files are still visible in Google Drive web interface.

# Test rclone works:
echo "rclone test" > /tmp/rclone-test.txt
rclone copy /tmp/rclone-test.txt "Google Drive":vaultwarden-backups/
rclone ls "Google Drive":vaultwarden-backups/
# → 12 rclone-test.txt ✓

###########################################################
# Step 4 — backup.sh
###########################################################

# /home/USER/vaultwarden/backup.sh

# #!/bin/bash
# set -euo pipefail
# TIMESTAMP=$(date +%Y%m%d_%H%M%S)
# BACKUP_DIR="/home/USER/vaultwarden-backups"
# BACKUP_FILE="$BACKUP_DIR/vaultwarden_$TIMESTAMP.tar.gz"
# ROUTER_IP="YOUR_ROUTER_IP"
# ROUTER_PATH="/overlay/vaultwarden-backups"
# KEEP_DAYS=30
#
# mkdir -p "$BACKUP_DIR"
#
# # Archive Vaultwarden data volume
# docker run --rm \
#   --volumes-from vaultwarden \
#   -v "$BACKUP_DIR":/backup \
#   alpine \
#   tar czf "/backup/vaultwarden_$TIMESTAMP.tar.gz" /data
#
# echo "[$(date)] Backup created: $BACKUP_FILE"
#
# # Copy to Flint 2 router via SCP
# BACKUP_FILENAME=$(basename "$BACKUP_FILE")
# scp -i /home/USER/.ssh/id_ed25519 \
#   "$BACKUP_FILE" \
#   "root@$ROUTER_IP:$ROUTER_PATH/"
#
# echo "[$(date)] Backup copied to Flint 2"
#
# # Copy to Google Drive via rclone
# rclone copy "$BACKUP_FILE" "Google Drive":vaultwarden-backups/
#
# echo "[$(date)] Backup copied to Google Drive"
#
# # Cleanup local backups older than 30 days
# find "$BACKUP_DIR" -name "vaultwarden_*.tar.gz" -mtime +$KEEP_DAYS -delete
#
# # Cleanup router backups
# # NOTE: BusyBox find does NOT support -delete flag — use -exec rm instead
# ssh -i /home/USER/.ssh/id_ed25519 root@$ROUTER_IP \
#   "find $ROUTER_PATH -name 'vaultwarden_*.tar.gz' -mtime +$KEEP_DAYS -exec rm {} \;"

chmod +x /home/USER/vaultwarden/backup.sh

###########################################################
# Step 5 — Test Backup Manually
###########################################################

bash /home/USER/vaultwarden/backup.sh
# → tar: removing leading '/' from member names
# → [Mon Mar  9 09:29:06 PM UTC 2026] Backup created: /home/USER/vaultwarden-backups/vaultwarden_20260309_212905.tar.gz
# → vaultwarden_20260309_212905.tar.gz  100%  8.7KB ✓
# → [Mon Mar  9 09:29:06 PM UTC 2026] Backup copied to Flint 2
# → [Mon Mar  9 09:29:08 PM UTC 2026] Backup copied to Google Drive ✓

# Verify on router:
ssh root@YOUR_ROUTER_IP "ls -lh /overlay/vaultwarden-backups/"
# → -rw-r--r--  1 root  root  8.7K  Mar  9 21:29  vaultwarden_20260309_212905.tar.gz ✓

###########################################################
# Step 6 — Set Up Cron Job
###########################################################

(crontab -l 2>/dev/null; echo "0 2 * * * /home/USER/vaultwarden/backup.sh >> /home/USER/vaultwarden/backup.log 2>&1") | crontab -

crontab -l
# → 0 2 * * * /home/USER/vaultwarden/backup.sh >> /home/USER/vaultwarden/backup.log 2>&1 ✓

# Check backup log:
cat /home/USER/vaultwarden/backup.log

###########################################################
# Restore Procedure
###########################################################

# Stop Vaultwarden:
cd /home/USER/vaultwarden
sudo docker compose stop vaultwarden

# Restore from local backup (replace TIMESTAMP with actual filename):
sudo docker run --rm \
  --volumes-from vaultwarden \
  -v /home/USER/vaultwarden-backups:/backup \
  alpine \
  tar xzf /backup/vaultwarden_YYYYMMDD_HHMMSS.tar.gz -C /

# Restart:
sudo docker compose start vaultwarden

# To restore from router backup, copy file to Ubuntu first:
scp -i /home/USER/.ssh/id_ed25519 \
  "root@YOUR_ROUTER_IP:/overlay/vaultwarden-backups/vaultwarden_TIMESTAMP.tar.gz" \
  /home/USER/vaultwarden-backups/
# Then run the restore commands above

###########################################################
# Troubleshooting Notes
###########################################################

# ERROR: ash: /usr/libexec/sftp-server: not found / Connection closed
# CAUSE: Router missing sftp server binary
# FIX:   ssh root@YOUR_ROUTER_IP "opkg update && opkg install openssh-sftp-server"

# ERROR: find: unrecognized: -delete
# CAUSE: BusyBox find doesn't support -delete flag
# FIX:   Use -exec rm {} \; instead in the router cleanup command

# ERROR: rclone Failed to create file system "gdrive:..."
# CAUSE: Remote named "Google Drive" (with space) but script used "gdrive:"
# FIX:   Use "Google Drive": with quotes in all rclone commands
