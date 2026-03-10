###########################################################
# AdGuard Home Setup
# Whole-Home Ad Blocking via Docker
###########################################################

################# - Requirements - ########################
# - Docker + Docker Compose installed
# - Immich already running at /home/USER/immich-app/
# - Ubuntu LAN IP: YOUR_LAN_IP
# - GL.iNet Flint 2 router at YOUR_ROUTER_IP

###########################################################
# Hardware Check Before Installing
###########################################################

echo "=== CPU ===" && nproc && cat /proc/cpuinfo | grep "model name" | head -1
echo "=== RAM ===" && free -h
echo "=== DISK ===" && df -h /
echo "=== Current load ===" && uptime
echo "=== Docker containers running ===" && sudo docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Image}}"
# CPU:  Intel Celeron N4500 @ 1.10GHz (2 cores) — modest but sufficient
# RAM:  7.6GB total, 1.3GB used, 6.3GB available ✓
# Disk: 232GB total, 21GB used (10%) ✓
# Load: 0.04 — basically idle ✓
# AdGuard Home uses ~50MB RAM and minimal CPU — safe to add

###########################################################
# Add AdGuard to Existing Docker Compose
###########################################################

nano /home/USER/immich-app/docker-compose.yml
# Add the following service at the bottom (before the volumes section):

#   adguardhome:
#     container_name: adguardhome
#     image: adguard/adguardhome:latest
#     network_mode: host
#     volumes:
#       - adguard-work:/opt/adguardhome/work
#       - adguard-conf:/opt/adguardhome/conf
#     restart: unless-stopped
#
# Also add to volumes section:
#   adguard-work:
#   adguard-conf:

# NOTE: network_mode: host is required so AdGuard binds directly to
# port 53 on YOUR_LAN_IP without Docker NAT complications.
# This allows it to serve DNS for the whole home network.

###########################################################
# Deploy
###########################################################

cd /home/USER/immich-app
sudo docker compose up -d
# → Immich containers unchanged (already running)
# → adguardhome container pulled and started

sudo docker ps | grep adguard
# → adguardhome   Up X hours   adguard/adguardhome:latest

###########################################################
# Initial Setup (browser)
###########################################################

# Open from any device on home WiFi:
http://YOUR_LAN_IP:3000
# Follow setup wizard:
# → DNS listen interface: YOUR_LAN_IP  port: 53
# → Admin UI port: 3000
# → Create admin username and password

###########################################################
# Point Flint 2 Router DNS to AdGuard
###########################################################

# GL.iNet admin panel → http://YOUR_ROUTER_IP
# Network → DNS
# DNS server: YOUR_LAN_IP
# Apply

# Verify AdGuard is listening on port 53:
sudo ss -tulpn | grep :53
# → tcp LISTEN  *:53  users:(("AdGuardHome",pid=XXXXX,fd=XX))

###########################################################
# Verify Working
###########################################################

# AdGuard dashboard — queries should appear in real time:
http://YOUR_LAN_IP:3000
# → Total queries counter going up
# → Blocked counter showing blocked ads in red
# → Query log showing all home network DNS requests

###########################################################
# Useful Info
###########################################################

# Port 80 is occupied by AdGuard Home (admin UI fallback)
# This blocks other services from using port 80 on host network
# → Vaultwarden nginx HTTP redirect was removed because of this conflict

# AdGuard dashboard URL:
http://YOUR_LAN_IP:3000

# To add blocklists:
# Filters → DNS blocklists → Add blocklist
# Recommended: AdGuard DNS filter, EasyList, EasyPrivacy
