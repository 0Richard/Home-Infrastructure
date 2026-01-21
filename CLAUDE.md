# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

**See `README.md` for full requirements and status per machine.**

## Project Overview

Personal infrastructure-as-code (Ansible) managing a home network with four devices:

- **NSA** (`192.168.1.183`): Debian 13 home server running Docker containers (Pi-hole, Home Assistant, Plex, WireGuard, nginx, Mosquitto, Zigbee2MQTT) + Cockpit web admin
- **Mini** (`192.168.1.116`): Mac Mini M1 for Syncthing and iCloud backup
- **MB4**: MacBook Pro M4 workstation with Syncthing and Docker (Colima) for local dev
- **MKT** (`192.168.1.1`): MikroTik hAP ax³ router (PPPoE WAN, DHCP, firewall, WiFi)

## Commands

```bash
# Run playbooks (vault password auto-retrieved from macOS Keychain)
ansible-playbook site.yml          # All hosts
ansible-playbook nsa.yml           # NSA only
ansible-playbook mini.yml          # Mini only
ansible-playbook mb4.yml           # MB4 only
ansible-playbook mkt.yml           # MikroTik router only

# Dry run with diff
ansible-playbook nsa.yml --check --diff

# Run specific tags
ansible-playbook nsa.yml --tags docker
ansible-playbook nsa.yml --tags pihole
ansible-playbook nsa.yml --tags wireguard
ansible-playbook mb4.yml --tags hosts    # Update /etc/hosts entries
ansible-playbook mb4.yml --tags docker   # Set up Colima + dev containers
ansible-playbook mkt.yml --tags dhcp     # DHCP server config
ansible-playbook mkt.yml --tags firewall # NAT and filter rules

# Available tags: common, ssh, cockpit, avahi, docker, colima, nftables, pihole, wireguard, syncthing, backup, plex, homebrew, icloud-backup, mackup, hosts, dns, identity, bridge, network, ip, pppoe, wan, dhcp, nat, filter, wifi, wireless, services, security

# Vault operations
ansible-vault view vault.yml
ansible-vault edit vault.yml

# Testing
./tests/quick-check.sh             # Fast smoke test
./tests/run-all.sh                 # Full test suite
```

## Architecture

```
site.yml                    # Master playbook - imports all host playbooks
├── nsa.yml                 # Linux server: Docker services, firewall, VPN
├── mini.yml                # macOS: Syncthing, iCloud backup, Homebrew
├── mb4.yml                 # macOS: Syncthing, Homebrew
└── mkt.yml                 # MikroTik router: PPPoE, DHCP, firewall, WiFi

tasks/                      # Reusable task modules
├── common.yml              # SSH dirs, shell config, Sync folder
├── ssh.yml                 # SSH keys, hardening (Linux)
├── cockpit.yml             # Web admin interface (Linux)
├── avahi.yml               # mDNS for .local resolution (Linux)
├── docker.yml              # Docker install, compose deployment
├── nftables.yml            # Linux firewall rules
├── pihole.yml              # Pi-hole config, disable dnsmasq
├── wireguard.yml           # VPN server config
├── syncthing-{linux,macos}.yml
├── backup.yml              # Docker backup script + cron
├── icloud-backup.yml       # rsync to iCloud (Mini only)
├── homebrew.yml            # Homebrew packages/casks
├── mackup.yml              # App settings backup (macOS)
├── hosts-macos.yml         # /etc/hosts entries for NSA services
├── plex.yml                # Media server directories
└── mikrotik/               # MikroTik router tasks
    ├── identity.yml        # Router name
    ├── bridge.yml          # LAN bridge config
    ├── ip-address.yml      # LAN IP
    ├── dhcp-server.yml     # DHCP pool, leases, DNS
    ├── pppoe.yml           # WAN PPPoE connection
    ├── firewall-nat.yml    # NAT masquerade, port forwards
    ├── firewall-filter.yml # Input/forward chain rules
    ├── wifi.yml            # WiFi config
    └── services.yml        # Enable/disable services

files/nsa/                  # Static config files deployed to NSA
├── docker-compose.yml      # All Docker service definitions
├── nftables.conf           # Firewall rules (IPv4 + IPv6)
├── nginx.conf              # Virtual hosts (laya, hopo, etc)
├── mosquitto.conf          # MQTT broker config
└── pihole/custom.list      # Local DNS entries

templates/nsa/              # Jinja2 templates
├── wg0.conf.j2             # WireGuard config (uses vault peers)
└── docker.env.j2           # Docker environment vars

group_vars/                 # Variables by group
├── linux_servers.yml       # Linux-specific (apt, systemd)
├── macos.yml               # macOS-specific (homebrew paths)
└── network_devices.yml     # MikroTik connection settings

host_vars/                  # Variables by host (override group_vars)
├── nsa.yml                 # NSA-specific config
├── mini.yml                # Mini-specific config
├── mb4.yml                 # MB4-specific config
└── mkt.yml                 # MikroTik router config

docs/                       # Documentation
├── guest-wifi-qr.png       # Guest WiFi QR code
└── nsa-migration.md        # NSA rebuild runbook
```

