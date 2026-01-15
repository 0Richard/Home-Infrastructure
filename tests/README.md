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
| `quick-check.sh` | Mac | Fast smoke test (~30s) |
| `run-all.sh` | Mac | Full suite orchestrator |
| `test-from-mac.sh` | Mac | Tests remote connectivity |
| `test-nsa-local.sh` | NSA | Tests local services |

## What's Tested

### From Mac (`test-from-mac.sh`)

| Category | Tests |
|----------|-------|
| SSH | richard@nsa, root@nsa, hostname resolution |
| VPN | WireGuard interface, ping gateway |
| DNS | Local hostnames (ha, laya, pihole, etc), external forwarding |
| Services | Home Assistant, Pi-hole, Plex, nginx, Cockpit |
| Ports | 22, 53, 80, 1883, 8080, 32400, 8123, 9090, 51820 |

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
| DNS | dnsmasq stopped, Pi-hole resolving |

## Usage Examples

```bash
# Run quick check
./tests/quick-check.sh

# Run full suite
./tests/run-all.sh

# Run only Mac tests
./tests/test-from-mac.sh

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
