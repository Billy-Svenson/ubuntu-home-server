###########################################################
# Glances + Uptime Kuma Setup
# System Monitor + Service Uptime Dashboard
###########################################################

################# - What Each Does - ######################
# Glances:      Replaces SSH aliases — CPU temp, RAM, disk,
#               battery, Docker containers in browser
# Uptime Kuma:  Watches if services are up/down, sends
#               Telegram alert within 60 seconds of outage

################# - Requirements - ########################
# - Docker + Docker Compose installed
# - Ubuntu LAN IP: YOUR_LAN_IP
# - Telegram account (for alerts)

###########################################################
# Step 1 — Check Port 80 Availability
###########################################################

sudo ss -tulpn | grep :80
# If AdGuard is on port 80, it must be moved before nginx
# proxy can work. See 07_reverse_proxy.md for that fix.

###########################################################
# Step 2 — Create Directory and docker-compose.yml
###########################################################

mkdir -p /home/USER/monitoring
cd /home/USER/monitoring

# /home/USER/monitoring/docker-compose.yml
#
# name: monitoring
# services:
#
#   glances:
#     container_name: glances
#     image: nicolargo/glances:latest-full
#     restart: unless-stopped
#     pid: host
#     network_mode: host
#     volumes:
#       - /var/run/docker.sock:/var/run/docker.sock:ro
#       - /sys:/sys:ro
#       - /etc/os-release:/etc/os-release:ro
#     environment:
#       - GLANCES_OPT=-w
#     # Accessible at: http://YOUR_LAN_IP:61208
#     # network_mode: host required so Glances reads
#     # host-level hardware sensors (CPU temp, battery)
#
#   uptime-kuma:
#     container_name: uptime-kuma
#     image: louislam/uptime-kuma:latest
#     restart: unless-stopped
#     volumes:
#       - uptime-kuma-data:/app/data
#       - /var/run/docker.sock:/var/run/docker.sock:ro
#     ports:
#       - "3001:3001"
#     # Accessible at: http://YOUR_LAN_IP:3001
#
# volumes:
#   uptime-kuma-data:

###########################################################
# Step 3 — Deploy
###########################################################

sudo docker compose up -d
# → Image louislam/uptime-kuma:latest   Pulled
# → Image nicolargo/glances:latest-full Pulled
# → Network monitoring_default          Created
# → Volume monitoring_uptime-kuma-data  Created
# → Container uptime-kuma               Started ✓
# → Container glances                   Started ✓

sudo docker ps | grep -E "glances|uptime"
# → 529a9f1a282e  louislam/uptime-kuma:latest       Up (healthy)  0.0.0.0:3001->3001/tcp  uptime-kuma
# → 9bc927c5a89b  nicolargo/glances:latest-full     Up                                     glances

###########################################################
# Step 4 — Uptime Kuma Initial Setup
###########################################################

# Open in browser: http://YOUR_LAN_IP:3001
# → Create admin account (username + password)
# → Add monitors — Type: HTTP(s) for each:

# Monitor 1 — Immich
# Name: Immich
# URL:  http://YOUR_LAN_IP:2283
# Interval: 60 seconds

# Monitor 2 — Vaultwarden
# Name: Vaultwarden
# URL:  https://YOUR_TAILSCALE_HOST
# Interval: 60 seconds

# Monitor 3 — AdGuard
# Name: AdGuard
# URL:  http://YOUR_LAN_IP:3000
# Interval: 60 seconds

# Monitor 4 — Glances
# Name: Glances
# URL:  http://YOUR_LAN_IP:61208
# Interval: 60 seconds

###########################################################
# Step 5 — Telegram Bot Setup
###########################################################

# 1. Open Telegram → search @BotFather
# 2. Send: /newbot
# 3. Name: HomeServer Monitor (or anything)
# 4. Username: must end in _bot (e.g. lordserver_bot)
# 5. BotFather replies with token: 7123456789:AAFxxx...

# Get your Chat ID:
# → Send any message to your new bot in Telegram first
curl "https://api.telegram.org/bot<YOUR_TOKEN>/getUpdates"
# → {"ok":true,"result":[{"message":{"chat":{"id":YOUR_CHAT_ID,...}}}]}
# → "id" value inside "chat" is your Chat ID

###########################################################
# Step 6 — Add Telegram to Uptime Kuma
###########################################################

# http://kuma.home (or http://YOUR_LAN_IP:3001)
# Settings → Notifications → Add Notification
# → Type: Telegram
# → Friendly Name: Telegram
# → Bot Token: <token from BotFather>
# → Chat ID: <id from getUpdates>
# → Click Test → Telegram message should arrive ✓
# → Save

# Attach to each monitor:
# Click monitor → Edit → Notifications → select Telegram → Save
# Repeat for all 4 monitors

###########################################################
# Step 7 — Verify Alerts Working
###########################################################

# Stop a service to test:
cd /home/USER/monitoring
sudo docker compose stop glances
# → Wait up to 60 seconds
# → Telegram: [Glances] [Down] connect ECONNREFUSED YOUR_LAN_IP:61208 ✓

sudo docker compose start glances
# → Telegram: [Glances] [Up] 200 - OK ✓

###########################################################
# Access URLs
###########################################################

# Glances (after proxy setup):
http://glances.home

# Uptime Kuma (after proxy setup):
http://kuma.home

# Direct access (no proxy needed):
http://YOUR_LAN_IP:61208   ← Glances
http://YOUR_LAN_IP:3001    ← Uptime Kuma

###########################################################
# Service Management
###########################################################

cd /home/USER/monitoring

# Start:
sudo docker compose up -d

# Stop:
sudo docker compose down

# Logs:
sudo docker logs glances --tail 20
sudo docker logs uptime-kuma --tail 20
