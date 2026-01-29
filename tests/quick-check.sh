#!/bin/bash
# =============================================================================
# Infrastructure Quick Check
# =============================================================================
# Fast smoke test - checks essential connectivity to all services
# Run: ./tests/quick-check.sh
# =============================================================================

NSA_IP="${NSA_IP:-192.168.1.183}"
MINI_IP="${MINI_IP:-192.168.1.116}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASSED=0
FAILED=0

check() {
    local name="$1" result="$2"
    printf "%-16s" "$name"
    if [ "$result" = "ok" ]; then
        echo -e "${GREEN}OK${NC}"
        ((PASSED++))
    else
        echo -e "${RED}FAIL${NC} ${result:+(${result})}"
        ((FAILED++))
    fi
}

echo "Quick Infrastructure Check"
echo "=========================="

# SSH
if ssh -o ConnectTimeout=3 -o BatchMode=yes richardbell@$NSA_IP "echo ok" &>/dev/null; then
    check "SSH" "ok"
else
    check "SSH" ""
fi

# VPN
if ping -c 1 -W 2 10.0.0.1 &>/dev/null; then
    check "VPN" "ok"
else
    printf "%-16s" "VPN"
    echo -e "${YELLOW}SKIP${NC} (not connected - expected on LAN)"
fi

# Docker
CONTAINERS=$(ssh -o ConnectTimeout=3 richardbell@$NSA_IP "docker ps -q 2>/dev/null | wc -l" 2>/dev/null)
if [ "$CONTAINERS" -gt 0 ] 2>/dev/null; then
    printf "%-16s" "Docker"
    echo -e "${GREEN}OK${NC} ($CONTAINERS containers)"
    ((PASSED++))
else
    check "Docker" ""
fi

# Home Assistant
if curl -s --connect-timeout 3 -o /dev/null -w "%{http_code}" "http://$NSA_IP:8123" | grep -qE "200|302"; then
    check "HomeAssistant" "ok"
else
    check "HomeAssistant" ""
fi

# Pi-hole (v6 uses HTTPS on 443)
if curl -skL --connect-timeout 3 "https://$NSA_IP/admin/" | grep -qi "pi-hole" 2>/dev/null; then
    check "Pi-hole" "ok"
else
    check "Pi-hole" ""
fi

# Plex (HTTPS required - returns 200/302)
if curl -sk --connect-timeout 3 -o /dev/null -w "%{http_code}" "https://$NSA_IP:32400/identity" | grep -qE "200|401"; then
    check "Plex" "ok"
else
    check "Plex" "HTTPS not responding"
fi

# Cockpit
if curl -sk --connect-timeout 3 -o /dev/null -w "%{http_code}" "https://$NSA_IP:9090" | grep -q "200"; then
    check "Cockpit" "ok"
else
    check "Cockpit" ""
fi

# ntopng
if curl -s --connect-timeout 3 -o /dev/null -w "%{http_code}" "http://$NSA_IP:3000" | grep -qE "200|302"; then
    check "ntopng" "ok"
else
    check "ntopng" ""
fi

# Moltbot
if curl -s --connect-timeout 3 -o /dev/null -w "%{http_code}" "http://$NSA_IP:18789" | grep -qE "200|302|404"; then
    check "Moltbot" "ok"
else
    printf "%-16s" "Moltbot"
    echo -e "${YELLOW}SKIP${NC} (not deployed yet)"
fi

# Ollama on Mini
if curl -s --connect-timeout 3 "http://$MINI_IP:11434/" | grep -q "Ollama is running"; then
    check "Ollama (Mini)" "ok"
else
    check "Ollama (Mini)" ""
fi

# DNS
if dig +short @$NSA_IP ha 2>/dev/null | grep -q "192.168.1.183"; then
    check "DNS" "ok"
else
    check "DNS" ""
fi

# nginx
if curl -s --connect-timeout 3 -o /dev/null -w "%{http_code}" "http://$NSA_IP:8080" | grep -qE "200|404"; then
    check "nginx" "ok"
else
    check "nginx" ""
fi

# Summary
echo ""
echo -e "Passed: ${GREEN}$PASSED${NC}  Failed: ${RED}$FAILED${NC}"

if [ "$FAILED" -gt 0 ]; then
    exit 1
fi
