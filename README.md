# Infrastructure

Personal infrastructure-as-code for home network devices.

## Executive Summary

**Four Devices** managed via Ansible:

| Device | Role | Key Services |
|--------|------|--------------|
| **NSA** (Debian) | Home server | Pi-hole DNS, Home Assistant, Plex, WireGuard VPN, Zigbee, ntopng, Moltbot |
| **MKT** (MikroTik) | Router | PPPoE WAN, DHCP, WiFi, Guest network |
| **Mini** (Mac) | Backup hub + LLM | Syncthing, iCloud backup, Ollama |
| **MB4** (Mac) | Workstation + LLM | Syncthing, Docker dev, LM Studio |

**Three  Networks:** managed via Ansible:

| Network | Subnet | Purpose |
|---------|--------|---------|
| LAN | 192.168.1.0/24 | Main network, Pi-hole DNS |
| Guest | 192.168.10.0/24 | Isolated, public DNS (1.1.1.1) |
| VPN | 10.0.0.0/24 | WireGuard remote access |

**Services (LAN & VPN):** all via nginx reverse proxy — no port numbers:

| Service | URL |
|---------|-----|
| Home Assistant | http://ha |
| Pi-hole Admin | http://pihole/admin |
| Plex | http://plex/web |
| Cockpit | http://nsa |
| Moltbot | https://moltbot |
| ntopng | http://ntopng |
| Static sites | http://laya, http://hopo |
| SSH | ssh richardbell@nsa |
| Syncthing | ~/Sync/ folder sync |


---

## Devices

| Device | Hostname | Type | Chip | RAM | Storage | OS |
|--------|----------|------|------|-----|---------|-----|
| NSA | nsa | Beelink SEi8 | Intel i3-8109U | 16GB DDR4 | 238GB NVMe + 1TB SATA | Debian 13 |
| Mac Mini | mini | Mac Mini | Apple M1 | 16GB | 256GB | macOS 15 |
| MacBook Pro | mb4 | MacBook Pro 14" | Apple M4 | 36GB | 512GB | macOS 15 |
| iPhone | ios | iPhone 17 Pro Max | A18 Pro | - | 512GB | iOS 18 |
| Router | mkt | MikroTik hAP ax³ | ARM64 | 1GB | 128MB | RouterOS 7.19.6 |

### Device Roles

| Device | Role | Services |
|--------|------|----------|
| NSA | Home server | Docker, VPN, DNS, Media, MQTT, Zigbee, Syncthing, Cockpit, Moltbot AI |
| Mini | Backup hub / LLM server | Syncthing, iCloud backup, Ollama |
| MB4 | Daily workstation | Syncthing, Docker (Colima) |
| iOS | Mobile | Syncthing, WireGuard VPN |
| Router | Network gateway | PPPoE, DHCP, WiFi, Guest VLAN, Firewall |

---

## Requirements & Status

### NSA (Home Server)

| # | Requirement | Status | Notes |
|---|-------------|--------|-------|
| 1 | SSH access from LAN | ✅ Done | Port 22, key-only auth |
| 2 | SSH access from VPN | ✅ Done | Via WireGuard tunnel |
| 3 | Docker containers running | ✅ Done | 8 containers: Pi-hole, Home Assistant, Plex, nginx, Mosquitto, Zigbee2MQTT, ntopng, Moltbot |
| 4 | WireGuard VPN server | ✅ Done | Port 51820, 3 peers configured (MB4, Mini, iOS) |
| 5 | Home Assistant accessible | ✅ Done | http://ha (via nginx proxy) |
| 6 | Plex media server | ✅ Done | http://plex (via nginx proxy) |
| 7 | Cockpit admin panel | ✅ Done | http://nsa (via nginx proxy) |
| 8 | nginx reverse proxy | ✅ Done | Port 80/443, all services via hostname |
| 9 | MQTT broker | ✅ Done | Port 1883 |
| 10 | Zigbee2MQTT | ✅ Done | Sonoff dongle connected |
| 11 | Firewall (nftables) | ✅ Done | Default deny, explicit allow |
| 12 | Weekly Docker backup | ✅ Done | Sun 3am → Syncthing |
| 13 | Pi-hole DNS (LAN) | ✅ Done | MikroTik pushes Pi-hole as DNS (2026-01-20) |
| 14 | Pi-hole DNS (VPN) | ✅ Done | Works via 10.0.0.1 |
| 15 | Ad-blocking (LAN) | ✅ Done | Pi-hole blocks ads network-wide |
| 16 | Ad-blocking (VPN) | ✅ Done | Works when VPN active |
| 17 | Local DNS names | ✅ Done | Pi-hole custom.list + /etc/hosts on Macs |
| 18 | Moltbot AI assistant | ✅ Done | https://moltbot (via nginx HTTPS proxy) |

