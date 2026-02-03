#!/bin/bash
# =============================================================================
# Infrastructure Tests - Run on NSA Server
# =============================================================================
# Tests local services, Docker containers, and system configuration
# Run: ./tests/test-nsa-local.sh (or via SSH from Mac)
# =============================================================================

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
    if id richardbell &>/dev/null; then
        pass "User 'richardbell' exists"
    else
        fail "User 'richardbell' missing"
    fi

    # richardbell in docker group
    if groups richardbell | grep -q docker; then
        pass "User 'richardbell' in docker group"
    else
        fail "User 'richardbell' not in docker group"
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

    # .env file exists (for Pi-hole password, Moltbot token)
    if [ -f "/srv/docker/.env" ]; then
        pass ".env file exists"
    else
        fail ".env file missing"
    fi

    # Check containers
    local containers=("homeassistant" "nginx" "mosquitto" "zigbee2mqtt" "pihole" "plex" "ntopng")

    for container in "${containers[@]}"; do
        if docker ps --format '{{.Names}}' | grep -q "^${container}$"; then
            pass "Container '$container' running"
        elif docker ps -a --format '{{.Names}}' | grep -q "^${container}$"; then
            fail "Container '$container' exists but not running"
        else
            skip "Container '$container' not found"
        fi
    done

    # Moltbot (may not be deployed yet)
    if docker ps --format '{{.Names}}' | grep -q "^moltbot-gateway$"; then
        pass "Container 'moltbot-gateway' running"
    elif docker ps -a --format '{{.Names}}' | grep -q "^moltbot-gateway$"; then
        fail "Container 'moltbot-gateway' exists but not running"
    else
        skip "Container 'moltbot-gateway' not deployed yet"
    fi
}

# =============================================================================
# Service Health Tests
# =============================================================================
test_services_local() {
    section "Service Health (localhost)"

    # Home Assistant
    if curl -s --connect-timeout 3 -o /dev/null -w "%{http_code}" "http://localhost:8123" | grep -qE "200|302"; then
        pass "Home Assistant responding on :8123"
    else
        fail "Home Assistant not responding on :8123"
    fi

    # Pi-hole (v6 web UI on port 8081)
    if curl -sL --connect-timeout 3 "http://localhost:8081/admin/" | grep -qi "pi-hole"; then
        pass "Pi-hole responding on :8081"
    else
        fail "Pi-hole not responding on :8081"
    fi

    # Plex (HTTPS required)
    if curl -sk --connect-timeout 3 -o /dev/null -w "%{http_code}" "https://localhost:32400/identity" | grep -qE "200|401"; then
        pass "Plex responding on :32400 (HTTPS)"
    else
        fail "Plex not responding on :32400 (HTTPS required)"
    fi

    # nginx (port 80, default server returns 404)
    if curl -s --connect-timeout 3 -o /dev/null -w "%{http_code}" "http://localhost:80" | grep -qE "200|404"; then
        pass "nginx responding on :80"
    else
        fail "nginx not responding on :80"
    fi

    # ntopng
    if curl -s --connect-timeout 3 -o /dev/null -w "%{http_code}" "http://localhost:3000" | grep -qE "200|302"; then
        pass "ntopng responding on :3000"
    else
        fail "ntopng not responding on :3000"
    fi

    # Moltbot
    if curl -s --connect-timeout 3 -o /dev/null -w "%{http_code}" "http://localhost:18789" | grep -qE "200|302|404"; then
        pass "Moltbot responding on :18789"
    else
        skip "Moltbot not responding on :18789 (not deployed yet)"
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

    # UDP port listening
    if ss -uln | grep -q ':51820 '; then
        pass "WireGuard listening on :51820/UDP"
    else
        fail "WireGuard not listening on :51820/UDP"
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
    local ruleset
    ruleset=$(nft list ruleset 2>/dev/null)

    if echo "$ruleset" | grep -q 'policy drop'; then
        pass "Default policy is DROP"
    else
        fail "Default policy is not DROP"
    fi

    # Service port rules
    local port_rules=(
        "dport 22 accept:SSH"
        "dport 9090 accept:Cockpit"
        "dport 53 accept:DNS"
        "dport 80 accept:HTTP"
        "dport 1883 accept:MQTT"
        "dport 8123 accept:Home Assistant"
        "dport 32400 accept:Plex"
        "dport 3000 accept:ntopng"
        "dport 18789 accept:Moltbot"
        "udp dport 51820:WireGuard"
    )

    for rule_info in "${port_rules[@]}"; do
        pattern="${rule_info%%:*}"
        name="${rule_info##*:}"

        if echo "$ruleset" | grep -q "$pattern"; then
            pass "Firewall rule: $name"
        else
            fail "Firewall rule missing: $name ($pattern)"
        fi
    done

    if echo "$ruleset" | grep -q 'iifname "wg0" accept'; then
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

    # richardbell authorized_keys exists
    if [ -f "/home/richardbell/.ssh/authorized_keys" ]; then
        pass "/home/richardbell/.ssh/authorized_keys exists"

        # Check permissions
        PERMS=$(stat -c %a /home/richardbell/.ssh/authorized_keys)
        if [ "$PERMS" = "600" ]; then
            pass "authorized_keys has correct permissions (600)"
        else
            fail "authorized_keys has wrong permissions ($PERMS)"
        fi
    else
        fail "/home/richardbell/.ssh/authorized_keys missing"
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

    if [ -d "/home/richardbell/Sync/backups/nsa" ]; then
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

    # Service running for richardbell
    if systemctl is-active --quiet syncthing@richardbell; then
        pass "Syncthing service running"
    else
        fail "Syncthing service not running"
    fi

    # Sync folder exists
    if [ -d "/home/richardbell/Sync" ]; then
        pass "~/Sync folder exists"
    else
        fail "~/Sync folder missing"
    fi
}

