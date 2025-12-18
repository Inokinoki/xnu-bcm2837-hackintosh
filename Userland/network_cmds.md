# Building network_cmds for ARM64

network_cmds contains essential networking utilities for Darwin/macOS.

## Overview

network_cmds provides networking utilities including:

- `arp` - ARP table management
- `ifconfig` - Interface configuration
- `netstat` - Network statistics
- `ping` / `ping6` - ICMP echo
- `route` - Routing table management
- `traceroute` / `traceroute6` - Trace packet path
- `ndp` - NDP table management (IPv6)
- `ip6fw` - IPv6 firewall
- `kdumpd` - Kernel dump server
- `mptcp_client` - MPTCP testing
- `natd` - NAT daemon
- `nc` / `netcat` - Network utility
- `rarpd` - Reverse ARP daemon
- `rtsol` - Router solicitation
- `spray` - RPC spray test

## Source

Download from Apple Open Source:
- **URL**: https://opensource.apple.com/source/network_cmds/
- **Recommended Version**: network_cmds-606.100.2 or latest

```bash
curl -O https://opensource.apple.com/tarballs/network_cmds/network_cmds-606.100.2.tar.gz
tar xzf network_cmds-606.100.2.tar.gz
cd network_cmds-606.100.2
```

## Dependencies

| Dependency | Purpose | Required |
|------------|---------|----------|
| [Libc](Libc.md) | C standard library | ✅ Yes |
| XNU Headers | Network structures | ✅ Yes |
| libpcap | Packet capture | Some commands |

## Project Structure

```
network_cmds/
├── arp.tproj/
│   └── arp.c
├── ifconfig.tproj/
│   ├── ifconfig.c
│   ├── af_inet.c
│   ├── af_inet6.c
│   └── ...
├── netstat.tproj/
│   ├── main.c
│   ├── inet.c
│   ├── route.c
│   └── ...
├── ping.tproj/
│   └── ping.c
├── route.tproj/
│   └── route.c
├── traceroute.tproj/
│   └── traceroute.c
└── ... (other commands)
```

## Build Instructions

### Using Xcode

```bash
xcodebuild -project network_cmds.xcodeproj \
    -alltargets \
    -configuration Release \
    ARCHS=arm64 \
    SDKROOT=macosx \
    DSTROOT=/path/to/install
```

### Manual Build

```bash
export CC=clang
export CFLAGS="-arch arm64 -isysroot $(xcrun --sdk macosx --show-sdk-path) -O2"

# ping (requires setuid)
clang ${CFLAGS} -o ping ping.tproj/ping.c -lm

# arp
clang ${CFLAGS} -o arp arp.tproj/arp.c

# route
clang ${CFLAGS} -o route route.tproj/route.c

# ifconfig (multiple source files)
clang ${CFLAGS} -o ifconfig ifconfig.tproj/*.c

# netstat (multiple source files)
clang ${CFLAGS} -o netstat netstat.tproj/*.c
```

## Key Commands

### ifconfig - Interface Configuration

```bash
ifconfig                    # Show all interfaces
ifconfig en0                # Show specific interface
ifconfig en0 inet 192.168.1.100 netmask 255.255.255.0
ifconfig en0 up             # Bring interface up
ifconfig en0 down           # Bring interface down
```

### netstat - Network Statistics

```bash
netstat -an                 # All connections, numeric
netstat -r                  # Routing table
netstat -i                  # Interface statistics
netstat -s                  # Protocol statistics
```

### ping - ICMP Echo

```bash
ping -c 4 8.8.8.8          # Ping 4 times
ping6 ::1                   # IPv6 ping
```

### route - Routing Table

```bash
route -n get default        # Show default route
route add default 192.168.1.1
route delete default
```

### arp - ARP Table

```bash
arp -a                      # Show ARP table
arp -d 192.168.1.1          # Delete entry
arp -s 192.168.1.1 00:11:22:33:44:55  # Add static entry
```

## Output Binaries

| Binary | Location | Description |
|--------|----------|-------------|
| `ping`, `ping6` | `/sbin/` | ICMP utilities (setuid) |
| `ifconfig` | `/sbin/` | Interface config |
| `route` | `/sbin/` | Routing management |
| `arp` | `/usr/sbin/` | ARP table |
| `netstat` | `/usr/sbin/` | Network statistics |
| `traceroute` | `/usr/sbin/` | Path tracing |

## Patches for ARM64

### Raw socket access

```c
// Raw sockets for ping, etc.
#include <netinet/ip.h>
#include <netinet/ip_icmp.h>

// May need CAP_NET_RAW or setuid root
```

### Network structure alignment

```c
// Ensure proper alignment for network structures
#if defined(__arm64__)
#pragma pack(push, 1)
// Network packet structures
#pragma pack(pop)
#endif
```

## Security Considerations

### Setuid Requirements

These commands need setuid root for raw socket access:

```bash
chown root:wheel ping
chmod 4755 ping

chown root:wheel traceroute
chmod 4755 traceroute
```

### Capabilities Alternative

On systems with capability support, prefer capabilities over setuid:

```bash
# If capabilities are available
setcap cap_net_raw+ep ping
```

## Verification

```bash
# Test built commands (some need root)
./ifconfig lo0
./netstat -an | head
./arp -a
sudo ./ping -c 1 127.0.0.1
./route -n get default
```

## References

- [Apple Open Source - network_cmds](https://opensource.apple.com/source/network_cmds/)
- [BSD Network Programming](https://www.freebsd.org/doc/en/books/developers-handbook/sockets.html)

## Next Steps

After building network_cmds:

1. Build [mDNSResponder](mDNSResponder.md) for Bonjour
2. Set up proper setuid permissions
3. Configure network interfaces on boot