### Mini (Backup Hub)

| # | Requirement | Status | Notes |
|---|-------------|--------|-------|
| 1 | SSH access | ✅ Done | Key-only auth |
| 2 | Syncthing running | ✅ Done | Syncs with NSA, MB4, iOS |
| 3 | iCloud backup | ✅ Done | Daily 3am rsync to iCloud Drive |
| 4 | Homebrew packages | ✅ Done | Managed via Ansible |
| 5 | /etc/hosts entries | ✅ Done | NSA service names |
| 6 | Ollama LLM server | ✅ Done | LAN-accessible on port 11434 |
| 7 | Auto-login after reboot | ✅ Done | LaunchAgents (Ollama, Syncthing) start without manual login |
| 8 | Always-on power settings | ✅ Done | No sleep, Wake on LAN, auto-restart after power failure |

### MB4 (Workstation)

| # | Requirement | Status | Notes |
|---|-------------|--------|-------|
| 1 | SSH access | ✅ Done | Key-only auth |
| 2 | Syncthing running | ✅ Done | Syncs with NSA, Mini, iOS |
| 3 | Homebrew packages | ✅ Done | Managed via Ansible |
| 4 | /etc/hosts entries | ✅ Done | NSA service names |
| 5 | WireGuard client | ✅ Done | Split tunnel for DNS |
| 6 | Docker (Colima) | ✅ Done | ~/docker/, Ansible managed |
| 7 | PostgreSQL container | ✅ Done | Port 5432, PostGIS 16 |
| 8 | DynamoDB Local container | ✅ Done | Port 8000, AWS emulator |
| 9 | k6 load testing | ✅ Done | On-demand (profiles: tools) |
| 10 | OpenVAS vulnerability scanner | 📋 Planned | Security scanning |
| 11 | nmap network scanner | 📋 Planned | Network reconnaissance |

### Router (MikroTik hAP ax³)

| # | Requirement | Status | Notes |
|---|-------------|--------|-------|
| 1 | DHCP server | ✅ Done | Pool 192.168.1.100-200 |
| 2 | DHCP reservations | ✅ Done | NSA, Mini static IPs |
| 3 | Port forward 51820 | ✅ Done | WireGuard VPN |
| 4 | DNS to Pi-hole | ✅ Done | Pi-hole primary, 1.1.1.1 fallback |
| 5 | PPPoE (Plusnet) | ✅ Done | Replaced Plusnet Hub Two |
| 6 | SSH access | ✅ Done | `ssh admin@mkt` |
| 7 | WiFi (2.4/5GHz) | ✅ Done | WPA2/WPA3-PSK with PMF |
| 8 | Guest WiFi | ✅ Done | SSID: guestexpress |
| 9 | Guest isolation | ✅ Done | 192.168.10.0/24, blocked from LAN |
| 10 | Ansible managed | ✅ Done | `ansible-playbook mkt.yml` |

---

## Network

### Topology

```
                            INTERNET (Plusnet ISP)
                                    │
                                    ▼
┌───────────────────────────────────────────────────────────────────┐
│                    ROUTER (MikroTik hAP ax³)                      │
│                         192.168.1.1                               │
│  WAN: PPPoE │ LAN: 192.168.1.0/24 │ Guest: 192.168.10.0/24       │
│  DHCP: .100-.200 │ DNS: Pi-hole (LAN) / 1.1.1.1 (Guest)          │
└───────────────────────────────────────────────────────────────────┘
         │                    │                    │
         ▼                    ▼                    ▼
┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐
│      NSA        │  │      Mini       │  │    MB4/iOS      │
│  192.168.1.183  │  │  192.168.1.116  │  │   DHCP Pool     │
│                 │  │                 │  │                 │
│  Pi-hole DNS    │  │  Syncthing      │  │  Syncthing      │
│  Docker         │  │  iCloud Backup  │  │  WireGuard      │
│  WireGuard VPN  │  │                 │  │                 │
│  Home Assistant │  └─────────────────┘  └─────────────────┘
│  Plex, nginx    │
└─────────────────┘
         │                              ┌─────────────────┐
         │ WireGuard VPN (10.0.0.0/24)  │  Guest WiFi     │
         ▼                              │  192.168.10.x   │
┌─────────────────┐                     │  (isolated)     │
│  Remote Clients │                     │  DNS: 1.1.1.1   │
│  10.0.0.2-254   │                     └─────────────────┘
└─────────────────┘
```

### Settings

