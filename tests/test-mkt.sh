#!/bin/bash
# =============================================================================
# MikroTik Router Tests
# =============================================================================
# Tests MikroTik hAP ax³ configuration
# Run: ./tests/test-mkt.sh
# =============================================================================

MKT_IP="${MKT_IP:-192.168.1.1}"
NSA_IP="${NSA_IP:-192.168.1.183}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

PASS=0
FAIL=0
SKIP=0

pass() { echo -e "${GREEN}PASS${NC}"; ((PASS++)); }
fail() { echo -e "${RED}FAIL${NC}"; ((FAIL++)); }
skip() { echo -e "${YELLOW}SKIP${NC} $1"; ((SKIP++)); }

echo "MikroTik Router Tests"
echo "====================="
echo ""

# ---------------------------------------------------------------------------
# Connectivity Tests
# ---------------------------------------------------------------------------
echo "== Connectivity =="

printf "Router reachable........... "
if ping -c 1 -W 2 $MKT_IP &>/dev/null; then
    pass
else
    fail
    echo "Router not reachable - aborting remaining tests"
    exit 1
fi

printf "SSH access................. "
if ssh -o ConnectTimeout=5 -o BatchMode=yes admin@$MKT_IP "/system identity print" &>/dev/null; then
    pass
else
    fail
fi

# ---------------------------------------------------------------------------
# Identity & Basic Config
# ---------------------------------------------------------------------------
echo ""
echo "== Identity & Config =="

printf "Router identity = mkt...... "
IDENTITY=$(ssh -o ConnectTimeout=5 admin@$MKT_IP "/system identity print" 2>/dev/null | grep "name:" | awk '{print $2}' | tr -d '\r')
if [ "$IDENTITY" = "mkt" ]; then
    pass
else
    fail
    echo "  Got: '$IDENTITY'"
fi

# ---------------------------------------------------------------------------
# Network Tests
# ---------------------------------------------------------------------------
echo ""
echo "== Network =="

printf "Bridge exists.............. "
if ssh admin@$MKT_IP "/interface bridge print" 2>/dev/null | grep -q "name=\"bridge\""; then
    pass
else
    fail
fi

printf "LAN IP configured.......... "
if ssh admin@$MKT_IP "/ip address print" 2>/dev/null | grep -q "192.168.1.1/24"; then
    pass
else
    fail
fi

printf "PPPoE interface running.... "
# MikroTik shows 'R' flag for running interfaces
if ssh admin@$MKT_IP "/interface pppoe-client print" 2>/dev/null | grep -q "R.*pppoe-plusnet"; then
    pass
else
    fail
fi

printf "Internet connectivity...... "
if ssh admin@$MKT_IP "/ping 1.1.1.1 count=1" 2>/dev/null | grep -q "received=1"; then
    pass
else
    fail
fi

# ---------------------------------------------------------------------------
# DHCP Tests
# ---------------------------------------------------------------------------
echo ""
echo "== DHCP =="

printf "DHCP server running........ "
if ssh admin@$MKT_IP "/ip dhcp-server print" 2>/dev/null | grep -q "dhcp-lan"; then
    pass
else
    fail
fi

printf "DHCP pool configured....... "
if ssh admin@$MKT_IP "/ip pool print" 2>/dev/null | grep -q "192.168.1.100-192.168.1.200"; then
    pass
else
    fail
fi

printf "DNS servers in DHCP........ "
DHCP_DNS=$(ssh admin@$MKT_IP "/ip dhcp-server network print" 2>/dev/null)
if echo "$DHCP_DNS" | grep -q "192.168.1.183"; then
    pass
else
    fail
fi

printf "NSA static lease........... "
if ssh admin@$MKT_IP "/ip dhcp-server lease print" 2>/dev/null | grep -qi "7C:83:34:B2:C1:33"; then
    pass
else
    fail
fi

printf "Mini static lease.......... "
if ssh admin@$MKT_IP "/ip dhcp-server lease print" 2>/dev/null | grep -qi "14:98:77:78:D6:46"; then
    pass
else
    fail
fi

# ---------------------------------------------------------------------------
# Firewall Tests
# ---------------------------------------------------------------------------
echo ""
echo "== Firewall =="

printf "NAT masquerade............. "
if ssh admin@$MKT_IP "/ip firewall nat print" 2>/dev/null | grep -q "masquerade"; then
    pass
else
    fail
fi

printf "WireGuard port forward..... "
if ssh admin@$MKT_IP "/ip firewall nat print" 2>/dev/null | grep -q "51820"; then
    pass
else
    fail
fi

printf "Input chain has rules...... "
# Check if there are any filter rules (not just count)
if ssh admin@$MKT_IP "/ip firewall filter print" 2>/dev/null | grep -q "chain=input"; then
    pass
else
    fail
fi

# ---------------------------------------------------------------------------
# WiFi Tests
# ---------------------------------------------------------------------------
echo ""
echo "== WiFi =="

printf "Main WiFi (2.4GHz)......... "
# MikroTik shows 'R' flag for running, 'M' for master
if ssh admin@$MKT_IP "/interface wifi print" 2>/dev/null | grep -E "M.*wifi1\s" | grep -q "R"; then
    pass
else
    fail
fi

printf "Main WiFi (5GHz)........... "
if ssh admin@$MKT_IP "/interface wifi print" 2>/dev/null | grep -E "M.*wifi2\s" | grep -q "R"; then
    pass
else
    fail
fi

printf "Guest WiFi (2.4GHz)........ "
if ssh admin@$MKT_IP "/interface wifi print" 2>/dev/null | grep -q "wifi1-guest"; then
    pass
else
    fail
fi

printf "Guest WiFi (5GHz).......... "
if ssh admin@$MKT_IP "/interface wifi print" 2>/dev/null | grep -q "wifi2-guest"; then
    pass
else
    fail
fi

printf "Guest SSID = guestexpress.. "
if ssh admin@$MKT_IP "/interface wifi print" 2>/dev/null | grep -q "guestexpress"; then
    pass
else
    fail
fi

# ---------------------------------------------------------------------------
# Services Tests
# ---------------------------------------------------------------------------
echo ""
echo "== Services =="

printf "SSH enabled................ "
# Services without 'X' flag are enabled
if ssh admin@$MKT_IP "/ip service print" 2>/dev/null | grep "ssh" | grep -v "^.*X" | grep -q "22"; then
    pass
else
    fail
fi

printf "Telnet disabled............ "
# Services with 'X' flag are disabled
if ssh admin@$MKT_IP "/ip service print" 2>/dev/null | grep "telnet" | grep -q "X"; then
    pass
else
    fail
fi

printf "Winbox disabled............ "
if ssh admin@$MKT_IP "/ip service print" 2>/dev/null | grep "winbox" | grep -q "X"; then
    pass
else
    fail
fi

# ---------------------------------------------------------------------------
# End-to-End Tests
# ---------------------------------------------------------------------------
echo ""
echo "== End-to-End =="

printf "NSA reachable via router... "
if ping -c 1 -W 2 $NSA_IP &>/dev/null; then
    pass
else
    fail
fi

printf "DNS resolution working..... "
if dig +short @$NSA_IP google.com 2>/dev/null | grep -q "."; then
    pass
else
    skip "(Pi-hole may be down)"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "====================="
echo -e "Results: ${GREEN}$PASS passed${NC}, ${RED}$FAIL failed${NC}, ${YELLOW}$SKIP skipped${NC}"
echo ""

if [ $FAIL -gt 0 ]; then
    exit 1
fi
