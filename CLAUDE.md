# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

**See `README.md` for full requirements and status per machine.**

## Project Overview

Personal infrastructure-as-code (Ansible) managing a home network with four devices:

- **NSA** (`192.168.1.183`): Debian 13 home server running Docker containers (Pi-hole, Home Assistant, Plex, WireGuard, nginx, Mosquitto, Zigbee2MQTT, ntopng, Moltbot) + Cockpit web admin
- **Mini** (`192.168.1.116`): Mac Mini M1 for Syncthing, iCloud backup, and Ollama LLM (Moltbot backend)
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

# Available tags: common, ssh, cockpit, avahi, docker, colima, ssl, https, nftables, pihole, wireguard, syncthing, backup, plex, moltbot, ollama, power, autologin, homebrew, icloud-backup, mackup, hosts, dns, identity, bridge, network, ip, pppoe, wan, dhcp, nat, filter, wifi, wireless, services, security, traffic-flow, monitoring

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
├── ssl.yml                 # Self-signed cert for Moltbot HTTPS
├── moltbot.yml             # Moltbot AI assistant directories
├── ollama.yml              # Ollama LLM server (Mini)
└── mikrotik/               # MikroTik router tasks
    ├── identity.yml        # Router name
    ├── bridge.yml          # LAN bridge config
    ├── ip-address.yml      # LAN IP
    ├── dhcp-server.yml     # DHCP pool, leases, DNS
    ├── pppoe.yml           # WAN PPPoE connection
    ├── firewall-nat.yml    # NAT masquerade, port forwards
    ├── firewall-filter.yml # Input/forward chain rules
    ├── wifi.yml            # WiFi config
    ├── guest-network.yml   # Guest isolation (192.168.10.0/24)
    ├── traffic-flow.yml    # NetFlow export to ntopng
    └── services.yml        # Enable/disable services

files/nsa/                  # Static config files deployed to NSA
├── docker-compose.yml      # All Docker service definitions
├── nftables.conf           # Firewall rules (IPv4 + IPv6)
├── nginx.conf              # Reverse proxy config (all services)
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

**URLs that work on both LAN and VPN** (use short hostnames, not `.local`):

All browser services are accessible via nginx reverse proxy — no port numbers needed.

| Service | URL | Notes |
|---------|-----|-------|
| Home Assistant | http://ha | WebSocket supported |
| Pi-hole Admin | http://pihole/admin | Direct: http://192.168.1.183:8081/admin |
| Plex | http://plex/web | |
| Cockpit | http://nsa | Proxies to Cockpit HTTPS on 9090 |
| Moltbot | https://moltbot | HTTPS required (WebSocket secure context) |
| ntopng | http://ntopng | |
| Laya | http://laya | Static site |
| Hopo | http://hopo | Static site |
| Docs | http://docs | README + service directory |
| Mosquitto | - | Port 1883 (not browser) |
| WireGuard | - | Port 51820 (not browser) |

**Note:** Short hostnames (e.g., `ha`, `pihole`) are resolved by Pi-hole DNS and work over both LAN and WireGuard VPN. `.local` variants (e.g., `ha.local`) use mDNS (Avahi) and only work on LAN.

## Moltbot + Ollama Architecture

Moltbot gateway runs on NSA (Docker), connects to Ollama on Mini (192.168.1.116:11434) as its LLM backend.

**Config:** Explicit provider config in `docker-compose.yml` moltbot-gateway `command` block (JSON written to `clawdbot.json` on first run). Remote Ollama requires `api: "openai-completions"`, `baseUrl`, `apiKey`, and full `models` array with object entries.

**Model:** `qwen2.5:7b-16k` — custom Ollama model created with `num_ctx: 16384` to meet gateway's 16K minimum context window. The 14B model is available but too slow for agentic chat on M1 16GB (~84s vs ~12s for 7B).

**Creating custom Ollama models on Mini:**
```bash
curl -s http://192.168.1.116:11434/api/create -d '{"model":"qwen2.5:7b-16k","from":"qwen2.5:7b","parameters":{"num_ctx":16384}}'
```

