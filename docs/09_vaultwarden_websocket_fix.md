###########################################################
# Vaultwarden Websocket Fix
# nginx.conf upgrade map for real-time vault sync
###########################################################

################# - Problem - #############################
# Vaultwarden admin diagnostics showed:
# Websocket: Error
# This means vault changes don't sync in real-time between
# devices — you'd need to manually refresh to see updates.

################# - Root Cause - ##########################
# nginx.conf was missing the $connection_upgrade map and
# the Upgrade/Connection headers in the main location block.
# The /notifications/hub/negotiate endpoint was also missing.

###########################################################
# Fix — Update nginx.conf
###########################################################

# /home/USER/vaultwarden/nginx.conf (full working version)
#
# events {
#     worker_connections 1024;
# }
#
# http {
#     # This map is the key fix — handles websocket upgrades
#     map $http_upgrade $connection_upgrade {
#         default upgrade;
#         ''      close;
#     }
#
#     server {
#         listen 443 ssl;
#         server_name YOUR_TAILSCALE_HOST;
#
#         ssl_certificate     /certs/YOUR_TAILSCALE_HOST.crt;
#         ssl_certificate_key /certs/YOUR_TAILSCALE_HOST.key;
#         ssl_protocols       TLSv1.2 TLSv1.3;
#         ssl_ciphers         HIGH:!aNULL:!MD5;
#         ssl_session_cache   shared:SSL:10m;
#         ssl_session_timeout 10m;
#
#         client_max_body_size 525M;
#
#         location / {
#             proxy_pass http://vaultwarden:8080;
#             proxy_set_header Host $host;
#             proxy_set_header X-Real-IP $remote_addr;
#             proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
#             proxy_set_header X-Forwarded-Proto $scheme;
#             # These two lines are the websocket fix:
#             proxy_set_header Upgrade $http_upgrade;
#             proxy_set_header Connection $connection_upgrade;
#         }
#
#         # Real-time sync between devices
#         location /notifications/hub {
#             proxy_pass http://vaultwarden:8080;
#             proxy_set_header Host $host;
#             proxy_set_header Upgrade $http_upgrade;
#             proxy_set_header Connection $connection_upgrade;
#             proxy_set_header X-Real-IP $remote_addr;
#             proxy_read_timeout 3600s;
#             proxy_send_timeout 3600s;
#         }
#
#         # Websocket negotiation endpoint (was missing before)
#         location /notifications/hub/negotiate {
#             proxy_pass http://vaultwarden:8080;
#             proxy_set_header Host $host;
#             proxy_set_header X-Real-IP $remote_addr;
#             proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
#             proxy_set_header X-Forwarded-Proto $scheme;
#         }
#     }
# }

###########################################################
# Apply Fix
###########################################################

cd /home/USER/vaultwarden

# After updating nginx.conf, restart nginx:
sudo docker compose restart nginx
# → Container vaultwarden-nginx Restarted ✓

# Verify config is valid:
sudo docker exec vaultwarden-nginx nginx -t
# → nginx: configuration file /etc/nginx/nginx.conf syntax is ok
# → nginx: configuration file /etc/nginx/nginx.conf test is successful ✓

###########################################################
# Verify Fix
###########################################################

# Open: https://YOUR_TAILSCALE_HOST/admin/diagnostics
# Checks section should show:
# Websocket enabled: Ok Yes ✓  (was Error before)
# All other checks also Ok ✓

# Full diagnostics after fix:
# OS/Arch:                linux / x86_64
# Running within container: Yes (Base: Debian)
# Uses reverse proxy:     Yes
# IP header:              Match — Config/Server: X-Real-IP
# Internet access:        Ok
# Websocket enabled:      Ok Yes    ← FIXED ✓
# DNS (github.com):       Ok
# Date & Time:            Server/Browser Ok, NTP Ok
# Domain configuration:   Match HTTPS
# HTTP Response:          Ok
