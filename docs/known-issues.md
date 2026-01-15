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

### Possible Causes

1. **Router DNS interception** - Some routers intercept/redirect UDP port 53 traffic
2. **ISP DNS filtering** - Less likely on LAN, but possible
3. **Mac firewall** - Could be blocking outbound UDP 53 to non-standard destinations
4. **Network switch/VLAN issue** - UDP-specific filtering

### Ruled Out
- Pi-hole configuration (listeningMode=all, binding 0.0.0.0:53)
- nftables rules (correct, counter shows 0 packets received)
- systemd-resolved conflict (not installed)
- rp_filter (already relaxed)
- Docker host networking (packets don't even reach host)

### Next Steps To Try

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

### Workaround
- Add entries to `/etc/hosts` on Mac clients (deployed via Ansible `hosts-macos.yml`)
- Pi-hole ad-blocking not active until resolved
- DNS hijacking rule in nftables won't help since packets don't reach NSA

### Related Files
- `/srv/docker/docker-compose.yml` - Pi-hole container config
- `/etc/nftables.conf` - Firewall rules
- `tasks/hosts-macos.yml` - Mac hosts file workaround

### References
- [GitHub #1735](https://github.com/pi-hole/docker-pi-hole/issues/1735) - Pi-hole v6 host interface issue (different symptoms)
- [GitHub #1695](https://github.com/pi-hole/docker-pi-hole/issues/1695) - listeningMode issue (already applied fix)
