#!/bin/bash
# =============================================================================
# Infrastructure Tests - Run on NSA Server
# =============================================================================
# Tests local services, Docker containers, and system configuration
# Run: ./tests/test-nsa-local.sh (or via SSH from Mac)
# =============================================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Counters
PASSED=0
FAILED=0
SKIPPED=0

# Test functions
pass() { echo -e "${GREEN}✓ PASS${NC}: $1"; ((PASSED++)); }
fail() { echo -e "${RED}✗ FAIL${NC}: $1"; ((FAILED++)); }
skip() { echo -e "${YELLOW}○ SKIP${NC}: $1"; ((SKIPPED++)); }
section() { echo -e "\n${YELLOW}=== $1 ===${NC}"; }

# =============================================================================
# System Tests
# =============================================================================
test_system() {
    section "System"
    
    # Hostname
    if [ "$(hostname)" = "nsa" ]; then
        pass "Hostname is nsa"
    else
        fail "Hostname is $(hostname), expected nsa"
    fi
    
    # User exists
    if id richard &>/dev/null; then
        pass "User 'richard' exists"
    else
        fail "User 'richard' missing"
    fi
    
    # richard in docker group
    if groups richard | grep -q docker; then
        pass "User 'richard' in docker group"
    else
        fail "User 'richard' not in docker group"
    fi
    
    # IP forwarding enabled
    if [ "$(cat /proc/sys/net/ipv4/ip_forward)" = "1" ]; then
        pass "IP forwarding enabled"
    else
        fail "IP forwarding disabled"
    fi
}

# =============================================================================
# Disk & Storage Tests
# =============================================================================
test_storage() {
    section "Storage"
    
    # Root filesystem
    ROOT_USED=$(df / | awk 'NR==2 {print $5}' | tr -d '%')
    if [ "$ROOT_USED" -lt 80 ]; then
        pass "Root filesystem: ${ROOT_USED}% used"
    else
        fail "Root filesystem: ${ROOT_USED}% used (>80%)"
    fi
    
    # Data drive mounted
    if mountpoint -q /mnt/data 2>/dev/null; then
        pass "/mnt/data mounted"
        
        # Check subdirectories
        for dir in media backups; do
            if [ -d "/mnt/data/$dir" ]; then
                pass "/mnt/data/$dir exists"
            else
                fail "/mnt/data/$dir missing"
            fi
        done
        
        # Media subdirectories
        for dir in movies tv music; do
            if [ -d "/mnt/data/media/$dir" ]; then
                pass "/mnt/data/media/$dir exists"
            else
                fail "/mnt/data/media/$dir missing"
            fi
        done
    else
        skip "/mnt/data not mounted (SSD not installed yet?)"
    fi
    
    # Docker directory
    if [ -d "/srv/docker" ]; then
        pass "/srv/docker exists"
    else
        fail "/srv/docker missing"
    fi
}

# =============================================================================
# Docker Tests
# =============================================================================
test_docker() {
    section "Docker"
    
    # Docker service running
    if systemctl is-active --quiet docker; then
        pass "Docker service running"
    else
        fail "Docker service not running"
    fi
    
    # Docker compose file exists
    if [ -f "/srv/docker/docker-compose.yml" ]; then
        pass "docker-compose.yml exists"
    else
        fail "docker-compose.yml missing"
    fi
    
    # .env file exists (for Pi-hole password)
    if [ -f "/srv/docker/.env" ]; then
        pass ".env file exists"
    else
        fail ".env file missing"
    fi
    
    # Check containers
    local containers=("homeassistant" "nginx" "mosquitto" "zigbee2mqtt" "pihole" "plex")
    
    for container in "${containers[@]}"; do
        if docker ps --format '{{.Names}}' | grep -q "^${container}$"; then
            pass "Container '$container' running"
        elif docker ps -a --format '{{.Names}}' | grep -q "^${container}$"; then
            fail "Container '$container' exists but not running"
        else
            skip "Container '$container' not found"
        fi
    done
}

