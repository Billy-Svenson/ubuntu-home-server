###########################################################
# Tailscale Subnet Routing Setup
# Ubuntu as Subnet Router → Access LAN via Tailscale
###########################################################

################# - Network Topology - ####################
# Target:        Flint 2 Router      → YOUR_ROUTER_IP
# Subnet Router: Ubuntu Laptop       → YOUR_LAN_IP / YOUR_TAILSCALE_IP
# Client:        Phone on 5G         → Tailscale 100.x.x.x
# Subnet:        YOUR_SUBNET

###########################################################
# Diagnosis — Identify Active Firewall Backend
###########################################################

nftables
# → command not found

iptables-legacy
# → iptables v1.8.10 (legacy): no command specified

iptables-nft
# → iptables v1.8.10 (nf_tables): no command specified

cat /etc/default/ufw
# → DEFAULT_FORWARD_POLICY="DROP"
# NOTE: UFW is NOT installed — this is a leftover ghost config file
# The active firewall framework is nftables

###########################################################
# Diagnosis — Dump nftables Ruleset
###########################################################

sudo nft list ruleset
# KEY FINDINGS:
# - table ip nat     → ts-postrouting chain EMPTY (no masquerade)
# - table ip6 nat    → ts-postrouting has masquerade rule ← Tailscale wrote IPv6 only
# - table ip filter  → ts-forward chain does NOT exist
# - table ip6 filter → ts-forward chain exists with correct rules
# ROOT CAUSE: Tailscale injected its rules into ip6 tables only, missing ip (IPv4)

sudo iptables -L FORWARD -v -n
# → Chain FORWARD (policy ACCEPT)
# → Empty — no rules but ACCEPT policy so forwarding itself was fine

sudo iptables -t nat -L -v -n | grep -i masq
# → returns nothing — no masquerade rule in IPv4 nat table

###########################################################
# Fix 1 — Add Missing IPv4 MASQUERADE Rule
###########################################################

sudo nft add rule ip nat ts-postrouting meta mark and 0x0000ff00 == 0x00000400 masquerade

# Verify:
sudo nft list table ip nat
# → table ip nat {
#     chain ts-postrouting {
#         meta mark & 0x0000ff00 == 0x00000400 masquerade  ✓
#     }
# }

###########################################################
# Fix 2 — Create Missing ts-forward Chain in ip filter
###########################################################

sudo nft add chain ip filter ts-forward
sudo nft add rule ip filter ts-forward iifname "tailscale0" meta mark set mark and 0xffff04ff or 0x00000400
sudo nft add rule ip filter ts-forward meta mark and 0x0000ff00 == 0x00000400 accept
sudo nft add rule ip filter ts-forward oifname "tailscale0" accept
sudo nft add rule ip filter FORWARD jump ts-forward

###########################################################
# Fix 3 — Switch Tailscale Account (Cross-account sharing
#          does not support subnet routing)
###########################################################

sudo tailscale logout
sudo systemctl restart tailscaled
sudo tailscale up --advertise-routes=YOUR_SUBNET --snat-subnet-routes --accept-routes --advertise-exit-node
# → Opens auth URL → sign in with your Tailscale account
# → Warning: UDP GRO forwarding is suboptimally configured on enp6s0
# → Success.

sudo tailscale status
# → YOUR_TAILSCALE_IP  ubuntu  YOUR_ACCOUNT@  linux  idle; offers exit node

# NOTE: After clean re-auth, Tailscale correctly injected rules into
# BOTH ip and ip6 tables automatically. Manual rules from Fix 1 & 2
# are rebuilt properly by Tailscale itself.

###########################################################
# Tailscale Admin Console Actions (browser)
###########################################################

# https://login.tailscale.com/admin/machines
# → Find ubuntu → ... → Edit route settings
# → Enable: YOUR_SUBNET subnet route ✓
# → Enable: Use as exit node ✓
# → Enable HTTPS Certificates: login.tailscale.com/admin/dns ✓
# → MagicDNS: same DNS page → must be enabled ✓

###########################################################
# Persist nftables Rules Across Reboots
###########################################################

sudo nft list ruleset | sudo tee /etc/nftables.conf
# NOTE: Run AFTER Tailscale is connected so ts- chains are included

sudo systemctl enable nftables
# → Created symlink /etc/systemd/system/sysinit.target.wants/nftables.service

sudo systemctl start nftables

# Verify rules saved:
grep "ts-forward\|masquerade" /etc/nftables.conf
# → Should show ts-forward and masquerade in both ip and ip6 tables

###########################################################
# Verification — Packet Flow Test
###########################################################

# From Ubuntu — confirm LAN access works:
ping YOUR_ROUTER_IP
# → 64 bytes from YOUR_ROUTER_IP: icmp_seq=1 ttl=64 time=0.515 ms ✓

curl http://YOUR_ROUTER_IP
# → <!DOCTYPE html>...<title>Admin Panel</title>... ✓

# Watch tailscale0 while phone pings YOUR_ROUTER_IP:
sudo tcpdump -i tailscale0 icmp
# → IP otgonkhishigs-s22.tail248d76.ts.net > console.gl-inet.com: ICMP echo request
# → IP console.gl-inet.com > otgonkhishigs-s22.tail248d76.ts.net: ICMP echo reply
# ✅ Full round trip — phone → YOUR_ROUTER_IP → reply back

###########################################################
# Common Commands
###########################################################

# Check Tailscale status
sudo tailscale status
tailscale ip -4

# Verify IPv4 nat rules
sudo nft list chain ip nat ts-postrouting

# Verify IPv4 forward rules
sudo nft list chain ip filter ts-forward

# Packet debugging
sudo tcpdump -i tailscale0 icmp
sudo tcpdump -i enp6s0 host YOUR_ROUTER_IP