# =============================================================================
# GitHub Actions Runner Tests
# =============================================================================
test_github_runner() {
    section "GitHub Actions Runner"

    # Service installed
    if [ -f /etc/systemd/system/actions.runner.Buckden-vb.nsa.service ]; then
        pass "Runner systemd service file exists"
    else
        fail "Runner systemd service file missing"
    fi

    # Service running
    if systemctl is-active --quiet actions.runner.Buckden-vb.nsa; then
        pass "Runner service running"
    else
        fail "Runner service not running"
    fi

    # Service enabled on boot
    if systemctl is-enabled --quiet actions.runner.Buckden-vb.nsa; then
        pass "Runner service enabled on boot"
    else
        fail "Runner service not enabled on boot"
    fi

    # Runner directory exists
    if [ -d /home/richardbell/actions-runner ]; then
        pass "Runner directory exists"
    else
        fail "Runner directory missing"
    fi

    # AWS CLI installed
    if command -v aws &>/dev/null; then
        pass "AWS CLI installed ($(aws --version 2>&1 | awk '{print $1}'))"
    else
        fail "AWS CLI not installed"
    fi

    # Playwright deps (check key libraries)
    if ldconfig -p 2>/dev/null | grep -q libnss3; then
        pass "Playwright system deps installed (libnss3)"
    else
        fail "Playwright system deps missing (libnss3)"
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

    # All local hostnames must resolve
    local nsa_hosts=("ha" "pihole" "plex" "nsa" "laya" "hopo" "docs" "moltbot")

    for hostname in "${nsa_hosts[@]}"; do
        if dig +short @127.0.0.1 "$hostname" 2>/dev/null | grep -q "192.168.1.183"; then
            pass "Local DNS: $hostname → 192.168.1.183"
        else
            fail "Local DNS: $hostname not resolving"
        fi
    done

    # Mini hostname
    if dig +short @127.0.0.1 mini 2>/dev/null | grep -q "192.168.1.116"; then
        pass "Local DNS: mini → 192.168.1.116"
    else
        fail "Local DNS: mini not resolving"
    fi

    # External forwarding
    if dig +short @127.0.0.1 google.com 2>/dev/null | grep -qE '^[0-9]+\.[0-9]+'; then
        pass "DNS external forwarding works"
    else
        fail "DNS external forwarding broken"
    fi
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
    test_github_runner
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
