#!/bin/bash
# =============================================================================
# Infrastructure Tests - Run All
# =============================================================================
# Orchestrates tests from Mac and on NSA server
# Run: ./tests/run-all.sh
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NSA_IP="${NSA_IP:-192.168.1.183}"
NSA_USER="${NSA_USER:-richardbell}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}"
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║           Infrastructure Test Suite                           ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"
echo "Started: $(date)"
echo ""

# Check connectivity first
echo -e "${YELLOW}Checking connectivity to NSA...${NC}"
if ! ping -c 1 -W 2 "$NSA_IP" &>/dev/null; then
    echo -e "${RED}ERROR: Cannot reach $NSA_IP${NC}"
    echo "Make sure you're on the LAN or connected to WireGuard VPN"
    exit 1
fi
echo -e "${GREEN}NSA reachable at $NSA_IP${NC}"
echo ""

# =============================================================================
# Phase 1: Local Tests (from Mac)
# =============================================================================
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}Phase 1: Tests from Mac${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

if [ -f "$SCRIPT_DIR/test-from-mac.sh" ]; then
    "$SCRIPT_DIR/test-from-mac.sh" || MAC_FAILED=1
else
    echo -e "${RED}ERROR: test-from-mac.sh not found${NC}"
    MAC_FAILED=1
fi

# =============================================================================
# Phase 2: Remote Tests (on NSA)
# =============================================================================
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}Phase 2: Tests on NSA Server (via SSH)${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Copy test script to NSA and run it
echo "Copying test script to NSA..."
if scp -q "$SCRIPT_DIR/test-nsa-local.sh" "${NSA_USER}@${NSA_IP}:/tmp/test-nsa-local.sh"; then
    echo "Running tests on NSA (as root for full access)..."
    ssh -t "root@${NSA_IP}" "bash /tmp/test-nsa-local.sh" || NSA_FAILED=1
    ssh "${NSA_USER}@${NSA_IP}" "rm -f /tmp/test-nsa-local.sh"
else
    echo -e "${RED}ERROR: Could not copy test script to NSA${NC}"
    NSA_FAILED=1
fi

# =============================================================================
# Phase 3: MikroTik Router Tests
# =============================================================================
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}Phase 3: MikroTik Router Tests${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

if [ -f "$SCRIPT_DIR/test-mkt.sh" ]; then
    "$SCRIPT_DIR/test-mkt.sh" || MKT_FAILED=1
else
    echo -e "${YELLOW}SKIP: test-mkt.sh not found${NC}"
fi

# =============================================================================
# Final Summary
# =============================================================================
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}Final Summary${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

if [ -n "$MAC_FAILED" ] || [ -n "$NSA_FAILED" ] || [ -n "$MKT_FAILED" ]; then
    [ -n "$MAC_FAILED" ] && echo -e "${RED}✗ Mac tests: FAILED${NC}"
    [ -z "$MAC_FAILED" ] && echo -e "${GREEN}✓ Mac tests: PASSED${NC}"
    [ -n "$NSA_FAILED" ] && echo -e "${RED}✗ NSA tests: FAILED${NC}"
    [ -z "$NSA_FAILED" ] && echo -e "${GREEN}✓ NSA tests: PASSED${NC}"
    [ -n "$MKT_FAILED" ] && echo -e "${RED}✗ MikroTik tests: FAILED${NC}"
    [ -z "$MKT_FAILED" ] && echo -e "${GREEN}✓ MikroTik tests: PASSED${NC}"
    echo ""
    echo -e "${RED}Some tests failed!${NC}"
    exit 1
else
    echo -e "${GREEN}✓ Mac tests: PASSED${NC}"
    echo -e "${GREEN}✓ NSA tests: PASSED${NC}"
    echo -e "${GREEN}✓ MikroTik tests: PASSED${NC}"
    echo ""
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
fi
