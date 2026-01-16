# Known Issues

## DNS (Pi-hole) - UDP Port 53 Not Accessible Externally

**Status:** Open
**Date:** 2026-01-13
**Severity:** High

### Environment
- **OS:** Debian 13 (trixie)
- **Docker:** 29.1.4
- **Pi-hole:** Core v6.3, Web v6.4, FTL v6.4.1
- **Network mode:** Docker host networking
- **Firewall:** nftables

### Symptoms
- `dig @192.168.1.183 google.com` times out from LAN clients (Mac)
- `dig @192.168.1.183 google.com` times out from NSA itself
- `dig @127.0.0.1 google.com` works perfectly from NSA
- Pi-hole admin UI (HTTPS 443) works
- All other services work (SSH, HTTP, Plex, Home Assistant)
- Ping to NSA works

### Configuration (Verified Correct)
| Setting | Value |
|---------|-------|
| Pi-hole binding | 0.0.0.0:53 (all interfaces) |
| FTLCONF_dns_listeningMode | all |
| nftables INPUT UDP 53 | Allowed from 192.168.1.0/24 |
| nftables `iif lo accept` | Present (loopback accepted) |
| systemd-resolved | Not installed |
| rp_filter | 0 (all), 2 (interfaces) - relaxed |

### Investigation Results

**tcpdump analysis:**
- Packets from Mac to NSA port 53: **0 packets captured** on enp1s0
- Packets from NSA to itself (192.168.1.183): Leave OUTPUT but never reach INPUT
- Ping (ICMP) works, SSH works, only UDP 53 fails

**Key finding:** DNS packets are not reaching NSA's network interface at all from external sources, despite being on the same subnet and ping working.

### Root Cause (Confirmed)

**Plusnet Hub Two router intercepts ALL UDP port 53 traffic on LAN.**

Evidence:
- DNS works via WireGuard tunnel (bypasses router interception)
- DNS fails on LAN even with correct Pi-hole/firewall config
- All other UDP traffic works; only port 53 affected
- Router has no configurable option to disable this behavior

### Possible Causes (Ruled Out)

1. ~~**Router DNS interception**~~ - **CONFIRMED** as root cause
2. ~~**ISP DNS filtering**~~ - LAN-only issue, ruled out
3. ~~**Mac firewall**~~ - Works via VPN, ruled out
4. ~~**Network switch/VLAN issue**~~ - Only port 53 affected, ruled out

### Configuration (Verified Correct, Not The Issue)

- Pi-hole: listeningMode=all, binding 0.0.0.0:53
- nftables: rules correct, counter shows 0 packets received
- systemd-resolved: not installed
- rp_filter: already relaxed
- Docker: host networking correctly configured

### Next Steps (Optional)

1. **Check router settings** for DNS interception/redirect
2. **Test from different client** (not Mac) to rule out client-side issue
3. **Test with netcat** instead of dig: `echo "test" | nc -u 192.168.1.183 53`
4. **Try bridge networking** with iptables-nft:

   ```bash
   sudo apt-get install -y iptables
   sudo update-alternatives --set iptables /usr/sbin/iptables-nft
   sudo update-alternatives --set ip6tables /usr/sbin/ip6tables-nft
   sudo systemctl restart docker
   ```

5. **Check Mac outbound firewall** for UDP 53 rules

### Workarounds

#### 1. WireGuard Split Tunnel (Recommended)

Verified working 2026-01-16

- Connect via WireGuard VPN from Mac clients
- DNS routed through tunnel to `10.0.0.1` (Pi-hole)
- Full Pi-hole functionality: ad-blocking, custom DNS entries
- Test results:
  - `dig @10.0.0.1 google.com` - resolves correctly
  - `ads.google.com` returns `0.0.0.0` (blocked)
  - All NSA services accessible via VPN

#### 2. Hosts File Fallback (Name resolution only)

- Add entries to `/etc/hosts` on Mac clients (deployed via Ansible `hosts-macos.yml`)
- Provides local DNS resolution for NSA services
- No ad-blocking (Pi-hole not in DNS path)
- DNS hijacking rule in nftables won't help since router intercepts packets

### Related Files

- `/srv/docker/docker-compose.yml` - Pi-hole container config
- `/etc/nftables.conf` - Firewall rules
- `tasks/hosts-macos.yml` - Mac hosts file workaround

### References

- [GitHub #1735](https://github.com/pi-hole/docker-pi-hole/issues/1735) - Pi-hole v6 host interface issue (different symptoms)
- [GitHub #1695](https://github.com/pi-hole/docker-pi-hole/issues/1695) - listeningMode issue (already applied fix)