| Setting | Value |
|---------|-------|
| WAN IP | 81.174.139.34 (static) |
| LAN Subnet | 192.168.1.0/24 |
| Guest Subnet | 192.168.10.0/24 (isolated) |
| Gateway | 192.168.1.1 (MikroTik) |
| DNS Primary | 192.168.1.183 (Pi-hole) |
| DNS Fallback | 1.1.1.1 (Cloudflare) |
| VPN Subnet | 10.0.0.0/24 |
| ISP | Plusnet FTTC |

### Static IPs (DHCP Reservations)

| Device | IP | MAC |
|--------|-----|-----|
| NSA | 192.168.1.183 | 7c:83:34:b2:c1:33 |
| Mini | 192.168.1.116 | 14:98:77:78:d6:46 |
| Router | 192.168.1.1 | 04:f4:1c:d1:38:84 |

### VPN Addresses (WireGuard)

| Device | VPN IP |
|--------|--------|
| NSA | 10.0.0.1 |
| iOS | 10.0.0.2 |
| MB4 | 10.0.0.3 |
| Mini | 10.0.0.4 |

### DNS Resolution

All DNS queries go through Pi-hole for ad-blocking and local name resolution.

**Local DNS Records (Pi-hole custom.list):**
```
192.168.1.183  nsa ha pihole plex laya hopo etc moltbot
192.168.1.116  mini
```

**Service Discovery:**
| Method | Format | Accessible From |
|--------|--------|-----------------|
| Pi-hole DNS | `nsa`, `ha`, `mini` | LAN + VPN |
| mDNS/Avahi | `nsa.local`, `mini.local` | LAN only |

## Connection Matrix

### Services (from LAN or VPN)

| Port | Service | URL | Access |
|------|---------|-----|--------|
| 22 | SSH | `ssh richardbell@nsa` | LAN + VPN |
| 53 | Pi-hole DNS | - | LAN + VPN |
| 80 | nginx proxy | http://ha, http://pihole, http://plex, etc | LAN + VPN |
| 443 | nginx HTTPS | https://moltbot (self-signed cert) | LAN + VPN |
| 1883 | MQTT | - | LAN + VPN |
| 8081 | Pi-hole Admin | http://pihole/admin (via proxy) or direct | LAN + VPN |
| 51820 | WireGuard | - | Anywhere |

### VPN Remote Access (when on conflicting 192.168.1.x network)

Many public networks use 192.168.1.0/24 which conflicts with home LAN. Use VPN IP (10.0.0.1) instead:

```bash
# Add to /etc/hosts on Mac when remote
sudo sh -c 'echo "10.0.0.1  laya hopo etc ha plex pihole nsa" >> /etc/hosts'
```

| Service | URL |
|---------|-----|
| Home Assistant | http://ha |
| Plex | http://plex/web |
| Pi-hole Admin | http://pihole/admin |
| Cockpit | http://nsa |
| Moltbot | https://moltbot |
| ntopng | http://ntopng |
| Static sites | http://laya, http://hopo |
| SSH | ssh root@10.0.0.1 |

### SSH Access

| From | To | Command |
|------|----|---------|
| MB4/Mini (LAN) | NSA | `ssh nsa` or `ssh richardbell@192.168.1.183` |
| MB4/Mini (LAN) | NSA root | `ssh root@nsa` |
| MB4 (Remote) | NSA | `ssh nsa` (via WireGuard) |
| MB4 (Remote) | Mini | `ssh mini` (via WireGuard + ProxyJump) |

### Syncthing Mesh

```
NSA ←──→ MB4
 ↑        ↑
 │        │
 ↓        ↓
Mini ←──→ iOS
```

All peers sync ~/Sync bidirectionally.

## Backup Architecture

| Source | Method | Destination | Schedule |
|--------|--------|-------------|----------|
| NSA /srv/docker | tar + Syncthing | Mini, MB4 | Weekly (Sun 3am) |
| Mini ~/Sync | rsync | iCloud Drive | Daily (3am) |
| MB4 ~/Sync | Syncthing | NSA, Mini | Real-time |

**Data flow:**
```
NSA Docker backup → ~/Sync/backups/nsa/ → Syncthing → Mini → iCloud
```

## Quick Commands

```bash
# Configure everything
ansible-playbook site.yml

# Single machine
ansible-playbook nsa.yml
ansible-playbook mini.yml
ansible-playbook mb4.yml
ansible-playbook mkt.yml

# Dry run
ansible-playbook site.yml --check --diff

# Specific tags
ansible-playbook nsa.yml --tags docker
ansible-playbook nsa.yml --tags pihole
ansible-playbook nsa.yml --tags plex
ansible-playbook mini.yml --tags icloud-backup
ansible-playbook mb4.yml --tags docker
ansible-playbook mkt.yml --tags dhcp
ansible-playbook mkt.yml --tags wifi
```

