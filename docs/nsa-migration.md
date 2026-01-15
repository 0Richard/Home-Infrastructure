# NSA Migration Runbook

**Purpose:** Fresh Debian 13 (Trixie) install on NSA, managed by Ansible from first boot.

---

## Overview

| Phase | Location | Time |
|-------|----------|------|
| 1. Backup | On NSA | 10 min |
| 2. Create USB | On Mac | 15 min |
| 3. Install Debian | On NSA | 20 min |
| 4. Post-install | SSH from Mac | 10 min |
| 5. Run Ansible | On Mac | 15 min |
| 6. Restore data | SSH to NSA | 10 min |
| **Total** | | ~80 min |

---

## Phase 1: Backup (On NSA)

```bash
# SSH to NSA
ssh root@nsa

# Run backup script
cd /root
curl -O https://raw.githubusercontent.com/.../scripts/nsa-backup.sh  # or scp from Mac
chmod +x nsa-backup.sh
./nsa-backup.sh

# Copy backup to Mac (from Mac)
scp root@nsa:/data/backups/migration/nsa-backup-*.tar.gz ~/Sync/backups/nsa/
```

**Verify backup contains:**
- [ ] homeassistant.tar.gz (HA config, zigbee2mqtt, .storage)
- [ ] mosquitto.tar.gz
- [ ] nginx.tar.gz
- [ ] system/wireguard/
- [ ] MANIFEST.txt

---

## Phase 2: Create Bootable USB (On Mac)

```bash
cd ~/Sync/infrastructure/scripts

# List available disks
./create-debian-usb.sh

# Write to USB (e.g., disk4)
./create-debian-usb.sh disk4
```

---

## Phase 3: Install Debian 13 (On NSA)

1. **Boot from USB**
   - Insert USB into NSA
   - Power on, press F7/F12 for boot menu
   - Select USB drive

2. **Installer selections**

   | Setting | Value |
   |---------|-------|
   | Install type | Install (text mode, NOT graphical) |
   | Language | English |
   | Location | United Kingdom |
   | Keyboard | British English |
   | Hostname | `nsa` |
   | Domain | (blank) |
   | Root password | (strong password) |
   | Username | `richard` |
   | User password | (strong password) |
   | Timezone | London |
   | Partitioning | Guided - entire disk |
   | Disk | `nvme0n1` (NOT sda!) |
   | Scheme | All files in one partition |
   | Mirror | UK / deb.debian.org |
   | Popularity contest | No |

3. **Software selection** (CRITICAL)

   ```
   [x] SSH server          <-- MUST SELECT
   [x] standard system utilities
   [ ] Debian desktop      <-- UNCHECK
   [ ] GNOME               <-- UNCHECK
   [ ] ... (all desktops)  <-- UNCHECK
   ```

4. **Reboot** and remove USB

---

## Phase 4: Post-Install (SSH from Mac)

```bash
# Test SSH (may need to update known_hosts)
ssh-keygen -R 192.168.1.183
ssh root@192.168.1.183

# If IP changed, check router DHCP leases
```

### Mount 1TB SATA Drive

```bash
# Verify drive visible
lsblk
# Should show sda with sda1 partition

# Create mount point
mkdir -p /mnt/data

# Check existing filesystem (should be ext4 with data intact)
blkid /dev/sda1
# UUID=56380a4f-8876-4b77-9dc0-7d0d8ab7d948

# Add to fstab
cat >> /etc/fstab << 'EOF'
# 1TB SATA SSD
UUID=56380a4f-8876-4b77-9dc0-7d0d8ab7d948 /mnt/data ext4 defaults 0 2
EOF

# Mount and verify
mount -a
df -h /mnt/data
# Should show ~869G available
```

### Create media directories

```bash
mkdir -p /mnt/data/media/{movies,tv,music}
mkdir -p /mnt/data/backups
mkdir -p /mnt/data/transcode
mkdir -p /mnt/data/downloads
chown -R richard:docker /mnt/data/media
```

---

## Phase 5: Run Ansible (On Mac)

```bash
cd ~/Sync/infrastructure

# Dry run first
ansible-playbook nsa.yml --check --diff

# Full run
ansible-playbook nsa.yml

# Verify
./tests/quick-check.sh
```

---

## Phase 6: Restore Data (SSH to NSA)

```bash
# Copy backup to NSA
scp ~/Sync/backups/nsa/nsa-backup-*.tar.gz root@nsa:/tmp/

# SSH to NSA
ssh root@nsa

# Extract outer archive
cd /tmp
tar -xzf nsa-backup-*.tar.gz
cd nsa-backup-*

# Stop containers
cd /srv/docker
docker compose down

# Restore Home Assistant (most critical)
tar -xzf /tmp/nsa-backup-*/homeassistant.tar.gz -C /srv/docker/

# Restore Mosquitto
tar -xzf /tmp/nsa-backup-*/mosquitto.tar.gz -C /srv/docker/

# Restore nginx
tar -xzf /tmp/nsa-backup-*/nginx.tar.gz -C /srv/docker/

# Restore Pi-hole (if backed up)
tar -xzf /tmp/nsa-backup-*/pihole.tar.gz -C /srv/docker/ 2>/dev/null || echo "No pihole backup"

# Restore Plex (if backed up - preserves library DB)
tar -xzf /tmp/nsa-backup-*/plex.tar.gz -C /srv/docker/ 2>/dev/null || echo "No plex backup"

# Fix permissions
chown -R root:docker /srv/docker

# Start containers
docker compose up -d

# Verify
docker ps
```

---

## Verification Checklist

Run from Mac:

```bash
./tests/run-all.sh
```

Manual checks:

- [ ] SSH: `ssh nsa` works
- [ ] SSH: `ssh root@nsa` works
- [ ] DNS: `dig @192.168.1.183 nsa` returns IP
- [ ] Pi-hole: http://pihole:8080/admin loads
- [ ] Home Assistant: http://ha:8123 loads
- [ ] Plex: http://plex:32400/web loads
- [ ] WireGuard: VPN connects from phone
- [ ] Zigbee: Devices responding in HA

---

## Rollback

If something goes wrong:

1. **Re-run Ansible** - fixes most config issues
   ```bash
   ansible-playbook nsa.yml
   ```

2. **Restore from backup** - if data corrupted
   ```bash
   # Re-extract specific service
   docker compose down
   tar -xzf /tmp/nsa-backup-*/homeassistant.tar.gz -C /srv/docker/
   docker compose up -d
   ```

3. **Reinstall** - worst case, repeat from Phase 3

---

## Post-Migration Cleanup

After confirming everything works:

```bash
# Remove backup from /tmp
rm -rf /tmp/nsa-backup-*

# Clear old Docker images
docker image prune -a

# Update system
apt update && apt upgrade -y
```
