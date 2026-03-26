# Ubuntu Home Server

I built this over a single day, mostly because I wanted to stop paying for cloud services and actually own my data. I had some general tech background but had never touched self-hosting before. A lot of this was trial and error — figuring out why things weren't working, reading error messages, and going deeper than I expected to.

What started as "I just want to access my router remotely" turned into a full stack with photo storage, a password manager, ad blocking, monitoring, and automated backups. I'm writing this down so I don't forget how I got here, and hopefully it saves someone else the same headaches.

---

## What's running

| Service | What it does |
|---|---|
| [Immich](https://immich.app) | Self-hosted Google Photos replacement |
| [AdGuard Home](https://adguard.com/adguard-home.html) | Whole-home ad blocking, handles DNS for the whole network |
| [Vaultwarden](https://github.com/dani-garcia/vaultwarden) | Self-hosted Bitwarden — passwords, secure notes, family sharing |
| [Glances](https://nicolargo.github.io/glances/) | Replaced a bunch of SSH aliases — CPU temp, RAM, disk, battery in one browser tab |
| [Uptime Kuma](https://github.com/louislam/uptime-kuma) | Watches all services and sends Telegram alerts if anything goes down |
| Tailscale | The thing that makes all of this accessible from anywhere without a public IP |
| Nginx | Routes `.home` URLs to the right service so I don't have to remember port numbers |

---

## Hardware

Old laptop sitting on a shelf — Intel Celeron N4500, 7.6GB RAM, 256GB NVMe. Draws very little power and handles everything without breaking a sweat. The only thing that slows it down is Immich's machine learning during large photo imports, which is expected.

---

## The problem I started with

I'm behind CGNAT — my ISP doesn't give me a real public IP, so traditional port forwarding doesn't work at all. Tailscale solved this completely. It creates an encrypted WireGuard tunnel between my devices so they can talk to each other regardless of what network they're on.

Ubuntu acts as a subnet router, which means any device connected to my Tailscale network can reach everything on my home LAN — including the router admin page at `192.168.1.1`.

---

## Network layout

```
Internet (CGNAT — no public IP, no port forwarding)
    ↓
GL.iNet Flint 2 router
DNS pointed to Ubuntu via AdGuard Home
    ↓
Ubuntu (YOUR_LAN_IP / YOUR_TAILSCALE_IP)
    ├── Immich          :2283
    ├── AdGuard Home    :3000  (DNS :53)
    ├── Vaultwarden     :443   (Nginx + Tailscale cert)
    ├── Glances         :61208
    ├── Uptime Kuma     :3001
    └── Nginx Proxy     :80    (routes .home domains)
         ↑
    Tailscale tunnel (WireGuard encrypted)
         ↑
    Phone, laptop, anything — from anywhere
```

---

## Things that didn't just work

A few things that took longer than expected and are worth knowing upfront:

**Tailscale subnet routing wasn't working** even after setup. Turned out Tailscale was only injecting its firewall rules into the IPv6 tables, completely skipping IPv4. Had to manually add the masquerade and forwarding rules to nftables, then re-authenticate to the right account (cross-account subnet routing doesn't work).

**AdGuard was sitting on port 80**, which blocked nginx from starting. The config file doesn't use `bind_port` like the docs suggest — it uses `address: 0.0.0.0:80` deep in the http section. Had to find the Docker volume, edit the yaml directly, and restart.

**Vaultwarden SMTP wasn't loading** even though the variables were in `.env`. The `env_file` directive was missing from `docker-compose.yml` so the container never saw them.

**Websocket showing as Error** in Vaultwarden diagnostics. Fixed by adding an `$http_upgrade` map to nginx.conf and passing `Upgrade` and `Connection` headers properly.

These are all documented properly in the `/docs` folder.

---

## Automated tasks

| When | What |
|---|---|
| Every hour | SSD health check pushed to Uptime Kuma |
| Daily 2am | Vaultwarden vault backed up to router + Google Drive |

If the SSD temperature spikes, spare capacity drops, or wear gets high — Telegram alert. Same if any service goes down.

---

## Docs

Setup guides are in `/docs`, written as annotated shell scripts with actual command outputs included. Each file covers one service from scratch.

| File | What it covers |
|---|---|
| [01_tailscale_subnet_routing](docs/01_tailscale_subnet_routing.md) | nftables debugging, subnet router, exit node |
| [02_adguard_home](docs/02_adguard_home.md) | Docker setup, whole-home DNS |
| [03_immich](docs/03_immich.md) | Photo storage, remote access via Tailscale |
| [04_vaultwarden](docs/04_vaultwarden.md) | Password manager, HTTPS cert, SMTP, account setup |
| [05_backup_system](docs/05_backup_system.md) | Automated backups to router and Google Drive |
| [07_monitoring](docs/07_monitoring.md) | Glances, Uptime Kuma, Telegram alerts |
| [08_reverse_proxy](docs/08_reverse_proxy.md) | Clean .home URLs, AdGuard DNS rewrites, nginx routing |
| [09_vaultwarden_websocket_fix](docs/09_vaultwarden_websocket_fix.md) | Websocket fix, nginx upgrade map |

---

## Config placeholders

Sensitive values are replaced throughout. Find and replace these before using anything:

| Placeholder | What to put |
|---|---|
| `YOUR_LAN_IP` | Ubuntu's local IP address |
| `YOUR_TAILSCALE_IP` | Ubuntu's Tailscale IP |
| `YOUR_TAILSCALE_HOST` | Your Tailscale machine hostname |
| `YOUR_ROUTER_IP` | Router's local IP |
| `YOUR_SUBNET` | Your home network subnet |
| `YOUR_GMAIL` | Gmail address for SMTP |
| `YOUR_PUSH_TOKEN` | Uptime Kuma push monitor token |

---

## Setup order

If you're starting from scratch, do it in this order or you'll run into dependency issues:

1. Tailscale subnet routing
2. Immich
3. AdGuard Home
4. Vaultwarden
5. Backup system
6. Glances + Uptime Kuma
7. Nginx reverse proxy
8. Telegram alerts