## Secrets (Ansible Vault)

Secrets stored encrypted in `vault.yml`. Password retrieved from macOS Keychain automatically via `~/.ansible/vault-pass.sh`.

### Git Hooks (Security)

Two git hooks prevent accidental commit/push of unencrypted secrets:

| Hook | Trigger | Protection |
|------|---------|------------|
| `pre-commit` | Before commit | Blocks if staged `vault.yml` is not encrypted |
| `pre-push` | Before push | Scans all commits being pushed for unencrypted vault |

Hooks are in `.githooks/` (tracked by git). After cloning, tell git where to find them:
```bash
git config core.hooksPath .githooks
```

To bypass in emergency (NOT recommended): `git commit --no-verify`

```bash
# Edit vault
ansible-vault edit vault.yml

# View vault
ansible-vault view vault.yml

# Re-encrypt with new password
ansible-vault rekey vault.yml
```

### Vault Contents

| Variable | Purpose |
|----------|---------|
| vault_wireguard_private_key | VPN server key |
| vault_wireguard_peers | VPN peer configs |
| vault_mqtt_password | MQTT broker auth |
| vault_pihole_password | Pi-hole admin |
| vault_plex_claim | Plex setup token |
| vault_macos_ssh_key | Mac SSH key |
| vault_ssh_authorized_keys | SSH public keys |
| vault_mikrotik_admin_password | Router admin |
| vault_mikrotik_pppoe_username/password | ISP credentials |
| vault_mikrotik_wifi_ssid/password | Main WiFi |
| vault_mikrotik_guest_ssid/password | Guest WiFi |
| vault_moltbot_token | Moltbot API token |
| vault_mini_login_password | Mini macOS login password (auto-login) |

## Testing

```bash
# Quick smoke test (~30 seconds)
./tests/quick-check.sh

# Full test suite (~2-3 minutes)
./tests/run-all.sh

# MikroTik router tests only
./tests/test-mkt.sh
```

See `tests/README.md` for details.

### Manual Verification Log

| Date | Test | Result | Notes |
|------|------|--------|-------|
| 2026-01-29 | Comprehensive LAN test | ✅ Pass | DNS (9/9), SSH (3/3), HTTP services (8/8), Ollama, MikroTik |
| 2026-01-29 | Plex HTTPS requirement | ⚠️ Note | HTTP returns empty reply; HTTPS works. Bookmarks updated to `https://` |
| 2026-01-29 | Ollama LAN access | ✅ Pass | `http://192.168.1.116:11434/` responds, qwen2.5:14b model loaded |
| 2026-01-21 | iOS WireGuard VPN | ✅ Pass | 10.0.0.2, Pi-hole/Plex accessible from mobile |
| 2026-01-21 | Guest network isolation | ✅ Pass | 192.168.10.x, internet works, LAN blocked |
| 2026-01-21 | WireGuard full tunnel | ✅ Pass | Remote access to ha, pihole, plex |
| 2026-01-21 | Tests via VPN | ✅ Pass | 25/25 MikroTik tests from offsite |
| 2026-01-20 | Pi-hole DNS from LAN | ✅ Pass | `dig @192.168.1.183 google.com` works |
| 2026-01-20 | MikroTik Ansible tests | ✅ Pass | 25/25 tests passed |
| 2026-01-20 | Guest WiFi | ✅ Pass | SSID guestexpress working |
| 2026-01-16 | WireGuard split tunnel DNS | ✅ Pass | `dig @10.0.0.1 google.com` resolves correctly |
| 2026-01-16 | Pi-hole ad-blocking via VPN | ✅ Pass | `ads.google.com` → `0.0.0.0` (blocked) |

## NSA Server Baseline

Before running Ansible, NSA needs:

1. Debian 13 (trixie) installed
2. User `richardbell` with sudo access
3. SSH enabled, key copied
4. Static IP or DHCP reservation
5. 1TB SATA SSD mounted at `/mnt/data`

### NSA Firewall Ports

| Port | Protocol | Service | Access |
|------|----------|---------|--------|
| 22 | TCP | SSH | LAN + VPN |
| 53 | TCP/UDP | DNS (Pi-hole) | LAN + VPN |
| 80 | TCP | HTTP (nginx) | LAN + VPN |
| 443 | TCP | Pi-hole Admin (HTTPS) | LAN + VPN |
| 1883 | TCP | MQTT | LAN + VPN |
| 8123 | TCP | Home Assistant | LAN + VPN |
| 9090 | TCP | Cockpit | LAN + VPN |
| 32400 | TCP | Plex | LAN + VPN |
| 3000 | TCP | ntopng | LAN + VPN |
| 18789 | TCP | Moltbot | LAN + VPN |
| 51820 | UDP | WireGuard | Anywhere |

