###########################################################
# Nginx Reverse Proxy + Clean .home URLs
# AdGuard Port Fix + DNS Rewrites
###########################################################

################# - What We're Building - #################
# nginx-proxy container on port 80 routes .home domains
# to the correct service based on Host header.
# AdGuard handles DNS — all .home domains resolve to
# YOUR_LAN_IP, nginx decides where to send the request.
#
# Final URLs:
#   http://immich.home   → Immich  :2283
#   http://adguard.home  → AdGuard :3000
#   http://kuma.home     → Kuma    :3001
#   http://glances.home  → Glances :61208

################# - Requirements - ########################
# - AdGuard Home running
# - Glances + Uptime Kuma running (see 07_monitoring.md)
# - Ubuntu LAN IP: YOUR_LAN_IP

###########################################################
# Step 1 — Fix AdGuard Port Conflict
###########################################################

# AdGuard was binding port 80 (needed by nginx-proxy)
# Must move AdGuard web UI to port 3000

# Check who owns port 80:
sudo ss -tulpn | grep :80
# → tcp LISTEN  *:80  users:(("AdGuardHome",pid=18879,fd=10))
# → AdGuard is on port 80 ← must fix before nginx-proxy works

# Find AdGuard config file:
sudo find /var/lib/docker/volumes -name "AdGuardHome.yaml" 2>/dev/null
# → /var/lib/docker/volumes/YOUR_ADGUARD_VOLUME/_data/AdGuardHome.yaml

# Check current http section:
sudo grep -A10 "^http:" /var/lib/docker/volumes/YOUR_ADGUARD_VOLUME/_data/AdGuardHome.yaml
# → http:
# →   pprof:
# →     port: 6060
# →     enabled: false
# →   address: 0.0.0.0:80       ← this is the problem
# →   session_ttl: 720h

# Change port from 80 to 3000:
sudo sed -i 's/address: 0.0.0.0:80/address: 0.0.0.0:3000/' \
  /var/lib/docker/volumes/YOUR_ADGUARD_VOLUME/_data/AdGuardHome.yaml

# Verify change:
sudo grep "address:" /var/lib/docker/volumes/YOUR_ADGUARD_VOLUME/_data/AdGuardHome.yaml
# → address: 0.0.0.0:3000 ✓

# Restart AdGuard:
cd /home/USER/immich-app
sudo docker compose restart adguardhome

# Verify AdGuard moved to 3000, port 80 now free:
sudo ss -tulpn | grep -E ':80|:3000'
# → tcp LISTEN  YOUR_LAN_IP:3000  users:(("AdGuardHome",...)) ✓
# → port 80 should be empty now ✓

###########################################################
# Step 2 — Create Proxy Directory and Files
###########################################################

mkdir -p /home/USER/proxy
cd /home/USER/proxy

###########################################################
# Step 3 — docker-compose.yml
###########################################################

# /home/USER/proxy/docker-compose.yml
#
# name: proxy
# services:
#   nginx-proxy:
#     container_name: nginx-proxy
#     image: nginx:alpine
#     restart: unless-stopped
#     network_mode: host
#     volumes:
#       - ./nginx.conf:/etc/nginx/nginx.conf:ro
#     # network_mode: host so nginx can reach all services
#     # on YOUR_LAN_IP without Docker NAT complications.
#     # Listens on port 80 for all .home domain requests.

###########################################################
# Step 4 — nginx.conf
###########################################################

