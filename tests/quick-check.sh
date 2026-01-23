#!/bin/bash
# =============================================================================
# Infrastructure Quick Check
# =============================================================================
# Fast smoke test - just checks essential connectivity
# Run: ./tests/quick-check.sh
# =============================================================================

NSA_IP="${NSA_IP:-192.168.1.183}"

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

echo "Quick Infrastructure Check"
echo "=========================="

# SSH
printf "SSH........... "
if ssh -o ConnectTimeout=3 -o BatchMode=yes richardbell@$NSA_IP "echo ok" &>/dev/null; then
    echo -e "${GREEN}OK${NC}"
else
    echo -e "${RED}FAIL${NC}"
fi

# VPN
printf "VPN........... "
if ping -c 1 -W 2 10.0.0.1 &>/dev/null; then
    echo -e "${GREEN}OK${NC}"
else
    echo -e "${RED}FAIL${NC} (not connected)"
fi

# Docker
printf "Docker........ "
CONTAINERS=$(ssh -o ConnectTimeout=3 richardbell@$NSA_IP "docker ps -q 2>/dev/null | wc -l" 2>/dev/null)
if [ "$CONTAINERS" -gt 0 ]; then
    echo -e "${GREEN}OK${NC} ($CONTAINERS containers)"
else
    echo -e "${RED}FAIL${NC}"
fi

# Home Assistant
printf "HomeAssistant. "
if curl -s --connect-timeout 3 "http://$NSA_IP:8123" &>/dev/null; then
    echo -e "${GREEN}OK${NC}"
else
    echo -e "${RED}FAIL${NC}"
fi

# Pi-hole (v6 uses HTTPS on 443)
printf "Pi-hole....... "
if curl -skL --connect-timeout 3 "https://$NSA_IP/admin/" | grep -qi "pi-hole" 2>/dev/null; then
    echo -e "${GREEN}OK${NC}"
else
    echo -e "${RED}FAIL${NC}"
fi

# Plex (returns 401 but that means it's running)
printf "Plex.......... "
if curl -s --connect-timeout 3 -o /dev/null -w "%{http_code}" "http://$NSA_IP:32400" | grep -qE "200|401" 2>/dev/null; then
    echo -e "${GREEN}OK${NC}"
else
    echo -e "${RED}FAIL${NC}"
fi

# DNS
printf "DNS........... "
if dig +short @$NSA_IP ha 2>/dev/null | grep -q "192.168.1.183"; then
    echo -e "${GREEN}OK${NC}"
else
    echo -e "${RED}FAIL${NC}"
fi

echo ""
