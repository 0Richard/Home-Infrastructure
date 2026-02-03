# Infrastructure Test Suite

Comprehensive tests to verify infrastructure is working correctly.

## Quick Start

```bash
# Fast smoke test (30 seconds)
./tests/quick-check.sh

# Full test suite (2-3 minutes)
./tests/run-all.sh
```

## Test Scripts

| Script | Run From | Purpose |
|--------|----------|---------|
| `quick-check.sh` | MB4 | Fast smoke test (~30s) |
| `run-all.sh` | MB4 | Full suite orchestrator (auto-logs to `results/`) |
| `test-from-mb4.sh` | MB4 | Tests remote connectivity |
| `test-nsa-local.sh` | NSA | Tests local services |
| `test-mkt.sh` | MB4 | MikroTik router tests |

## What's Tested

### From MB4 (`test-from-mb4.sh`)

| Category | Tests |
|----------|-------|
| SSH | richardbell@nsa, root@nsa, hostname resolution |
| VPN | WireGuard interface, ping gateway |
| DNS | Local hostnames (ha, laya, pihole, etc), external forwarding |
| Services | Home Assistant, Pi-hole, Plex, nginx, Cockpit |
| Ports | 22, 53, 80, 443, 1883, 3000, 8081, 8123, 9090, 18789, 32400 |

### On NSA (`test-nsa-local.sh`)

| Category | Tests |
|----------|-------|
| System | Hostname, user exists, docker group, IP forwarding |
| Storage | Root filesystem usage, /mnt/data mounted, media dirs |
| Docker | Service running, compose file, all containers up |
| Services | Each service responding on localhost |
| WireGuard | Service running, interface, IP, peers |
| Firewall | nftables running, DROP policy, key rules |
| SSH | Hardening config, password auth disabled, keys |
| Backups | Script exists, cron job, directories |
| Syncthing | Service running, Sync folder |
| GitHub Runner | Service installed, running, enabled, AWS CLI, Playwright deps |
| DNS | dnsmasq stopped, Pi-hole resolving |

### MikroTik Router (`test-mkt.sh`)

| Category | Tests |
|----------|-------|
| Connectivity | Router reachable, SSH access |
| Network | Bridge, LAN IP, PPPoE, internet |
| DHCP | Server running, pool, DNS, static leases |
| Firewall | NAT masquerade, port forwards, input rules |
| WiFi | Main 2.4/5GHz, guest 2.4/5GHz, SSID |
| Services | SSH enabled, telnet/winbox disabled |

### Security Scanning (MB4, Docker/Colima)

nmap and OpenVAS run on MB4 via Docker containers with the `security` profile.

| Tool | Purpose | Command |
|------|---------|---------|
| nmap | Port/service scan | `docker compose --profile security run --rm nmap -sV 192.168.1.0/24` |
| OpenVAS | Vulnerability scan | `docker compose --profile security up openvas` → `http://localhost:9392` |

nmap runs automatically as Phase 4 of `run-all.sh` (skipped if Docker/Colima not running). OpenVAS is manual — first start takes 10-15 min to sync vulnerability feeds.

## Test Logs

| Log | Location | Notes |
|-----|----------|-------|
| Full suite | `results/YYYY-MM-DD_HHMMSS.log` | Auto-saved by `run-all.sh` |
| nmap reports | `~/docker/nmap/reports/` | `nsa-YYYY-MM-DD.txt`, `mini-YYYY-MM-DD.txt` |
| OpenVAS | `~/docker/openvas/data/` | Managed via web UI |

## Usage Examples

```bash
# Run quick check
./tests/quick-check.sh

# Run full suite
./tests/run-all.sh

# Run only MB4 tests
./tests/test-from-mb4.sh

# Run NSA tests directly (when SSH'd to NSA)
sudo ./tests/test-nsa-local.sh

# Run with different NSA IP
NSA_IP=192.168.1.100 ./tests/run-all.sh
```

## Exit Codes

| Code | Meaning |
|------|---------|
| 0 | All tests passed |
| 1 | One or more tests failed |

## Requirements

**On Mac:**
- `ssh` - SSH client
- `curl` - HTTP requests
- `nc` - Port testing
- `dig` - DNS testing
- `ping` - Connectivity testing
- `wg` - WireGuard CLI (optional, for VPN tests)
- Docker/Colima (optional, for nmap scans in `run-all.sh`)

**On NSA:**
- Root access (for full test coverage)
- Standard Linux tools (systemctl, docker, ss, etc.)

## Adding Tests

To add new tests, edit the appropriate script and follow the pattern:

```bash
if some_condition; then
    pass "Test description"
else
    fail "Test description"
fi
```

Use `skip "reason"` for tests that can't run in current conditions.
