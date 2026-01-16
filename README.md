# Infrastructure

Personal infrastructure-as-code for home network devices.

## Devices

| Device | Hostname | Type | Chip | RAM | Storage | OS |
|--------|----------|------|------|-----|---------|-----|
| NSA | nsa | Beelink SEi8 | Intel i3-8109U | 16GB DDR4 | 238GB NVMe + 1TB SATA | Debian 13 |
| Mac Mini | mini | Mac Mini | Apple M1 | 8GB | 256GB | macOS 15 |
| MacBook Pro | mb4 | MacBook Pro 14" | Apple M4 | 48GB | 512GB | macOS 15 |
| iPhone | ios | iPhone 17 Pro Max | A18 Pro | - | 512GB | iOS 18 |
| Router | - | Plusnet Hub Two | - | - | - | v0.10.00.04201-PN |

### Device Roles

| Device | Role | Services |
|--------|------|----------|
| NSA | Home server | Docker, VPN, DNS, Media, MQTT, Zigbee, Syncthing, Cockpit |
| Mini | Dev server / Backup hub | Syncthing, iCloud backup |
| MB4 | Daily workstation | Syncthing, Docker (Colima) |
| iOS | Mobile | Syncthing |
| Router | Network gateway | DHCP, WAN |

---

## Requirements & Status

### NSA (Home Server)

| # | Requirement | Status | Notes |
|---|-------------|--------|-------|
| 1 | SSH access from LAN | ✅ Done | Port 22, key-only auth |
| 2 | SSH access from VPN | ✅ Done | Via WireGuard tunnel |
| 3 | Docker containers running | ✅ Done | 6 containers: Pi-hole, Home Assistant, Plex, nginx, Mosquitto, Zigbee2MQTT |
| 4 | WireGuard VPN server | ✅ Done | Port 51820, 2 peers configured |
| 5 | Home Assistant accessible | ✅ Done | Port 8123 |
| 6 | Plex media server | ✅ Done | Port 32400 |
| 7 | Cockpit admin panel | ✅ Done | Port 9090 |
| 8 | nginx static sites | ✅ Done | Port 80 (laya, hopo, etc) |
| 9 | MQTT broker | ✅ Done | Port 1883 |
| 10 | Zigbee2MQTT | ✅ Done | Sonoff dongle connected |
| 11 | Firewall (nftables) | ✅ Done | Default deny, explicit allow |
| 12 | Weekly Docker backup | ✅ Done | Sun 3am → Syncthing |
| 13 | **Pi-hole DNS (LAN)** | ❌ Blocked | Router intercepts UDP 53. **Plan:** Replace router or use Pi-hole DHCP |
| 14 | **Pi-hole DNS (VPN full)** | ❌ Blocked | Same router issue. **Plan:** Fix with LAN fix |
| 15 | **Pi-hole DNS (VPN split)** | ✅ Done | Works via 10.0.0.1 (verified 2026-01-16) |
| 16 | **Ad-blocking (LAN)** | ❌ Blocked | Depends on DNS. **Plan:** Fix with DNS fix |
| 17 | **Ad-blocking (VPN split)** | ✅ Done | Works when split tunnel active (verified 2026-01-16) |
| 18 | **DNS redirect (hardcoded)** | ❌ Blocked | Packets don't reach NSA. **Plan:** Fix with router replacement |
| 19 | Local DNS names | ⚠️ Workaround | Via /etc/hosts on Macs |

**DNS Issue:** Plusnet Hub Two router intercepts all UDP port 53 traffic. See `docs/known-issues.md`.

**Planned fixes:**
1. **Replace router** - Use a router that doesn't intercept DNS (e.g., UniFi, pfSense, OpenWrt)
2. **Pi-hole DHCP** - Let Pi-hole handle DHCP, pushing itself as DNS directly to clients
3. **Alternate port** - Run Pi-hole on port 5353 with client-side resolver config (complex)

### Mini (Backup Hub)

| # | Requirement | Status | Notes |
|---|-------------|--------|-------|
| 1 | SSH access | ✅ Done | Key-only auth |
| 2 | Syncthing running | ✅ Done | Syncs with NSA, MB4, iOS |
| 3 | iCloud backup | ✅ Done | Daily 3am rsync to iCloud Drive |
| 4 | Homebrew packages | ✅ Done | Managed via Ansible |
| 5 | /etc/hosts entries | ✅ Done | NSA service names |

### MB4 (Workstation)

| # | Requirement | Status | Notes |
|---|-------------|--------|-------|
| 1 | SSH access | ✅ Done | Key-only auth |
| 2 | Syncthing running | ✅ Done | Syncs with NSA, Mini, iOS |
| 3 | Homebrew packages | ✅ Done | Managed via Ansible |
| 4 | /etc/hosts entries | ✅ Done | NSA service names |
| 5 | WireGuard client | ✅ Done | Split tunnel for DNS |
| 6 | Docker (Colima) | ✅ Done | ~/docker/, Ansible managed |
| 7 | PostgreSQL container | ✅ Done | Port 5432, PostgreSQL 16 |
| 8 | DynamoDB Local container | ✅ Done | Port 8000, AWS emulator |

