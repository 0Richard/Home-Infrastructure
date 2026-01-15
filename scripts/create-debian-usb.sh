#!/bin/bash
# =============================================================================
# Create Bootable Debian USB for NSA Fresh Install
# =============================================================================
# Run this on Mac to create a bootable Debian installer USB.
#
# Usage: ./create-debian-usb.sh [disk]
#   disk: Target disk (e.g., disk4). If not provided, will list available.
#
# After install, SSH will be available immediately.
# =============================================================================

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log() { echo -e "${GREEN}[+]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
error() { echo -e "${RED}[x]${NC} $1"; exit 1; }
info() { echo -e "${CYAN}[i]${NC} $1"; }

# Debian 13 (Trixie) netinst - current stable
DEBIAN_VERSION="13.2.0"
DEBIAN_ISO="debian-${DEBIAN_VERSION}-amd64-netinst.iso"
DEBIAN_URL="https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/${DEBIAN_ISO}"
DOWNLOAD_DIR="${HOME}/Downloads"
ISO_PATH="${DOWNLOAD_DIR}/${DEBIAN_ISO}"

# =============================================================================
# Download ISO if needed
# =============================================================================
download_iso() {
    if [[ -f "${ISO_PATH}" ]]; then
        log "ISO already exists: ${ISO_PATH}"
        return 0
    fi

    log "Downloading Debian ${DEBIAN_VERSION} netinst ISO..."
    info "URL: ${DEBIAN_URL}"

    if command -v curl &> /dev/null; then
        curl -L -o "${ISO_PATH}" "${DEBIAN_URL}"
    elif command -v wget &> /dev/null; then
        wget -O "${ISO_PATH}" "${DEBIAN_URL}"
    else
        error "Neither curl nor wget found"
    fi

    log "Download complete: ${ISO_PATH}"
}

# =============================================================================
# List available disks
# =============================================================================
list_disks() {
    echo ""
    info "Available external disks:"
    echo ""
    diskutil list external
    echo ""
    warn "Choose carefully! This will ERASE the selected disk."
    echo ""
}

# =============================================================================
# Write ISO to USB
# =============================================================================
write_usb() {
    local disk="$1"
    local rdisk="r${disk}"  # Raw disk for faster writes

    # Validate disk exists
    if ! diskutil info "/dev/${disk}" &> /dev/null; then
        error "Disk /dev/${disk} not found"
    fi

    # Confirm
    echo ""
    warn "This will ERASE all data on /dev/${disk}"
    diskutil info "/dev/${disk}" | grep -E "(Device Node|Volume Name|Disk Size)"
    echo ""
    read -p "Type 'YES' to continue: " confirm
    [[ "${confirm}" != "YES" ]] && error "Aborted"

    # Unmount
    log "Unmounting /dev/${disk}..."
    diskutil unmountDisk "/dev/${disk}"

    # Write ISO
    log "Writing ISO to USB (this takes 5-10 minutes)..."
    info "You may be prompted for your password"

    sudo dd if="${ISO_PATH}" of="/dev/${rdisk}" bs=4m status=progress

    # Eject
    log "Ejecting..."
    diskutil eject "/dev/${disk}"

    log "USB ready!"
}

# =============================================================================
# Print post-install instructions
# =============================================================================
print_instructions() {
    cat << 'EOF'

================================================================================
DEBIAN 13 (TRIXIE) INSTALL INSTRUCTIONS FOR NSA
================================================================================

1. BOOT FROM USB
   - Insert USB into NSA (Beelink SEi8)
   - Power on, press F7/F12 for boot menu (or DEL for BIOS)
   - Select USB drive

2. INSTALLER CHOICES
   - Install (NOT graphical - text mode is faster)
   - Language: English
   - Location: United Kingdom
   - Keyboard: British English
   - Hostname: nsa
   - Domain: (leave blank)
   - Root password: (set a strong one)
   - User: richard (full name: Richard Bell)
   - User password: (set a strong one)
   - Timezone: London
   - Partitioning: Guided - use entire disk (NVMe)
     - Select: nvme0n1 (NOT sda - that's the 1TB SATA)
     - All files in one partition
   - Package manager mirror: United Kingdom / deb.debian.org
   - Popularity contest: No
   - Software selection:
     [x] SSH server        <-- CRITICAL - needed for remote access
     [x] Standard system utilities
     [ ] Debian desktop    <-- UNCHECK (no GUI needed)
     [ ] GNOME/KDE/etc     <-- UNCHECK ALL desktop environments

3. AFTER FIRST BOOT

   From Mac, verify SSH works:
   $ ssh root@192.168.1.183

   If IP changed, check router DHCP leases or connect monitor.

4. MOUNT 1TB SATA DRIVE

   # Check drive is visible
   lsblk

   # Create mount point
   mkdir -p /mnt/data

   # Get UUID
   blkid /dev/sda1

   # Add to fstab (replace UUID)
   echo 'UUID=56380a4f-8876-4b77-9dc0-7d0d8ab7d948 /mnt/data ext4 defaults 0 2' >> /etc/fstab

   # Mount
   mount -a

   # Verify
   df -h /mnt/data

5. RUN ANSIBLE

   From Mac:
   $ cd ~/Sync/infrastructure
   $ ansible-playbook nsa.yml

   This will install:
   - Cockpit (web admin at https://nsa:9090)
   - Docker + all containers
   - WireGuard VPN
   - nftables firewall
   - Syncthing

6. RESTORE BACKUPS

   See backup MANIFEST.txt for restore commands.

================================================================================
EOF
}

# =============================================================================
# Main
# =============================================================================
main() {
    echo ""
    echo "======================================"
    echo "Debian USB Creator for NSA"
    echo "======================================"
    echo ""

    # Download ISO
    download_iso

    # If disk provided, write to it
    if [[ $# -ge 1 ]]; then
        write_usb "$1"
    else
        list_disks
        echo "Usage: $0 <disk>"
        echo "Example: $0 disk4"
        echo ""
    fi

    # Always print instructions
    print_instructions
}

main "$@"
