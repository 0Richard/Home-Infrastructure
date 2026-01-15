# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

**See `README.md` for full requirements and status per machine.**

## Project Overview

Personal infrastructure-as-code (Ansible) managing a home network with three devices:

- **NSA** (`192.168.1.183`): Debian 13 home server running Docker containers (Pi-hole, Home Assistant, Plex, WireGuard, nginx, Mosquitto, Zigbee2MQTT) + Cockpit web admin
- **Mini** (`192.168.1.116`): Mac Mini M1 for Syncthing and iCloud backup
- **MB4**: MacBook Pro M4 workstation with Syncthing and Docker (Colima) for local dev

## Commands

```bash
# Run playbooks (vault password auto-retrieved from macOS Keychain)
ansible-playbook site.yml          # All hosts
ansible-playbook nsa.yml           # NSA only
ansible-playbook mini.yml          # Mini only
ansible-playbook mb4.yml           # MB4 only

# Dry run with diff
ansible-playbook nsa.yml --check --diff

# Run specific tags
ansible-playbook nsa.yml --tags docker
ansible-playbook nsa.yml --tags pihole
ansible-playbook nsa.yml --tags wireguard
ansible-playbook mb4.yml --tags hosts    # Update /etc/hosts entries
ansible-playbook mb4.yml --tags docker   # Set up Colima + dev containers

# Available tags: common, ssh, cockpit, avahi, docker, colima, nftables, pihole, wireguard, syncthing, backup, plex, homebrew, icloud-backup, mackup, hosts, dns

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
└── mb4.yml                 # macOS: Syncthing, Homebrew

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
└── plex.yml                # Media server directories

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
└── macos.yml               # macOS-specific (homebrew paths)

host_vars/                  # Variables by host (override group_vars)
├── nsa.yml                 # NSA-specific config
├── mini.yml                # Mini-specific config
└── mb4.yml                 # MB4-specific config

docs/                       # Documentation
├── network-design.md       # Network architecture
├── nsa-migration.md        # NSA rebuild runbook
└── known-issues.md         # Current issues and workarounds
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

## Network

- LAN IPv4: `192.168.1.0/24`, Gateway: `192.168.1.254`
- LAN IPv6: `fd7a:94b4:f195:7248::/64`
- VPN: `10.0.0.0/24` (WireGuard on NSA)
- DNS: Pi-hole at `192.168.1.183:53` - **blocked on LAN by router** (see Known Issues)
- mDNS: Avahi for `.local` resolution (e.g., `nsa.local`)
- Hosts file: macOS clients have `/etc/hosts` entries as DNS workaround
- DNS redirect: Configured but ineffective (router intercepts before packets reach NSA)
- All services accessible from LAN or VPN only (except WireGuard port 51820)

See `docs/network-design.md` for full network architecture.

## Known Issues

See `docs/known-issues.md` for current issues and workarounds.

**Active Issues:**
- **Pi-hole DNS** - Plusnet Hub Two router intercepts ALL UDP port 53 traffic on LAN. Root cause: router DNS interception (not configurable). Workarounds:
  - `/etc/hosts` entries on macOS clients (name resolution only, no ad-blocking)
  - WireGuard split tunnel routes DNS via VPN to 10.0.0.1 (full Pi-hole functionality)
