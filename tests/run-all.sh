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

# Auto-log results to tests/results/
RESULTS_DIR="$SCRIPT_DIR/results"
mkdir -p "$RESULTS_DIR"
LOG_FILE="$RESULTS_DIR/$(date +%Y-%m-%d_%H%M%S).log"

# Strip ANSI colors for log file, keep colors for terminal
strip_colors() { sed 's/\x1b\[[0-9;]*m//g'; }

# Tee output to both terminal (with colors) and log file (without colors)
exec > >(tee >(strip_colors > "$LOG_FILE")) 2>&1

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
echo -e "${BLUE}Phase 1: Tests from MB4${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

if [ -f "$SCRIPT_DIR/test-from-mb4.sh" ]; then
    "$SCRIPT_DIR/test-from-mb4.sh" || MAC_FAILED=1
else
    echo -e "${RED}ERROR: test-from-mb4.sh not found${NC}"
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
# Phase 4: nmap Security Scan (requires Docker/Colima on MB4)
# =============================================================================
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}Phase 4: nmap Security Scan${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

DOCKER_COMPOSE="$HOME/docker/docker-compose.yml"
NMAP_REPORTS="$HOME/docker/nmap/reports"

if ! docker info &>/dev/null; then
    echo -e "${YELLOW}SKIP: Docker not running (start Colima for nmap scans)${NC}"
    NMAP_SKIPPED=1
elif [ ! -f "$DOCKER_COMPOSE" ]; then
    echo -e "${YELLOW}SKIP: $DOCKER_COMPOSE not found${NC}"
    NMAP_SKIPPED=1
else
    mkdir -p "$NMAP_REPORTS"
    NMAP_DATE=$(date +%Y-%m-%d)

    echo "Scanning NSA ($NSA_IP) - expected service ports..."
    if docker compose -f "$DOCKER_COMPOSE" --profile security run --rm \
        nmap -sV -p 22,53,80,443,1883,3000,8081,8123,9090,18789,32400,51820 "$NSA_IP" \
        -oN "/reports/nsa-${NMAP_DATE}.txt" 2>/dev/null; then
        echo -e "${GREEN}✓ NSA scan complete${NC} → $NMAP_REPORTS/nsa-${NMAP_DATE}.txt"
    else
        echo -e "${RED}✗ NSA scan failed${NC}"
        NMAP_FAILED=1
    fi

    MINI_IP="${MINI_IP:-192.168.1.116}"
    echo "Scanning Mini ($MINI_IP) - Ollama port..."
    if docker compose -f "$DOCKER_COMPOSE" --profile security run --rm \
        nmap -sV -p 11434 "$MINI_IP" \
        -oN "/reports/mini-${NMAP_DATE}.txt" 2>/dev/null; then
        echo -e "${GREEN}✓ Mini scan complete${NC} → $NMAP_REPORTS/mini-${NMAP_DATE}.txt"
    else
        echo -e "${RED}✗ Mini scan failed${NC}"
        NMAP_FAILED=1
    fi
fi

# =============================================================================
# Final Summary
# =============================================================================
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}Final Summary${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

if [ -n "$MAC_FAILED" ] || [ -n "$NSA_FAILED" ] || [ -n "$MKT_FAILED" ] || [ -n "$NMAP_FAILED" ]; then
    [ -n "$MAC_FAILED" ] && echo -e "${RED}✗ MB4 tests: FAILED${NC}"
    [ -z "$MAC_FAILED" ] && echo -e "${GREEN}✓ MB4 tests: PASSED${NC}"
    [ -n "$NSA_FAILED" ] && echo -e "${RED}✗ NSA tests: FAILED${NC}"
    [ -z "$NSA_FAILED" ] && echo -e "${GREEN}✓ NSA tests: PASSED${NC}"
    [ -n "$MKT_FAILED" ] && echo -e "${RED}✗ MikroTik tests: FAILED${NC}"
    [ -z "$MKT_FAILED" ] && echo -e "${GREEN}✓ MikroTik tests: PASSED${NC}"
    if [ -n "$NMAP_SKIPPED" ]; then
        echo -e "${YELLOW}○ nmap scan: SKIPPED${NC}"
    elif [ -n "$NMAP_FAILED" ]; then
        echo -e "${RED}✗ nmap scan: FAILED${NC}"
    else
        echo -e "${GREEN}✓ nmap scan: PASSED${NC}"
    fi
    echo ""
    echo -e "${RED}Some tests failed!${NC}"
    echo "Log saved: $LOG_FILE"
    exit 1
else
    echo -e "${GREEN}✓ MB4 tests: PASSED${NC}"
    echo -e "${GREEN}✓ NSA tests: PASSED${NC}"
    echo -e "${GREEN}✓ MikroTik tests: PASSED${NC}"
    if [ -n "$NMAP_SKIPPED" ]; then
        echo -e "${YELLOW}○ nmap scan: SKIPPED${NC}"
    else
        echo -e "${GREEN}✓ nmap scan: PASSED${NC}"
    fi
    echo ""
    echo -e "${GREEN}All tests passed!${NC}"
    echo "Log saved: $LOG_FILE"
    exit 0
fi