## NSA Services

| Service | Port | URL | Notes |
|---------|------|-----|-------|
| Home Assistant | 8123 | http://ha.local:8123 | Smart home |
| Pi-hole Admin | 443 | https://pihole.local/admin | HTTPS (v6), LAN + VPN |
| Plex | 32400 | http://plex.local:32400/web | Media server |
| nginx | 80 | http://laya.local, http://hopo.local | Static sites |
| Cockpit | 9090 | https://nsa.local:9090 | Server admin |
| Mosquitto | 1883 | - | MQTT broker |
| WireGuard | 51820 | - | VPN (external) |

## NSA Storage

Two-tier storage balancing speed and capacity:

| Drive | Size | Mount | Use |
|-------|------|-------|-----|
| NVMe | 256GB | `/` | OS, Docker, databases |
| SATA SSD | 1TB | `/mnt/data` | Media, backups |

Key paths:
- `/srv/docker/` - Docker Compose and configs (NVMe)
- `/mnt/data/media/` - Plex library (SATA)
- `/mnt/data/backups/` - Docker backup archives (SATA)

## Vault

Password retrieved automatically from macOS Keychain via `~/.ansible/vault-pass.sh`.

Key variables in `vault.yml`:
- `vault_wireguard_private_key`, `vault_wireguard_peers` - VPN config
- `vault_pihole_password` - Pi-hole admin
- `vault_plex_claim` - Plex setup token (expires in 4 min, get from plex.tv/claim)
- `vault_ssh_authorized_keys` - SSH public keys
- `vault_mikrotik_admin_password` - Router admin password
- `vault_mikrotik_pppoe_username`, `vault_mikrotik_pppoe_password` - ISP credentials
- `vault_mikrotik_wifi_ssid`, `vault_mikrotik_wifi_password` - WiFi config
- `vault_mikrotik_guest_ssid`, `vault_mikrotik_guest_password` - Guest WiFi config

## Network

- LAN IPv4: `192.168.1.0/24`, Gateway: `192.168.1.1` (MikroTik hAP ax³)
- LAN IPv6: `fd7a:94b4:f195:7248::/64`
- VPN: `10.0.0.0/24` (WireGuard on NSA)
- DNS: Pi-hole at `192.168.1.183:53` (primary), 1.1.1.1 (fallback)
- mDNS: Avahi for `.local` resolution (e.g., `nsa.local`)
- Router: MikroTik hAP ax³ (replaced Plusnet Hub Two on 2026-01-20)
- All services accessible from LAN or VPN only (except WireGuard port 51820)

## Known Issues

| Issue | Status | Notes |
|-------|--------|-------|
| Pi-hole DNS not responding | 🔴 Active | DNS queries to 192.168.1.183 timeout; container shows healthy but FTL not responding. Restart container to temporarily fix. |
| iCloud Private Relay incompatible | ℹ️ Info | Guest WiFi shows "not compatible with Private Relay" - expected for IPv4-only networks. |

## Resolved Issues

| Issue | Resolution | Date |
|-------|------------|------|
| Network issues (browsers/NSA failing) | Removed duplicate `bridge-lan` - must use existing `bridge` (defconf). Set `bridge_name: bridge` in host_vars/mkt.yml. | 2026-01-20 |
| Browsers not loading (curl works) | Added MSS clamping for PPPoE (MTU 1492). Without it, large TCP packets (TLS handshakes) fail silently. | 2026-01-20 |

## Verified Tests

| Date | Test | Result |
|------|------|--------|
| 2026-01-20 | MikroTik Ansible (25 tests) | ✅ Pass - `./tests/test-mkt.sh` |
| 2026-01-20 | Guest WiFi connection | ✅ Pass - SSID `guestexpress` working |
| 2026-01-20 | WiFi PMF (management-protection) | ✅ Pass - Apple security warning resolved |
| 2026-01-16 | WireGuard split tunnel DNS | ✅ Pass - `dig @10.0.0.1 google.com` resolves |
| 2026-01-16 | Pi-hole ad-blocking via VPN | ✅ Pass - `ads.google.com` returns `0.0.0.0` |