### Router (Plusnet Hub Two)

| # | Requirement | Status | Notes |
|---|-------------|--------|-------|
| 1 | DHCP server | ✅ Done | Pool 192.168.1.100-200 |
| 2 | DHCP reservations | ✅ Done | NSA, Mini static IPs |
| 3 | Port forward 51820 | ✅ Done | WireGuard VPN |
| 4 | **DNS to Pi-hole** | ❌ Blocked | Router intercepts port 53 |

---

## Network

### Defaults

| Setting | Value |
|---------|-------|
| LAN Subnet | 192.168.1.0/24 |
| Gateway | 192.168.1.254 |
| ISP DNS | 212.159.13.49, 212.159.6.9 |
| Pi-hole DNS | 192.168.1.183 |
| VPN Subnet | 10.0.0.0/24 |
| WAN | FTTX 1000 Mbps |
| WAN IP | Static (81.174.139.34) |

### Static IPs (DHCP Reservations)

| Device | IP | MAC |
|--------|-----|-----|
| NSA | 192.168.1.183 | 7c:83:34:b2:c1:33 |
| Mini | 192.168.1.116 | 14:98:77:78:d6:46 |
| Router | 192.168.1.254 | - |

### VPN Addresses (WireGuard)

| Device | VPN IP |
|--------|--------|
| NSA | 10.0.0.1 |
| iOS | 10.0.0.2 |
| MB4 | 10.0.0.3 |
| Mini | 10.0.0.4 |

## Connection Matrix

### Services (from LAN or VPN)

| Port | Service | URL | Access |
|------|---------|-----|--------|
| 22 | SSH | `ssh richardbell@nsa` | LAN + VPN |
| 53 | Pi-hole DNS | - | ⚠️ VPN split only (router blocks LAN) |
| 80 | nginx | http://laya, http://hopo, http://etc | LAN + VPN |
| 443 | Pi-hole Admin | https://pihole/admin | LAN + VPN |
| 1883 | MQTT | - | LAN + VPN |
| 8123 | Home Assistant | http://ha:8123 | LAN + VPN |
| 9090 | Cockpit | https://nsa:9090 | LAN + VPN |
| 32400 | Plex | http://plex:32400/web | LAN + VPN |
| 51820 | WireGuard | - | Anywhere |

### VPN Remote Access (when on conflicting 192.168.1.x network)

Many public networks use 192.168.1.0/24 which conflicts with home LAN. Use VPN IP (10.0.0.1) instead:

```bash
# Add to /etc/hosts on Mac when remote
sudo sh -c 'echo "10.0.0.1  laya hopo etc ha plex pihole nsa" >> /etc/hosts'
```

| Service | URL |
|---------|-----|
| laya/hopo/etc | http://laya, http://hopo, http://etc |
| Home Assistant | http://ha:8123 |
| Plex | http://plex:32400/web |
| Pi-hole Admin | https://pihole/admin |
| Cockpit | https://nsa:9090 |
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

# Dry run
ansible-playbook site.yml --check --diff

# Specific tags
ansible-playbook nsa.yml --tags docker
ansible-playbook nsa.yml --tags pihole
ansible-playbook nsa.yml --tags plex
ansible-playbook mini.yml --tags icloud-backup
ansible-playbook mb4.yml --tags docker
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

## Testing

```bash
# Quick smoke test (~30 seconds)
./tests/quick-check.sh

# Full test suite (~2-3 minutes)
./tests/run-all.sh
```

See `tests/README.md` for details.

### Manual Verification Log

| Date | Test | Result | Notes |
|------|------|--------|-------|
| 2026-01-16 | WireGuard split tunnel DNS | ✅ Pass | `dig @10.0.0.1 google.com` resolves correctly |
| 2026-01-16 | Pi-hole ad-blocking via VPN | ✅ Pass | `ads.google.com` → `0.0.0.0` (blocked) |
| 2026-01-16 | NSA services via VPN | ✅ Pass | All services accessible from MB4 |

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
| 53 | TCP/UDP | DNS (Pi-hole) | VPN split only (router blocks LAN) |
| 80 | TCP | HTTP (nginx) | LAN + VPN |
| 443 | TCP | Pi-hole Admin (HTTPS) | LAN + VPN |
| 1883 | TCP | MQTT | LAN + VPN |
| 8123 | TCP | Home Assistant | LAN + VPN |
| 9090 | TCP | Cockpit | LAN + VPN |
| 32400 | TCP | Plex | LAN + VPN |
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

### MB4 Docker (Colima)
| Item | Path |
|------|------|
| Docker compose | ~/docker/docker-compose.yml |
| PostgreSQL data | ~/docker/postgres/data/ |
| DynamoDB data | ~/docker/dynamodb/data/ |
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
- Cockpit: https://192.168.1.183:9090
- Physical access to Beelink

## Conventions

| Item | Value |
|------|-------|
| Username | richardbell |
| SSH key type | ed25519 |
| Sync folder | ~/Sync/ |
| Admin group | sudo (Linux), wheel (macOS) |
| Timezone | Europe/London |