## File Locations

### NSA
| Item | Path |
|------|------|
| Docker compose | /srv/docker/docker-compose.yml |
| Docker data | /srv/docker/{service}/ |
| Media library | /mnt/data/media/ |
| Backups | /mnt/data/backups/ |
| Firewall | /etc/nftables.conf |
| WireGuard | /etc/wireguard/wg0.conf |

### macOS (Mini, MB4)
| Item | Path |
|------|------|
| Sync folder | ~/Sync/ |
| Backup script | ~/bin/sync-backup.sh |
| Backup log | ~/Library/Logs/sync-backup.log |
| LaunchAgents | ~/Library/LaunchAgents/ |

### Local LLM Models

| Device | Server | Model | Quant | Size | Path |
|--------|--------|-------|-------|------|------|
| Mini | Ollama | qwen2.5:14b | Q4_K_M | 9GB | ~/.ollama/models/ |
| MB4 | LM Studio | Qwen2.5-32B-Instruct | Q6_K | 25GB | ~/.lmstudio/models/ |

### MB4 Docker (Colima)
| Item | Path |
|------|------|
| Docker compose | ~/docker/docker-compose.yml |
| PostgreSQL data | ~/docker/postgres/data/ |
| DynamoDB data | ~/docker/dynamodb/data/ |
| k6 scripts | ~/docker/k6/scripts/ |
| Environment | ~/docker/.env |

## NSA Storage Architecture

NSA has a two-tier storage setup balancing speed and capacity:

| Drive | Size | Type | Mount | Purpose |
|-------|------|------|-------|---------|
| NVMe | 256GB | PCIe NVMe | `/` | Fast tier - OS, Docker, databases |
| SATA SSD | 1TB | 2.5" SATA | `/mnt/data` | Capacity tier - media, backups |

### Fast Tier (NVMe) - What lives here

| Path | Contents | Why NVMe |
|------|----------|----------|
| `/` | Debian OS | Fast boot |
| `/srv/docker/` | Docker Compose + container configs | Fast container startup |
| `/var/lib/docker/` | Container images, volumes | I/O intensive |
| Pi-hole SQLite | DNS query database | Frequent writes |
| Home Assistant DB | Event/state history | Frequent writes |
| Syncthing index | File metadata | Random I/O |

### Capacity Tier (SATA SSD) - What lives here

| Path | Contents | Why SATA |
|------|----------|----------|
| `/mnt/data/media/` | Plex library (movies, TV, music) | Large files, sequential reads |
| `/mnt/data/backups/` | Docker backup archives | Weekly writes, large files |
| `/mnt/data/ntopng/` | Network traffic data (30 day retention) | Moderate writes, searchable |
| `/mnt/data/transcode/` | Plex transcoding temp | Can be slow, disposable |
| `/mnt/data/downloads/` | Staging area for new media | Temporary storage |

### Capacity Planning

| Drive | Used | Available | Headroom |
|-------|------|-----------|----------|
| NVMe | ~40GB | ~200GB | Plenty for Docker growth |
| SATA | TBD | ~1TB | Media library expansion |

**Note:** Monitor with `df -h` - if NVMe exceeds 80%, consider moving large Docker volumes to SATA.

## Disaster Recovery

### NSA Full Rebuild
1. Install Debian 13 minimal (server, SSH only, no desktop)
2. Create user `richardbell` with sudo
3. Enable root SSH: `echo "PermitRootLogin yes" >> /etc/ssh/sshd_config`
4. Copy SSH key from Mac: `ssh-copy-id root@192.168.1.183`
5. Mount data drive at `/mnt/data` (UUID: 56380a4f-8876-4b77-9dc0-7d0d8ab7d948)
6. Remove brltty if Zigbee dongle not detected: `apt remove brltty`
7. Run from Mac: `ansible-playbook nsa.yml`
8. Restore Docker data from backup (see `docs/nsa-migration.md`)

### Recovery Access
- Cockpit: http://nsa (via nginx proxy) or https://192.168.1.183:9090 (direct)
- Physical access to Beelink

## Conventions

| Item | Value |
|------|-------|
| Username | richardbell |
| SSH key type | ed25519 |
| Sync folder | ~/Sync/ |
| Admin group | sudo (Linux), wheel (macOS) |
| Timezone | Europe/London |
