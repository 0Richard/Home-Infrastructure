#!/bin/bash
# =============================================================================
# NSA Pre-Migration Backup Script
# =============================================================================
# Run this ON NSA before wiping for fresh Debian install.
# Creates a tarball of all critical data that can be restored after rebuild.
#
# Usage: sudo ./nsa-backup.sh [destination]
#   destination: Where to save backup (default: /data/backups/migration)
# =============================================================================

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() { echo -e "${GREEN}[+]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
error() { echo -e "${RED}[x]${NC} $1"; exit 1; }

# Check root
[[ $EUID -ne 0 ]] && error "Must run as root"

# Destination
BACKUP_DIR="${1:-/data/backups/migration}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="nsa-backup-${TIMESTAMP}"
BACKUP_PATH="${BACKUP_DIR}/${BACKUP_NAME}"

log "Creating backup directory: ${BACKUP_PATH}"
mkdir -p "${BACKUP_PATH}"

# =============================================================================
# Docker data (critical configs)
# =============================================================================
log "Backing up Docker service data..."

# Stop containers for consistent backup
log "Stopping Docker containers..."
cd /srv/docker && docker compose down || warn "Docker compose not running"

# Home Assistant
if [[ -d /srv/docker/homeassistant ]]; then
    log "  - Home Assistant config"
    tar -czf "${BACKUP_PATH}/homeassistant.tar.gz" \
        -C /srv/docker \
        --exclude='homeassistant/home-assistant.log*' \
        --exclude='homeassistant/deps' \
        --exclude='homeassistant/tts' \
        --exclude='homeassistant/.cloud' \
        homeassistant
fi

# Mosquitto
if [[ -d /srv/docker/mosquitto ]]; then
    log "  - Mosquitto MQTT"
    tar -czf "${BACKUP_PATH}/mosquitto.tar.gz" -C /srv/docker mosquitto
fi

# nginx sites
if [[ -d /srv/docker/nginx ]]; then
    log "  - nginx sites"
    tar -czf "${BACKUP_PATH}/nginx.tar.gz" -C /srv/docker nginx
fi

# laya-site (if separate)
if [[ -d /srv/docker/laya-site ]]; then
    log "  - laya-site"
    tar -czf "${BACKUP_PATH}/laya-site.tar.gz" -C /srv/docker laya-site
fi

# Pi-hole (if exists)
if [[ -d /srv/docker/pihole ]]; then
    log "  - Pi-hole"
    tar -czf "${BACKUP_PATH}/pihole.tar.gz" -C /srv/docker pihole
fi

# Plex (config only, not media)
if [[ -d /srv/docker/plex ]]; then
    log "  - Plex config (this may take a while)"
    tar -czf "${BACKUP_PATH}/plex.tar.gz" \
        -C /srv/docker \
        --exclude='plex/transcode' \
        plex
fi

# Restart containers
log "Restarting Docker containers..."
cd /srv/docker && docker compose up -d || warn "Failed to restart containers"

# =============================================================================
# System configs
# =============================================================================
log "Backing up system configs..."

mkdir -p "${BACKUP_PATH}/system"

# WireGuard
if [[ -d /etc/wireguard ]]; then
    log "  - WireGuard"
    cp -a /etc/wireguard "${BACKUP_PATH}/system/"
fi

# nftables
if [[ -f /etc/nftables.conf ]]; then
    log "  - nftables firewall"
    cp /etc/nftables.conf "${BACKUP_PATH}/system/"
fi

# SSH authorized keys
if [[ -f /root/.ssh/authorized_keys ]]; then
    log "  - SSH authorized keys"
    mkdir -p "${BACKUP_PATH}/system/ssh"
    cp /root/.ssh/authorized_keys "${BACKUP_PATH}/system/ssh/"
fi

# Cron jobs
log "  - Cron jobs"
crontab -l > "${BACKUP_PATH}/system/crontab-root.txt" 2>/dev/null || true
crontab -u richard -l > "${BACKUP_PATH}/system/crontab-richard.txt" 2>/dev/null || true

# =============================================================================
# Create manifest
# =============================================================================
log "Creating backup manifest..."

cat > "${BACKUP_PATH}/MANIFEST.txt" << EOF
NSA Migration Backup
====================
Created: $(date)
Hostname: $(hostname)
Kernel: $(uname -r)

Contents:
---------
$(ls -lh "${BACKUP_PATH}"/*.tar.gz 2>/dev/null | awk '{print $9, $5}')

System configs:
$(ls -la "${BACKUP_PATH}/system/" 2>/dev/null)

Restore Instructions:
--------------------
1. Fresh Debian 12 install
2. Mount 1TB SATA at /mnt/data
3. Copy this backup to new system
4. Run ansible-playbook nsa.yml
5. Stop containers: cd /srv/docker && docker compose down
6. Extract backups:
   tar -xzf homeassistant.tar.gz -C /srv/docker/
   tar -xzf mosquitto.tar.gz -C /srv/docker/
   tar -xzf nginx.tar.gz -C /srv/docker/
   # etc.
7. Start containers: docker compose up -d
EOF

# =============================================================================
# Create single archive
# =============================================================================
log "Creating final archive..."
FINAL_ARCHIVE="${BACKUP_DIR}/${BACKUP_NAME}.tar.gz"
tar -czf "${FINAL_ARCHIVE}" -C "${BACKUP_DIR}" "${BACKUP_NAME}"

# Calculate size
SIZE=$(du -h "${FINAL_ARCHIVE}" | cut -f1)

log "Backup complete!"
echo ""
echo "=========================================="
echo "Backup: ${FINAL_ARCHIVE}"
echo "Size:   ${SIZE}"
echo "=========================================="
echo ""
echo "Copy to Mac with:"
echo "  scp root@nsa:${FINAL_ARCHIVE} ~/Sync/backups/nsa/"
echo ""
