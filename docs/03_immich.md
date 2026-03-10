###########################################################
# Immich Photo Storage
# Self-Hosted Google Photos Alternative
###########################################################

################# - Requirements - ########################
# - Docker + Docker Compose installed
# - Ubuntu LAN IP: YOUR_LAN_IP
# - Tailscale running (for remote access)

###########################################################
# Existing Setup Location
###########################################################

# Docker Compose file:
/home/USER/immich-app/docker-compose.yml

# Running containers:
sudo docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Image}}"
# NAMES                     STATUS          IMAGE
# immich_server             Up (healthy)    ghcr.io/immich-app/immich-server:v2
# immich_postgres           Up (healthy)    ghcr.io/immich-app/postgres:14-vectorchord
# immich_machine_learning   Up (healthy)    ghcr.io/immich-app/immich-machine-learning:v2
# immich_redis              Up (healthy)    valkey/valkey:9

###########################################################
# docker-compose.yml (full)
###########################################################

# /home/USER/immich-app/docker-compose.yml
#
# name: immich
# services:
#   immich-server:
#     container_name: immich_server
#     image: ghcr.io/immich-app/immich-server:${IMMICH_VERSION:-release}
#     volumes:
#       - ${UPLOAD_LOCATION}:/data
#       - /etc/localtime:/etc/localtime:ro
#     env_file:
#       - .env
#     ports:
#       - '2283:2283'
#     depends_on:
#       - redis
#       - database
#     restart: always
#
#   immich-machine-learning:
#     container_name: immich_machine_learning
#     image: ghcr.io/immich-app/immich-machine-learning:${IMMICH_VERSION:-release}
#     volumes:
#       - model-cache:/cache
#     env_file:
#       - .env
#     restart: always
#
#   redis:
#     container_name: immich_redis
#     image: docker.io/valkey/valkey:9
#     restart: always
#
#   database:
#     container_name: immich_postgres
#     image: ghcr.io/immich-app/postgres:14-vectorchord
#     environment:
#       POSTGRES_PASSWORD: ${DB_PASSWORD}
#       POSTGRES_USER: ${DB_USERNAME}
#       POSTGRES_DB: ${DB_DATABASE_NAME}
#       POSTGRES_INITDB_ARGS: '--data-checksums'
#     volumes:
#       - ${DB_DATA_LOCATION}:/var/lib/postgresql/data
#     shm_size: 128mb
#     restart: always
#
#   adguardhome:                          ← added later
#     container_name: adguardhome
#     image: adguard/adguardhome:latest
#     network_mode: host
#     volumes:
#       - adguard-work:/opt/adguardhome/work
#       - adguard-conf:/opt/adguardhome/conf
#     restart: unless-stopped
#
# volumes:
#   model-cache:
#   adguard-work:
#   adguard-conf:

###########################################################
# Remote Access Setup — Wife's Phone (Tailscale)
###########################################################

# Ubuntu laptop must be shared to wife's Tailscale account:
# https://login.tailscale.com/admin/machines
# → ubuntu → ... → Share → enter her Tailscale email
# → She accepts invite in her Tailscale app

# Find Ubuntu Tailscale IP:
tailscale ip -4
# → YOUR_TAILSCALE_IP

# Wife's Immich mobile app settings:
# → Profile/avatar (top left) → Server URL
# → Local network URL:  http://YOUR_LAN_IP:2283   (home WiFi)
# → External URL:       http://YOUR_TAILSCALE_IP:2283   (away via Tailscale)
# → Enable: Automatic URL switching ✓
# → Local network: set home WiFi network

###########################################################
# Access URLs
###########################################################

# Local (home WiFi):
http://YOUR_LAN_IP:2283

# Remote (Tailscale connected):
http://YOUR_TAILSCALE_IP:2283

###########################################################
# Service Management
###########################################################

cd /home/USER/immich-app

# Start all services:
sudo docker compose up -d

# Stop all services:
sudo docker compose down

# View logs:
sudo docker logs immich_server --tail 20
sudo docker logs immich_machine_learning --tail 20

# Restart single service:
sudo docker compose restart immich-server

###########################################################
# Notes
###########################################################

# Machine learning containers (face detection, CLIP search)
# will spike CPU temporarily during photo processing.
# Celeron N4500 handles it but expect slowness during
# large batch uploads from wife's phone (especially from China).
#
# To check ML processing queue:
# Immich web UI → Administration → Jobs