**Key constraints:**
- Gateway minimum context: 16,000 tokens (errors below this, warns below 32K)
- Ollama default `num_ctx`: 4096 (too small — gateway rejects it)
- 14B + 16K context uses ~10GB VRAM on M1 — functional but slow for agentic mode
- 7B + 16K context uses ~5.4GB VRAM — acceptable speed (~12s warm response)

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
- `/mnt/data/ntopng/` - Network traffic data, 30 day retention (SATA)

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
- `vault_moltbot_token` - Moltbot API token
- `vault_mini_login_password` - Mini macOS login password (for auto-login after reboot)

## Network

- WAN: `81.174.139.34` (static IP from Plusnet)
- LAN IPv4: `192.168.1.0/24`, Gateway: `192.168.1.1` (MikroTik hAP ax³)
- Guest IPv4: `192.168.10.0/24`, Gateway: `192.168.10.1` (isolated, public DNS)
- LAN IPv6: `fd7a:94b4:f195:7248::/64`
- VPN: `10.0.0.0/24` (WireGuard on NSA, endpoint: 81.174.139.34:51820)
- DNS: Pi-hole at `192.168.1.183:53` (LAN), 1.1.1.1/8.8.8.8 (guest)
- mDNS: Avahi for `.local` resolution (e.g., `nsa.local`)
- Router: MikroTik hAP ax³ (replaced Plusnet Hub Two on 2026-01-20)
- All services accessible from LAN or VPN only (except WireGuard port 51820)
- Guest network isolated: can reach internet, blocked from LAN (192.168.1.0/24)

## Known Issues

| Issue | Status | Notes |
|-------|--------|-------|
| VPN not connected on MB4 (LAN) | ℹ️ Info | WireGuard VPN shows disconnected when MB4 is on LAN — expected, not needed on home network. |
| Moltbot self-signed cert | ℹ️ Info | `https://moltbot` uses self-signed cert. Browser shows warning on first visit — click "Proceed" once, then it's remembered. |
| iCloud Private Relay incompatible | ℹ️ Info | Guest WiFi shows "not compatible with Private Relay" - expected for IPv4-only networks. |

## Resolved Issues

| Issue | Resolution | Date |
|-------|------------|------|
| Pi-hole DNS not working on Mac | Removed legacy `/etc/hosts` entries (10.0.0.1) that were overriding Pi-hole DNS. Pi-hole now handles local hostnames. | 2026-01-21 |
| Network issues (browsers/NSA failing) | Removed duplicate `bridge-lan` - must use existing `bridge` (defconf). Set `bridge_name: bridge` in host_vars/mkt.yml. | 2026-01-20 |
| Browsers not loading (curl works) | Added MSS clamping for PPPoE (MTU 1492). Without it, large TCP packets (TLS handshakes) fail silently. | 2026-01-20 |

## Verified Tests

| Date | Test | Result |
|------|------|--------|
| 2026-01-29 | Comprehensive network test | ✅ Pass - 9/9 DNS, 3/3 SSH, 8/8 HTTP services, Ollama LAN access |
| 2026-01-29 | Plex HTTPS requirement | ⚠️ Note - HTTP returns empty reply, HTTPS works (302). Updated bookmarks to `https://` |
| 2026-01-29 | Ollama LAN access | ✅ Pass - `http://192.168.1.116:11434/` responds, qwen2.5:7b-16k active for Moltbot |
| 2026-01-29 | MikroTik router health | ✅ Pass - RouterOS 7.19.6, uptime 9+ days, 2% CPU |
| 2026-01-21 | Guest WiFi isolation | ✅ Pass - Internet works, LAN blocked (192.168.1.x unreachable) |
| 2026-01-21 | WireGuard full tunnel (mobile) | ✅ Pass - ping 10.0.0.1, http://ha:8123, https://pihole/admin |
| 2026-01-21 | Pi-hole DNS (LAN) | ✅ Pass - All hostnames resolve via 192.168.1.183 |
| 2026-01-20 | MikroTik Ansible (25 tests) | ✅ Pass - `./tests/test-mkt.sh` |
| 2026-01-20 | Guest WiFi connection | ✅ Pass - SSID `guestexpress` working |
| 2026-01-20 | WiFi PMF (management-protection) | ✅ Pass - Apple security warning resolved |
| 2026-01-16 | WireGuard split tunnel DNS | ✅ Pass - `dig @10.0.0.1 google.com` resolves |
| 2026-01-16 | Pi-hole ad-blocking via VPN | ✅ Pass - `ads.google.com` returns `0.0.0.0` |
