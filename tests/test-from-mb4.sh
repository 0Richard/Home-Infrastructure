#!/bin/bash
# =============================================================================
# Infrastructure Tests - Run from MB4 (workstation)
# =============================================================================
# Tests remote connectivity to NSA server and services from LAN or VPN.
# Tests both IP-based and hostname-based (bookmark) access.
# Run: ./tests/test-from-mb4.sh
# =============================================================================

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
NSA_IP="192.168.1.183"
NSA_VPN_IP="10.0.0.1"
MINI_IP="192.168.1.116"
ROUTER_IP="192.168.1.1"

# Counters
PASSED=0
FAILED=0
SKIPPED=0

# Test functions
pass() { echo -e "${GREEN}✓ PASS${NC}: $1"; ((PASSED++)); }
fail() { echo -e "${RED}✗ FAIL${NC}: $1"; ((FAILED++)); }
skip() { echo -e "${YELLOW}○ SKIP${NC}: $1"; ((SKIPPED++)); }
section() { echo -e "\n${YELLOW}=== $1 ===${NC}"; }

# Detect network: LAN, VPN, or unreachable
check_network() {
    if ping -c 1 -W 2 "$NSA_IP" &>/dev/null; then
        echo "Network: LAN (direct connection to $NSA_IP)"
        NETWORK="lan"
        TARGET_IP="$NSA_IP"
    elif ping -c 1 -W 2 "$NSA_VPN_IP" &>/dev/null; then
        echo "Network: VPN (connection via $NSA_VPN_IP)"
        NETWORK="vpn"
        TARGET_IP="$NSA_VPN_IP"
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

    # SSH as richardbell (IP)
    if ssh -o ConnectTimeout=5 -o BatchMode=yes richardbell@$NSA_IP "echo ok" &>/dev/null; then
        pass "SSH richardbell@$NSA_IP"
    else
        fail "SSH richardbell@$NSA_IP"
    fi

    # SSH as root (IP)
    if ssh -o ConnectTimeout=5 -o BatchMode=yes root@$NSA_IP "echo ok" &>/dev/null; then
        pass "SSH root@$NSA_IP"
    else
        fail "SSH root@$NSA_IP"
    fi

    # SSH via hostname (requires Pi-hole DNS)
    if ssh -o ConnectTimeout=5 -o BatchMode=yes richardbell@nsa "echo ok" &>/dev/null; then
        pass "SSH richardbell@nsa (hostname)"
    else
        fail "SSH richardbell@nsa (hostname)"
    fi

    # SSH to Mini
    if ssh -o ConnectTimeout=5 -o BatchMode=yes richardbell@$MINI_IP "echo ok" &>/dev/null; then
        pass "SSH richardbell@$MINI_IP (Mini)"
    else
        fail "SSH richardbell@$MINI_IP (Mini)"
    fi
}

# =============================================================================
# VPN Tests
# =============================================================================
test_vpn() {
    section "WireGuard VPN"

    if [ "$NETWORK" = "vpn" ]; then
        pass "Connected via VPN"

        # Ping VPN gateway
        if ping -c 2 -W 2 "$NSA_VPN_IP" &>/dev/null; then
            pass "Ping VPN gateway ($NSA_VPN_IP)"
        else
            fail "Ping VPN gateway ($NSA_VPN_IP)"
        fi
    else
        skip "VPN not active (on LAN - expected)"
    fi
}

# =============================================================================
# DNS Tests (Pi-hole)
# =============================================================================
test_dns() {
    section "DNS Resolution (Pi-hole at $NSA_IP)"

    # All local hostnames must resolve
    local nsa_hosts=("ha" "pihole" "plex" "nsa" "laya" "hopo" "etc" "moltbot")

    for hostname in "${nsa_hosts[@]}"; do
        if dig +short @$NSA_IP "$hostname" 2>/dev/null | grep -q "$NSA_IP"; then
            pass "DNS: $hostname → $NSA_IP"
        else
            fail "DNS: $hostname not resolving to $NSA_IP"
        fi
    done

    # Mini hostname
    if dig +short @$NSA_IP mini 2>/dev/null | grep -q "$MINI_IP"; then
        pass "DNS: mini → $MINI_IP"
    else
        fail "DNS: mini not resolving to $MINI_IP"
    fi

    # External DNS forwarding
    if dig +short @$NSA_IP google.com 2>/dev/null | grep -qE '^[0-9]+\.[0-9]+'; then
        pass "DNS: External forwarding (google.com)"
    else
        fail "DNS: External forwarding not working"
    fi

    # Ad-blocking test
    if dig +short @$NSA_IP ads.google.com 2>/dev/null | grep -q "0.0.0.0"; then
        pass "DNS: Ad-blocking active (ads.google.com → 0.0.0.0)"
    else
        skip "DNS: Ad-blocking not verifiable (ads.google.com may not be blocked)"
    fi
}

