###########################################################
# Vaultwarden Setup
# Self-Hosted Password Manager (Bitwarden compatible)
###########################################################

################# - Requirements - ########################
# - Docker + Docker Compose installed
# - Tailscale running with HTTPS certs enabled
# - Ubuntu Tailscale hostname: YOUR_TAILSCALE_HOST
# - Gmail account with 2FA enabled (for SMTP)
# - SSH key auth to Flint 2 router (for backups)
# - rclone configured with Google Drive (for backups)

###########################################################
# Step 1 — Enable Tailscale HTTPS Certificates
###########################################################

# In browser: https://login.tailscale.com/admin/dns
# → Enable MagicDNS ✓
# → Enable HTTPS Certificates ✓

# Get correct Tailscale hostname:
tailscale status | grep ubuntu
# → YOUR_TAILSCALE_IP  ubuntu  YOUR_ACCOUNT@  linux  idle; offers exit node

# Issue certificate:
sudo tailscale cert YOUR_TAILSCALE_HOST
# → Wrote public cert to YOUR_TAILSCALE_HOST.crt
# → Wrote private key to YOUR_TAILSCALE_HOST.key

# Verify certs exist:
sudo ls /var/lib/tailscale/certs/
# → acme-account.key.pem
# → YOUR_TAILSCALE_HOST.crt
# → YOUR_TAILSCALE_HOST.key

# NOTE: First attempt used wrong hostname ubuntu.tail248d76.ts.net
# Error message revealed correct hostname: YOUR_TAILSCALE_HOST
# Check machine details in Tailscale admin console if unsure

###########################################################
# Step 2 — Create Directory and Files
###########################################################

mkdir -p /home/USER/vaultwarden
cd /home/USER/vaultwarden

# Generate admin token:
openssl rand -base64 48
# → copy the output, store it safely — this is your login password

###########################################################
# Step 3 — .env File
###########################################################

# /home/USER/vaultwarden/.env

touch /home/USER/vaultwarden/.env
nano /home/USER/vaultwarden/.env

# Contents:
# ADMIN_TOKEN='$argon2id$v=19$m=65540,...'   ← Argon2 hash (see Step 6)
# SIGNUPS_ALLOWED=false
# SMTP_HOST=smtp.gmail.com
# SMTP_PORT=587
# SMTP_SECURITY=starttls
# SMTP_USERNAME=your@gmail.com
# SMTP_PASSWORD=abcdefghijklmnop   ← 16-char App Password, NO spaces
# SMTP_FROM=your@gmail.com

# Gmail App Password:
# Google Account → Security → 2-Step Verification → App passwords
# Create new → name it "Vaultwarden" → copy 16-char password (remove spaces)

###########################################################
# Step 4 — docker-compose.yml
###########################################################

# /home/USER/vaultwarden/docker-compose.yml

# name: vaultwarden
# services:
#   vaultwarden:
#     container_name: vaultwarden
#     image: vaultwarden/server:latest
#     restart: unless-stopped
#     env_file:
#       - .env                            ← REQUIRED for SMTP vars to load
#     environment:
#       - DOMAIN=https://YOUR_TAILSCALE_HOST
#       - ROCKET_ADDRESS=0.0.0.0
#       - ROCKET_PORT=8080
#     volumes:
#       - vaultwarden-data:/data
#     networks:
#       - vaultwarden-net
#
#   nginx:
#     container_name: vaultwarden-nginx
#     image: nginx:alpine
#     restart: unless-stopped
#     ports:
#       - "443:443"
#     volumes:
#       - ./nginx.conf:/etc/nginx/nginx.conf:ro
#       - /var/lib/tailscale/certs:/certs:ro
#     depends_on:
#       - vaultwarden
#     networks:
#       - vaultwarden-net
#
# volumes:
#   vaultwarden-data:
#
# networks:
#   vaultwarden-net:
#     driver: bridge

# NOTE: env_file directive is critical — without it SMTP variables
# in .env are NOT passed to the container. Only hardcoded
# environment: values would be used.

# NOTE: Both containers must be on same network (vaultwarden-net)
# so nginx can reach vaultwarden by container name.
# Using container name 'vaultwarden' in proxy_pass prevents
# IP changes from breaking things on reboot.

###########################################################
# Step 5 — nginx.conf
###########################################################

# /home/USER/vaultwarden/nginx.conf

