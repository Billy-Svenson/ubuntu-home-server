###########################################################
# Quick Reference — Home Server
# All URLs, commands, and pending tasks
###########################################################

###########################################################
# System Info
###########################################################

# Hardware:       Intel Celeron N4500, 7.6GB RAM, 232GB SSD
# OS:             Ubuntu (Linux x86_64)
# Router:         GL.iNet Flint 2 (MT6000) — OpenWrt/LuCI
# Ubuntu LAN IP:  YOUR_LAN_IP
# Router LAN IP:  YOUR_ROUTER_IP
# Tailscale IP:   YOUR_TAILSCALE_IP
# Tailscale Host: YOUR_TAILSCALE_HOST
# Tailscale Acct: YOUR_GMAIL
# ISP:            500/500 Mbps — behind CGNAT (no port forwarding)

###########################################################
# Service URLs
###########################################################

# Immich (home WiFi):
http://YOUR_LAN_IP:2283

# Immich (Tailscale remote):
http://YOUR_TAILSCALE_IP:2283

# AdGuard Home dashboard:
http://YOUR_LAN_IP:3000

# Router admin:
http://YOUR_ROUTER_IP

# Vaultwarden (Tailscale required):
https://YOUR_TAILSCALE_HOST

# Vaultwarden admin panel:
https://YOUR_TAILSCALE_HOST/admin

# Tailscale admin:
https://login.tailscale.com/admin/machines

###########################################################
# Docker Service Management
###########################################################

# Immich + AdGuard:
cd /home/USER/immich-app
sudo docker compose up -d
sudo docker compose down
sudo docker compose restart <service>
sudo docker logs <container_name> --tail 20

# Vaultwarden:
cd /home/USER/vaultwarden
sudo docker compose up -d
sudo docker compose restart nginx
sudo docker logs vaultwarden --tail 20
sudo docker logs vaultwarden-nginx --tail 20

# All running containers:
sudo docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Image}}"

###########################################################
# Tailscale Commands
###########################################################

sudo tailscale status
tailscale ip -4
sudo tailscale up --advertise-routes=YOUR_SUBNET --snat-subnet-routes --accept-routes --advertise-exit-node
sudo tailscale logout
sudo systemctl restart tailscaled

###########################################################
# Firewall / nftables
###########################################################

# View full ruleset:
sudo nft list ruleset

# Check specific chains:
sudo nft list chain ip nat ts-postrouting
sudo nft list chain ip filter ts-forward

# Save rules (run while Tailscale is connected):
sudo nft list ruleset | sudo tee /etc/nftables.conf

###########################################################
# Network Diagnostics
###########################################################

# Check what's on which port:
sudo ss -tulpn | grep :443
sudo ss -tulpn | grep :53
sudo ss -tulpn | grep :80

# Packet tracing:
sudo tcpdump -i tailscale0 icmp
sudo tcpdump -i enp6s0 host YOUR_ROUTER_IP

###########################################################
# Router SSH
###########################################################

# Connect (passwordless after key setup):
ssh root@YOUR_ROUTER_IP

# Check router storage:
ssh root@YOUR_ROUTER_IP "df -h /overlay"

# List backups on router:
ssh root@YOUR_ROUTER_IP "ls -lh /overlay/vaultwarden-backups/"

###########################################################
# Backup
###########################################################

# Run manual backup:
bash /home/USER/vaultwarden/backup.sh

# Check backup log:
cat /home/USER/vaultwarden/backup.log

# Check cron job:
crontab -l
# → 0 2 * * * /home/USER/vaultwarden/backup.sh >> ...

# List local backups:
ls -lh /home/USER/vaultwarden-backups/

###########################################################
# Pending Tasks
###########################################################

# BEFORE WIFE'S CHINA TRIP:
# [ ] Enable always-on VPN on wife's phone
#     Android: Settings → Network → VPN → Tailscale → Always-on VPN
#     iOS: Tailscale app → stay connected setting
# [ ] Set up wife's Vaultwarden account
#     Admin panel → Users → Invite User → her email
# [ ] Test exit node from her phone on mobile data
#     Tailscale app → select ubuntu as exit node → verify internet works

# LOW PRIORITY:
# [ ] Fix Vaultwarden Websocket error (nginx.conf missing upgrade headers properly)
#     Diagnostics page shows: Websocket: Error
# [ ] Nginx reverse proxy for clean .home URLs
#     immich.home, adguard.home via AdGuard local DNS rewrites
# [ ] Uptime Kuma — service monitoring with alerts
#     Add to docker-compose, get notified when services go down
# [ ] YubiKey / phone as 2FA for Vaultwarden
#     Vaultwarden → Account → Two-step login → FIDO2/WebAuthn

###########################################################
# File Locations
###########################################################

# Immich:
/home/USER/immich-app/docker-compose.yml
/home/USER/immich-app/.env

# Vaultwarden:
/home/USER/vaultwarden/docker-compose.yml
/home/USER/vaultwarden/nginx.conf
/home/USER/vaultwarden/.env
/home/USER/vaultwarden/backup.sh
/home/USER/vaultwarden/backup.log

# Tailscale certs:
/var/lib/tailscale/certs/YOUR_TAILSCALE_HOST.crt
/var/lib/tailscale/certs/YOUR_TAILSCALE_HOST.key

# nftables saved rules:
/etc/nftables.conf

# SSH key for router:
/home/USER/.ssh/id_ed25519
/home/USER/.ssh/id_ed25519.pub

# Backups (local):
/home/USER/vaultwarden-backups/

# Backups (router):
/overlay/vaultwarden-backups/   (on YOUR_ROUTER_IP)