# =============================================================================
# Service Accessibility Tests - IP based
# =============================================================================
test_services_ip() {
    section "Service Access (via IP: $NSA_IP)"

    # Home Assistant
    if curl -s --connect-timeout 5 -o /dev/null -w "%{http_code}" "http://$NSA_IP:8123" | grep -qE "200|302"; then
        pass "Home Assistant http://$NSA_IP:8123"
    else
        fail "Home Assistant http://$NSA_IP:8123"
    fi

    # Pi-hole Admin (HTTPS)
    if curl -skL --connect-timeout 5 "https://$NSA_IP/admin/" | grep -qi "pi-hole" 2>/dev/null; then
        pass "Pi-hole Admin https://$NSA_IP/admin"
    else
        fail "Pi-hole Admin https://$NSA_IP/admin"
    fi

    # Plex (HTTPS required)
    if curl -sk --connect-timeout 5 -o /dev/null -w "%{http_code}" "https://$NSA_IP:32400/identity" | grep -qE "200|401"; then
        pass "Plex https://$NSA_IP:32400"
    else
        fail "Plex https://$NSA_IP:32400 (requires HTTPS)"
    fi

    # Cockpit
    if curl -sk --connect-timeout 5 -o /dev/null -w "%{http_code}" "https://$NSA_IP:9090" | grep -q "200"; then
        pass "Cockpit https://$NSA_IP:9090"
    else
        fail "Cockpit https://$NSA_IP:9090"
    fi

    # nginx
    if curl -s --connect-timeout 5 -o /dev/null -w "%{http_code}" "http://$NSA_IP:8080" | grep -qE "200|404"; then
        pass "nginx http://$NSA_IP:8080"
    else
        fail "nginx http://$NSA_IP:8080"
    fi

    # ntopng
    if curl -s --connect-timeout 5 -o /dev/null -w "%{http_code}" "http://$NSA_IP:3000" | grep -qE "200|302"; then
        pass "ntopng http://$NSA_IP:3000"
    else
        fail "ntopng http://$NSA_IP:3000"
    fi

    # Moltbot
    if curl -s --connect-timeout 5 -o /dev/null -w "%{http_code}" "http://$NSA_IP:18789" | grep -qE "200|302|404"; then
        pass "Moltbot http://$NSA_IP:18789"
    else
        skip "Moltbot http://$NSA_IP:18789 (not deployed yet)"
    fi
}

# =============================================================================
# Service Accessibility Tests - Hostname based (bookmark URLs)
# =============================================================================
test_services_hostname() {
    section "Service Access (via hostname - bookmark URLs)"

    # Home Assistant
    if curl -s --connect-timeout 5 -o /dev/null -w "%{http_code}" "http://ha:8123" | grep -qE "200|302"; then
        pass "Home Assistant http://ha:8123"
    else
        fail "Home Assistant http://ha:8123"
    fi

    # Pi-hole Admin
    if curl -skL --connect-timeout 5 "https://pihole/admin/" | grep -qi "pi-hole" 2>/dev/null; then
        pass "Pi-hole Admin https://pihole/admin"
    else
        fail "Pi-hole Admin https://pihole/admin"
    fi

    # Plex (HTTPS required)
    if curl -sk --connect-timeout 5 -o /dev/null -w "%{http_code}" "https://plex:32400/web" | grep -qE "200|302"; then
        pass "Plex https://plex:32400/web"
    else
        fail "Plex https://plex:32400/web"
    fi

    # Cockpit
    if curl -sk --connect-timeout 5 -o /dev/null -w "%{http_code}" "https://nsa:9090" | grep -q "200"; then
        pass "Cockpit https://nsa:9090"
    else
        fail "Cockpit https://nsa:9090"
    fi

    # nginx sites
    if curl -s --connect-timeout 5 -o /dev/null -w "%{http_code}" "http://laya:8080" | grep -q "200"; then
        pass "nginx http://laya:8080"
    else
        fail "nginx http://laya:8080"
    fi

    if curl -s --connect-timeout 5 -o /dev/null -w "%{http_code}" "http://hopo:8080" | grep -q "200"; then
        pass "nginx http://hopo:8080"
    else
        fail "nginx http://hopo:8080"
    fi

    # ntopng
    if curl -s --connect-timeout 5 -o /dev/null -w "%{http_code}" "http://nsa:3000" | grep -qE "200|302"; then
        pass "ntopng http://nsa:3000"
    else
        fail "ntopng http://nsa:3000"
    fi

    # Moltbot
    if curl -s --connect-timeout 5 -o /dev/null -w "%{http_code}" "http://moltbot:18789" | grep -qE "200|302|404"; then
        pass "Moltbot http://moltbot:18789"
    else
        skip "Moltbot http://moltbot:18789 (not deployed yet)"
    fi
}

