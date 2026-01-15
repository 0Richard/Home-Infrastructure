#!/bin/bash
# =============================================================================
# Infrastructure Tests - Run from Mac
# =============================================================================
# Tests remote connectivity to NSA server and services
# Run: ./tests/test-from-mac.sh
# =============================================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
NSA_IP="192.168.1.183"
NSA_VPN_IP="10.0.0.1"
NSA_HOST="nsa"

# Counters
PASSED=0
FAILED=0
SKIPPED=0

# Test functions
pass() { echo -e "${GREEN}✓ PASS${NC}: $1"; ((PASSED++)); }
fail() { echo -e "${RED}✗ FAIL${NC}: $1"; ((FAILED++)); }
skip() { echo -e "${YELLOW}○ SKIP${NC}: $1"; ((SKIPPED++)); }
section() { echo -e "\n${YELLOW}=== $1 ===${NC}"; }

# Check if we're on the LAN or VPN
check_network() {
    if ping -c 1 -W 2 "$NSA_IP" &>/dev/null; then
        echo "Network: LAN (direct connection to $NSA_IP)"
        NETWORK="lan"
    elif ping -c 1 -W 2 "$NSA_VPN_IP" &>/dev/null; then
        echo "Network: VPN (connection via $NSA_VPN_IP)"
        NETWORK="vpn"
    else
        echo -e "${RED}ERROR: Cannot reach NSA server on LAN or VPN${NC}"
        exit 1
    fi
}

# =============================================================================
# SSH Tests
# =============================================================================
test_ssh() {
    section "SSH Connectivity"
    
    # SSH as richard
    if ssh -o ConnectTimeout=5 -o BatchMode=yes richard@$NSA_IP "echo ok" &>/dev/null; then
        pass "SSH as richard@$NSA_IP"
    else
        fail "SSH as richard@$NSA_IP"
    fi
    
    # SSH as root
    if ssh -o ConnectTimeout=5 -o BatchMode=yes root@$NSA_IP "echo ok" &>/dev/null; then
        pass "SSH as root@$NSA_IP"
    else
        fail "SSH as root@$NSA_IP"
    fi
    
    # SSH via hostname (requires DNS)
    if ssh -o ConnectTimeout=5 -o BatchMode=yes richard@$NSA_HOST "echo ok" &>/dev/null; then
        pass "SSH via hostname ($NSA_HOST)"
    else
        skip "SSH via hostname (DNS not configured)"
    fi
}

# =============================================================================
# VPN Tests
# =============================================================================
test_vpn() {
    section "WireGuard VPN"
    
    # Check WireGuard interface exists locally
    if command -v wg &>/dev/null && wg show &>/dev/null; then
        pass "WireGuard interface active"
        
        # Ping VPN gateway
        if ping -c 2 -W 2 "$NSA_VPN_IP" &>/dev/null; then
            pass "Ping VPN gateway ($NSA_VPN_IP)"
        else
            fail "Ping VPN gateway ($NSA_VPN_IP)"
        fi
    else
        skip "WireGuard not active on this machine"
    fi
}

# =============================================================================
# DNS Tests (Pi-hole)
# =============================================================================
test_dns() {
    section "DNS Resolution (Pi-hole)"
    
    # Test using NSA as DNS server
    local hostnames=("ha" "laya" "hopo" "pihole" "plex" "nsa")
    
    for hostname in "${hostnames[@]}"; do
        if dig +short @$NSA_IP "$hostname" 2>/dev/null | grep -q "$NSA_IP"; then
            pass "DNS: $hostname → $NSA_IP"
        else
            fail "DNS: $hostname not resolving"
        fi
    done
    
    # Test external DNS forwarding
    if dig +short @$NSA_IP google.com 2>/dev/null | grep -qE '^[0-9]+\.[0-9]+'; then
        pass "DNS: External forwarding (google.com)"
    else
        fail "DNS: External forwarding not working"
    fi
}

# =============================================================================
# Service Accessibility Tests
# =============================================================================
test_services() {
    section "Service Accessibility"
    
    # Home Assistant
    if curl -s --connect-timeout 5 "http://$NSA_IP:8123" | grep -qi "home.assistant\|hass" 2>/dev/null; then
        pass "Home Assistant (port 8123)"
    elif curl -s --connect-timeout 5 -o /dev/null -w "%{http_code}" "http://$NSA_IP:8123" | grep -q "200\|301\|302"; then
        pass "Home Assistant (port 8123) - responding"
    else
        fail "Home Assistant (port 8123)"
    fi
    
    # Pi-hole Admin
    if curl -s --connect-timeout 5 "http://$NSA_IP:8080/admin/" | grep -qi "pi-hole" 2>/dev/null; then
        pass "Pi-hole Admin (port 8080)"
    else
        fail "Pi-hole Admin (port 8080)"
    fi
    
    # Plex
    if curl -s --connect-timeout 5 "http://$NSA_IP:32400" | grep -qi "plex" 2>/dev/null; then
        pass "Plex (port 32400)"
    else
        fail "Plex (port 32400)"
    fi
    
    # nginx (check if responding)
    if curl -s --connect-timeout 5 -o /dev/null -w "%{http_code}" "http://$NSA_IP:80" | grep -qE "200|404"; then
        pass "nginx (port 80)"
    else
        fail "nginx (port 80)"
    fi
    
    # Cockpit
    if curl -sk --connect-timeout 5 "https://$NSA_IP:9090" | grep -qi "cockpit\|login" 2>/dev/null; then
        pass "Cockpit (port 9090)"
    elif curl -sk --connect-timeout 5 -o /dev/null -w "%{http_code}" "https://$NSA_IP:9090" | grep -q "200"; then
        pass "Cockpit (port 9090) - responding"
    else
        fail "Cockpit (port 9090)"
    fi
}

# =============================================================================
# Port Connectivity Tests
# =============================================================================
test_ports() {
    section "Port Connectivity"
    
    local ports=(
        "22:SSH"
        "53:DNS"
        "80:HTTP"
        "1883:MQTT"
        "8080:Pi-hole"
        "32400:Plex"
        "8123:HomeAssistant"
        "9090:Cockpit"
    )
    
    for port_info in "${ports[@]}"; do
        port="${port_info%%:*}"
        name="${port_info##*:}"
        
        if nc -z -w 2 "$NSA_IP" "$port" 2>/dev/null; then
            pass "Port $port ($name) open"
        else
            fail "Port $port ($name) closed"
        fi
    done
    
    # UDP port for WireGuard (harder to test)
    if nc -zu -w 2 "$NSA_IP" 51820 2>/dev/null; then
        pass "Port 51820/UDP (WireGuard) open"
    else
        skip "Port 51820/UDP (WireGuard) - UDP test unreliable"
    fi
}

# =============================================================================
# Main
# =============================================================================
main() {
    echo "============================================="
    echo "Infrastructure Tests - From Mac"
    echo "============================================="
    echo "Started: $(date)"
    echo ""
    
    check_network
    
    test_ssh
    test_vpn
    test_dns
    test_services
    test_ports
    
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