# =============================================================================
# Service Health Tests
# =============================================================================
test_services_local() {
    section "Service Health (localhost)"
    
    # Home Assistant
    if curl -s --connect-timeout 3 "http://localhost:8123" &>/dev/null; then
        pass "Home Assistant responding on :8123"
    else
        fail "Home Assistant not responding on :8123"
    fi
    
    # Pi-hole
    if curl -s --connect-timeout 3 "http://localhost:8080/admin/" | grep -qi "pi-hole"; then
        pass "Pi-hole responding on :8080"
    else
        fail "Pi-hole not responding on :8080"
    fi
    
    # Plex
    if curl -s --connect-timeout 3 "http://localhost:32400" | grep -qi "plex"; then
        pass "Plex responding on :32400"
    else
        fail "Plex not responding on :32400"
    fi
    
    # nginx
    if curl -s --connect-timeout 3 -o /dev/null -w "%{http_code}" "http://localhost:80" | grep -qE "200|404"; then
        pass "nginx responding on :80"
    else
        fail "nginx not responding on :80"
    fi
    
    # MQTT (check if port is listening)
    if ss -tln | grep -q ':1883 '; then
        pass "Mosquitto listening on :1883"
    else
        fail "Mosquitto not listening on :1883"
    fi
    
    # DNS (Pi-hole)
    if ss -uln | grep -q ':53 '; then
        pass "DNS (Pi-hole) listening on :53"
    else
        fail "DNS (Pi-hole) not listening on :53"
    fi
}

# =============================================================================
# WireGuard Tests
# =============================================================================
test_wireguard() {
    section "WireGuard VPN"
    
    # Service running
    if systemctl is-active --quiet wg-quick@wg0; then
        pass "WireGuard service running"
    else
        fail "WireGuard service not running"
    fi
    
    # Interface exists
    if ip link show wg0 &>/dev/null; then
        pass "wg0 interface exists"
    else
        fail "wg0 interface missing"
    fi
    
    # Has correct IP
    if ip addr show wg0 | grep -q "10.0.0.1"; then
        pass "wg0 has IP 10.0.0.1"
    else
        fail "wg0 missing IP 10.0.0.1"
    fi
    
    # Peers configured
    PEER_COUNT=$(wg show wg0 peers 2>/dev/null | wc -l)
    if [ "$PEER_COUNT" -gt 0 ]; then
        pass "WireGuard has $PEER_COUNT peer(s) configured"
    else
        fail "WireGuard has no peers configured"
    fi
    
    # Config file exists
    if [ -f "/etc/wireguard/wg0.conf" ]; then
        pass "WireGuard config exists"
    else
        fail "WireGuard config missing"
    fi
}

# =============================================================================
# Firewall Tests
# =============================================================================
test_firewall() {
    section "Firewall (nftables)"
    
    # Service running
    if systemctl is-active --quiet nftables; then
        pass "nftables service running"
    else
        fail "nftables service not running"
    fi
    
    # Config file exists
    if [ -f "/etc/nftables.conf" ]; then
        pass "nftables.conf exists"
    else
        fail "nftables.conf missing"
    fi
    
    # Check key rules exist
    if nft list ruleset | grep -q 'policy drop'; then
        pass "Default policy is DROP"
    else
        fail "Default policy is not DROP"
    fi
    
    if nft list ruleset | grep -q 'dport 22 accept'; then
        pass "SSH rule exists"
    else
        fail "SSH rule missing"
    fi
    
    if nft list ruleset | grep -q 'dport 51820 accept'; then
        pass "WireGuard rule exists"
    else
        fail "WireGuard rule missing"
    fi
    
    if nft list ruleset | grep -q 'iifname "wg0" accept'; then
        pass "WireGuard FORWARD rule exists"
    else
        fail "WireGuard FORWARD rule missing"
    fi
}

# =============================================================================
# SSH Tests
# =============================================================================
test_ssh_config() {
    section "SSH Configuration"
    
    # SSH service running
    if systemctl is-active --quiet sshd; then
        pass "SSH service running"
    else
        fail "SSH service not running"
    fi
    
    # Hardening config exists
    if [ -f "/etc/ssh/sshd_config.d/99-hardening.conf" ]; then
        pass "SSH hardening config exists"
    else
        fail "SSH hardening config missing"
    fi
    
    # Password auth disabled
    if sshd -T 2>/dev/null | grep -qi "passwordauthentication no"; then
        pass "Password authentication disabled"
    else
        fail "Password authentication may be enabled"
    fi
    
    # richard authorized_keys exists
    if [ -f "/home/richard/.ssh/authorized_keys" ]; then
        pass "/home/richard/.ssh/authorized_keys exists"
        
        # Check permissions
        PERMS=$(stat -c %a /home/richard/.ssh/authorized_keys)
        if [ "$PERMS" = "600" ]; then
            pass "authorized_keys has correct permissions (600)"
        else
            fail "authorized_keys has wrong permissions ($PERMS)"
        fi
    else
        fail "/home/richard/.ssh/authorized_keys missing"
    fi
    
    # root authorized_keys exists
    if [ -f "/root/.ssh/authorized_keys" ]; then
        pass "/root/.ssh/authorized_keys exists"
    else
        fail "/root/.ssh/authorized_keys missing"
    fi
}