# =============================================================================
# Ollama on Mini
# =============================================================================
test_ollama() {
    section "Ollama LLM (Mini at $MINI_IP)"

    # API reachable
    if curl -s --connect-timeout 5 "http://$MINI_IP:11434/" | grep -q "Ollama is running"; then
        pass "Ollama API http://$MINI_IP:11434"
    else
        fail "Ollama API http://$MINI_IP:11434"
    fi

    # Model loaded
    if curl -s --connect-timeout 5 "http://$MINI_IP:11434/api/tags" | grep -q "qwen2.5"; then
        pass "Ollama model qwen2.5:14b available"
    else
        fail "Ollama model qwen2.5:14b not found"
    fi
}

# =============================================================================
# Port Connectivity Tests
# =============================================================================
test_ports() {
    section "Port Connectivity ($NSA_IP)"

    local ports=(
        "22:SSH"
        "53:DNS"
        "80:Pi-hole HTTP"
        "443:Pi-hole HTTPS"
        "1883:MQTT"
        "3000:ntopng"
        "8080:nginx"
        "8123:HomeAssistant"
        "9090:Cockpit"
        "32400:Plex"
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

    # Moltbot port (may not be deployed yet)
    if nc -z -w 2 "$NSA_IP" 18789 2>/dev/null; then
        pass "Port 18789 (Moltbot) open"
    else
        skip "Port 18789 (Moltbot) - not deployed yet"
    fi

    # Ollama on Mini
    if nc -z -w 2 "$MINI_IP" 11434 2>/dev/null; then
        pass "Port 11434 (Ollama on Mini) open"
    else
        fail "Port 11434 (Ollama on Mini) closed"
    fi
}

# =============================================================================
# VPN Service Access Tests (only when on VPN)
# =============================================================================
test_vpn_services() {
    section "VPN Service Access (via $NSA_VPN_IP)"

    if [ "$NETWORK" != "vpn" ]; then
        skip "Not on VPN - skipping VPN service tests"
        return
    fi

    # Services via VPN IP
    if curl -s --connect-timeout 5 -o /dev/null -w "%{http_code}" "http://$NSA_VPN_IP:8123" | grep -qE "200|302"; then
        pass "Home Assistant via VPN (http://$NSA_VPN_IP:8123)"
    else
        fail "Home Assistant via VPN"
    fi

    if curl -skL --connect-timeout 5 "https://$NSA_VPN_IP/admin/" | grep -qi "pi-hole" 2>/dev/null; then
        pass "Pi-hole Admin via VPN (https://$NSA_VPN_IP/admin)"
    else
        fail "Pi-hole Admin via VPN"
    fi

    if curl -sk --connect-timeout 5 -o /dev/null -w "%{http_code}" "https://$NSA_VPN_IP:32400/identity" | grep -qE "200|401"; then
        pass "Plex via VPN (https://$NSA_VPN_IP:32400)"
    else
        fail "Plex via VPN"
    fi

    if curl -sk --connect-timeout 5 -o /dev/null -w "%{http_code}" "https://$NSA_VPN_IP:9090" | grep -q "200"; then
        pass "Cockpit via VPN (https://$NSA_VPN_IP:9090)"
    else
        fail "Cockpit via VPN"
    fi

    # DNS via VPN
    if dig +short @$NSA_VPN_IP ha 2>/dev/null | grep -q "192.168.1.183"; then
        pass "DNS via VPN (dig @$NSA_VPN_IP ha)"
    else
        fail "DNS via VPN"
    fi
}

# =============================================================================
# Main
# =============================================================================
main() {
    echo "============================================="
    echo "Infrastructure Tests - From MB4"
    echo "============================================="
    echo "Started: $(date)"
    echo ""

    check_network

    test_ssh
    test_vpn
    test_dns
    test_services_ip
    test_services_hostname
    test_ollama
    test_ports
    test_vpn_services

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