# /home/USER/proxy/nginx.conf
#
# events {
#     worker_connections 1024;
# }
#
# http {
#     map $http_upgrade $connection_upgrade {
#         default upgrade;
#         ''      close;
#     }
#
#     server {
#         listen 80;
#         server_name immich.home;
#         client_max_body_size 50000M;
#         location / {
#             proxy_pass http://YOUR_LAN_IP:2283;
#             proxy_set_header Host $host;
#             proxy_set_header X-Real-IP $remote_addr;
#             proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
#             proxy_set_header X-Forwarded-Proto $scheme;
#             proxy_set_header Upgrade $http_upgrade;
#             proxy_set_header Connection $connection_upgrade;
#             proxy_buffering off;
#             proxy_read_timeout 600s;
#             proxy_send_timeout 600s;
#         }
#     }
#
#     server {
#         listen 80;
#         server_name adguard.home;
#         location / {
#             proxy_pass http://YOUR_LAN_IP:3000;
#             proxy_set_header Host $host;
#             proxy_set_header X-Real-IP $remote_addr;
#             proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
#             proxy_set_header X-Forwarded-Proto $scheme;
#         }
#     }
#
#     server {
#         listen 80;
#         server_name kuma.home;
#         location / {
#             proxy_pass http://YOUR_LAN_IP:3001;
#             proxy_set_header Host $host;
#             proxy_set_header X-Real-IP $remote_addr;
#             proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
#             proxy_set_header X-Forwarded-Proto $scheme;
#             proxy_set_header Upgrade $http_upgrade;
#             proxy_set_header Connection $connection_upgrade;
#             proxy_read_timeout 3600s;
#             proxy_send_timeout 3600s;
#         }
#     }
#
#     server {
#         listen 80;
#         server_name glances.home;
#         location / {
#             proxy_pass http://YOUR_LAN_IP:61208;
#             proxy_set_header Host $host;
#             proxy_set_header X-Real-IP $remote_addr;
#             proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
#             proxy_set_header X-Forwarded-Proto $scheme;
#             proxy_set_header Upgrade $http_upgrade;
#             proxy_set_header Connection $connection_upgrade;
#         }
#     }
# }

###########################################################
# Step 5 — Deploy Proxy
###########################################################

cd /home/USER/proxy
sudo docker compose up -d
# → Container nginx-proxy Started ✓

# Verify nginx grabbed port 80:
sudo ss -tulpn | grep :80
# → tcp LISTEN  0.0.0.0:80  users:(("nginx",...)) ✓

# Test routing before DNS (using Host header):
curl -H "Host: immich.home" http://YOUR_LAN_IP/
# → <!doctype html><html>...<title>Immich</title>... ✓

curl -H "Host: adguard.home" http://YOUR_LAN_IP/
# → <a href="/login.html">Found</a>. ✓

###########################################################
# Step 6 — AdGuard DNS Rewrites
###########################################################

# AdGuard dashboard: http://YOUR_LAN_IP:3000
# Filters → DNS rewrites → Add DNS rewrite
# Add all 4 (all point to same IP, nginx handles routing):

# Domain: immich.home    → Answer: YOUR_LAN_IP
# Domain: adguard.home   → Answer: YOUR_LAN_IP
# Domain: kuma.home      → Answer: YOUR_LAN_IP
# Domain: glances.home   → Answer: YOUR_LAN_IP

# Verify DNS resolves:
nslookup immich.home YOUR_LAN_IP
# → Name:    immich.home
# → Address: YOUR_LAN_IP ✓

nslookup kuma.home YOUR_LAN_IP
# → Address: YOUR_LAN_IP ✓

###########################################################
# Troubleshooting
###########################################################

# .home URLs all show AdGuard dashboard:
# → AdGuard still on port 80, nginx-proxy didn't get it
# → Re-check: sudo ss -tulpn | grep :80
# → Make sure AdGuardHome.yaml address changed and restarted

# .home URLs show nginx error:
# → sudo docker exec nginx-proxy nginx -t
# → sudo docker logs nginx-proxy --tail 20

# DNS not resolving .home:
# → Check AdGuard DNS rewrites exist
# → Check Flint 2 DNS still points to YOUR_LAN_IP
# → nslookup immich.home YOUR_LAN_IP

###########################################################
# Service Management
###########################################################

cd /home/USER/proxy

sudo docker compose up -d
sudo docker compose restart nginx-proxy
sudo docker exec nginx-proxy nginx -t
sudo docker logs nginx-proxy --tail 20