# =============================================================================
# Backup Tests
# =============================================================================
test_backups() {
    section "Backup Configuration"
    
    # Backup script exists
    if [ -f "/usr/local/bin/docker-backup" ]; then
        pass "Backup script exists"
        
        # Is executable
        if [ -x "/usr/local/bin/docker-backup" ]; then
            pass "Backup script is executable"
        else
            fail "Backup script not executable"
        fi
    else
        fail "Backup script missing"
    fi
    
    # Cron job exists
    if crontab -l 2>/dev/null | grep -q "docker-backup"; then
        pass "Backup cron job configured"
    else
        fail "Backup cron job missing"
    fi
    
    # Backup directories exist
    if mountpoint -q /mnt/data 2>/dev/null; then
        if [ -d "/mnt/data/backups" ]; then
            pass "/mnt/data/backups exists"
        else
            fail "/mnt/data/backups missing"
        fi
    else
        skip "/mnt/data not mounted"
    fi
    
    if [ -d "/home/richard/Sync/backups/nsa" ]; then
        pass "Sync backup directory exists"
    else
        skip "Sync backup directory not found"
    fi
}

# =============================================================================
# Syncthing Tests
# =============================================================================
test_syncthing() {
    section "Syncthing"
    
    # Service running for richard
    if systemctl is-active --quiet syncthing@richard; then
        pass "Syncthing service running"
    else
        fail "Syncthing service not running"
    fi
    
    # Sync folder exists
    if [ -d "/home/richard/Sync" ]; then
        pass "~/Sync folder exists"
    else
        fail "~/Sync folder missing"
    fi
}

# =============================================================================
# DNS Tests (Pi-hole)
# =============================================================================
test_dns_local() {
    section "DNS (Pi-hole)"
    
    # dnsmasq should be disabled
    if systemctl is-active --quiet dnsmasq; then
        fail "dnsmasq is running (should be disabled)"
    else
        pass "dnsmasq is stopped"
    fi
    
    # Test local DNS resolution
    local hostnames=("ha" "laya" "pihole" "plex")
    
    for hostname in "${hostnames[@]}"; do
        if dig +short @127.0.0.1 "$hostname" 2>/dev/null | grep -q "192.168.1.183"; then
            pass "Local DNS: $hostname → 192.168.1.183"
        else
            fail "Local DNS: $hostname not resolving"
        fi
    done
}

# =============================================================================
# Main
# =============================================================================
main() {
    echo "============================================="
    echo "Infrastructure Tests - NSA Server Local"
    echo "============================================="
    echo "Started: $(date)"
    echo "Host: $(hostname)"
    echo ""
    
    # Check if running as root (needed for some tests)
    if [ "$EUID" -ne 0 ]; then
        echo -e "${YELLOW}Note: Running as non-root, some tests may be skipped${NC}"
    fi
    
    test_system
    test_storage
    test_docker
    test_services_local
    test_wireguard
    test_firewall
    test_ssh_config
    test_backups
    test_syncthing
    test_dns_local
    
    # Summary
    echo ""
    echo "============================================="
    echo "Summary"
    echo "============================================="
    echo -e "${GREEN}Passed${NC}: $PASSED"
    echo -e "${RED}Failed${NC}: $FAILED"
    echo -e "${YELLOW}Skipped${NC}: $SKIPPED"
    echo ""
    
    if [ "$FAILED" -gt 0 ]; then
        echo -e "${RED}Some tests failed!${NC}"
        exit 1
    else
        echo -e "${GREEN}All tests passed!${NC}"
        exit 0
    fi
}

main "$@"