# events {}
# http {
#   server {
#     listen 443 ssl;
#     server_name YOUR_TAILSCALE_HOST;
#     ssl_certificate     /certs/YOUR_TAILSCALE_HOST.crt;
#     ssl_certificate_key /certs/YOUR_TAILSCALE_HOST.key;
#     ssl_protocols       TLSv1.2 TLSv1.3;
#     ssl_ciphers         HIGH:!aNULL:!MD5;
#
#     location / {
#       proxy_pass http://vaultwarden:8080;
#       proxy_set_header Host $host;
#       proxy_set_header X-Real-IP $remote_addr;
#       proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
#       proxy_set_header X-Forwarded-Proto $scheme;
#     }
#
#     location /notifications/hub {
#       proxy_pass http://vaultwarden:8080;
#       proxy_set_header Upgrade $http_upgrade;
#       proxy_set_header Connection "upgrade";
#       proxy_set_header Host $host;
#     }
#   }
# }

# NOTE: HTTP redirect block (port 80) removed — AdGuard Home
# occupies port 80 on the host network causing conflict.

###########################################################
# Step 6 — Start and Secure Admin Token
###########################################################

cd /home/USER/vaultwarden
sudo docker compose up -d
# → vaultwarden container started ✓
# → vaultwarden-nginx container started ✓

# Hash the admin token (more secure than plain text):
sudo docker exec -it vaultwarden /vaultwarden hash
# → Enter your plain text token when prompted
# → Outputs: $argon2id$v=19$m=65540,t=3,p=4$...

# Update .env with the hash (single quotes required — hash contains $):
nano /home/USER/vaultwarden/.env
# ADMIN_TOKEN='$argon2id$v=19$...'

sudo docker compose up -d --force-recreate

# Verify SMTP variables loaded into container:
sudo docker exec vaultwarden env | grep -i smtp
# → SMTP_PORT=587
# → SMTP_USERNAME=...
# → SMTP_HOST=smtp.gmail.com
# → SMTP_PASSWORD=...
# → SMTP_SECURITY=starttls
# → SMTP_FROM=...

###########################################################
# Step 7 — Create Your Account
###########################################################

# Temporarily allow signups to register:
nano /home/USER/vaultwarden/.env
# SIGNUPS_ALLOWED=true

sudo docker compose up -d

# Register at:
https://YOUR_TAILSCALE_HOST/#/register

# After creating account, disable signups again:
nano /home/USER/vaultwarden/.env
# SIGNUPS_ALLOWED=false

sudo docker compose up -d

# Admin panel (use plain text token to log in, not the hash):
https://YOUR_TAILSCALE_HOST/admin

# Invite wife's account:
# Admin panel → Users → Invite User → enter her email
# She accepts email invite and creates account

###########################################################
# Step 8 — Bitwarden Browser Extension Setup
###########################################################

# Install Bitwarden extension from Chrome Web Store
# On the login page:
# → Click "Region" dropdown or gear icon
# → Select "Self-hosted"
# → Server URL: https://YOUR_TAILSCALE_HOST
# → Save
# → Log in with your email and master password

###########################################################
# Troubleshooting Log
###########################################################

# ERROR: cannot load certificate ubuntu.tail248d76.ts.net.crt
# CAUSE: nginx.conf had old wrong hostname
# FIX:   Update server_name and ssl_certificate paths to YOUR_TAILSCALE_HOST

# ERROR: 502 Bad Gateway
# CAUSE: nginx (network_mode:host) couldn't reach vaultwarden bridge network
# FIX:   Put both containers on same Docker network, use container
#        name 'vaultwarden' in proxy_pass instead of IP address

# ERROR: SMTP variables not loaded, emails not sending
# CAUSE: docker-compose.yml missing env_file directive
# FIX:   Add "env_file: - .env" to vaultwarden service block

# ERROR: bind() to 0.0.0.0:80 failed (98: Address in use)
# CAUSE: AdGuard Home occupies port 80
# FIX:   Remove HTTP redirect server block from nginx.conf

###########################################################
# Access URLs
###########################################################

# Vaultwarden (Tailscale required):
https://YOUR_TAILSCALE_HOST

# Admin panel:
https://YOUR_TAILSCALE_HOST/admin

# Login: use original plain text token (not the Argon2 hash)
# Store plain text token as Secure Note inside Vaultwarden itself

###########################################################
# Service Management
###########################################################

cd /home/USER/vaultwarden

# Start:
sudo docker compose up -d

# Restart nginx only:
sudo docker compose restart nginx

# View logs:
sudo docker logs vaultwarden --tail 20
sudo docker logs vaultwarden-nginx --tail 20

# Check SMTP config inside container:
sudo docker exec vaultwarden env | grep -i smtp
