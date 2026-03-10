# Ubuntu Home Server

A complete self-hosted home server setup running on an Ubuntu laptop behind CGNAT, accessible anywhere via Tailscale.

## Hardware

| Component | Spec |
|---|---|
| CPU | Intel Celeron N4500 |
| RAM | 7.6GB |
| Storage | 256GB NVMe SSD |
| Network | GL.iNet Flint 2 (MT6000) router |
| ISP | 500/500 Mbps — behind CGNAT |

## Stack

| Service | Purpose | Access |
|---|---|---|
| [Immich](https://immich.app) | Self-hosted photo storage | `http://immich.home` |
| [AdGuard Home](https://adguard.com/adguard-home.html) | Whole-home ad blocking + DNS | `http://adguard.home` |
| [Vaultwarden](https://github.com/dani-garcia/vaultwarden) | Self-hosted password manager | `https://YOUR_TAILSCALE_HOST` |
| [Glances](https://nicolargo.github.io/glances/) | System monitor (CPU, RAM, disk, temp) | `http://glances.home` |
| [Uptime Kuma](https://github.com/louislam/uptime-kuma) | Service uptime monitoring + alerts | `http://kuma.home` |
| [Tailscale](https://tailscale.com) | Remote access via WireGuard tunnel | — |
| Nginx | Reverse proxy for `.home` URLs | — |

## Network Architecture

```
Internet (CGNAT — no port forwarding)
    ↓
GL.iNet Flint 2 (YOUR_ROUTER_IP)
DNS → Ubuntu (YOUR_LAN_IP) via AdGuard Home
    ↓
Ubuntu (YOUR_LAN_IP / YOUR_TAILSCALE_IP)
    ├── Immich          :2283
    ├── AdGuard Home    :3000  (DNS :53)
    ├── Vaultwarden     :443   (via Nginx + Tailscale cert)
    ├── Glances         :61208
    ├── Uptime Kuma     :3001
    └── Nginx Proxy     :80    (.home URL routing)
         ↑
    Tailscale tunnel (WireGuard)
         ↑
    Any device anywhere
```

## Remote Access

CGNAT means no public IP and no port forwarding. Tailscale is the only remote access solution. Ubuntu acts as:
- **Subnet router** — expose full LAN (YOUR_SUBNET) to Tailscale devices
- **Exit node** — route all traffic through home IP (useful for bypassing geo-restrictions)

## Automated Tasks

| Schedule | Task |
|---|---|
| Daily 2am | Vaultwarden backup → Router + Google Drive |
| Every hour | SSD health check → Uptime Kuma push |

## Alerts

Telegram bot alerts via Uptime Kuma when:
- Any service goes down
- SSD temperature ≥ 70°C
- SSD available spare ≤ 20%
- SSD wear ≥ 80%
- Media integrity errors detected

## Directory Structure

```
.
├── docs/               # Step-by-step setup guides
├── immich/             # Immich + AdGuard docker-compose
├── vaultwarden/        # Vaultwarden + Nginx config
├── monitoring/         # Glances + Uptime Kuma docker-compose
├── proxy/              # Nginx reverse proxy for .home URLs
└── scripts/            # Backup and monitoring scripts
```

## Docs

| File | Contents |
|---|---|
| [01_tailscale_subnet_routing](docs/01_tailscale_subnet_routing.md) | nftables fixes, subnet router setup |
| [02_adguard_home](docs/02_adguard_home.md) | Whole-home ad blocking setup |
| [03_immich](docs/03_immich.md) | Photo storage + remote access |
| [04_vaultwarden](docs/04_vaultwarden.md) | Password manager + SMTP + HTTPS |
| [05_backup_system](docs/05_backup_system.md) | Automated backups to router + Google Drive |
| [07_monitoring](docs/07_monitoring.md) | Glances + Uptime Kuma + Telegram alerts |
| [08_reverse_proxy](docs/08_reverse_proxy.md) | Clean .home URLs via nginx + AdGuard DNS |
| [09_vaultwarden_websocket_fix](docs/09_vaultwarden_websocket_fix.md) | Websocket fix for real-time vault sync |

## Setup Order

1. Tailscale subnet routing
2. Immich
3. AdGuard Home
4. Vaultwarden
5. Backup system
6. Monitoring (Glances + Uptime Kuma)
7. Reverse proxy
8. Telegram alerts

## Sensitive Values

All sensitive values in config files are replaced with placeholders:

| Placeholder | Replace with |
|---|---|
| `YOUR_LAN_IP` | Your Ubuntu LAN IP |
| `YOUR_TAILSCALE_IP` | Your Tailscale IP |
| `YOUR_TAILSCALE_HOST` | Your Tailscale hostname |
| `YOUR_ROUTER_IP` | Your router LAN IP |
| `YOUR_GMAIL` | Your Gmail address |
| `YOUR_PUSH_TOKEN` | Your Uptime Kuma push token |
| `YOUR_SUBNET` | Your LAN subnet |
