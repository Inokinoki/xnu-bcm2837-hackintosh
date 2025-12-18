# Building mDNSResponder for ARM64

mDNSResponder is Apple's implementation of Multicast DNS and DNS Service Discovery, commonly known as Bonjour.

## Overview

mDNSResponder provides:

- **mDNS** - Multicast DNS for local network name resolution
- **DNS-SD** - DNS Service Discovery for finding services
- **Bonjour** - Zero-configuration networking
- **Wide-Area Bonjour** - DNS-SD over unicast DNS
- **Sleep Proxy** - Wake-on-demand support

## Components

| Component | Description |
|-----------|-------------|
| `mDNSResponder` | Main daemon |
| `dns-sd` | Command-line tool |
| `dnsextd` | DNS extension daemon |
| `libdns_sd.dylib` | Client library |
| `mDNSResponderHelper` | Privileged helper |

## Source

Download from Apple Open Source:
- **URL**: https://opensource.apple.com/source/mDNSResponder/
- **Recommended Version**: mDNSResponder-1557.140.1 or latest

```bash
curl -O https://opensource.apple.com/tarballs/mDNSResponder/mDNSResponder-1557.140.1.tar.gz
tar xzf mDNSResponder-1557.140.1.tar.gz
cd mDNSResponder-1557.140.1
```

## Dependencies

| Dependency | Purpose | Required |
|------------|---------|----------|
| [Libc](Libc.md) | C standard library | ✅ Yes |
| [libdispatch](libdispatch.md) | Event handling | ✅ Yes |
| XNU Headers | Network interfaces | ✅ Yes |
| [CoreFoundation](CoreFoundation.md) | Property lists | Optional |

## Project Structure

```
mDNSResponder/
├── mDNSCore/
│   ├── mDNS.c              # Core mDNS implementation
│   ├── DNSCommon.c         # DNS utilities
│   ├── DNSDigest.c         # DNSSEC/TSIG
│   └── uDNS.c              # Unicast DNS
├── mDNSShared/
│   ├── dns_sd.h            # Public API header
│   ├── dnssd_ipc.c         # IPC implementation
│   └── PlatformCommon.c    # Platform utilities
├── mDNSMacOSX/
│   ├── daemon.c            # macOS daemon
│   ├── helper.c            # Helper process
│   └── ...
├── mDNSPosix/
│   ├── mDNSPosix.c         # POSIX implementation
│   └── mDNSUNP.c           # Unix network programming
├── Clients/
│   └── dns-sd.c            # Command-line client
└── ServiceRegistration/
    └── ...
```

## Build Instructions

### Using Xcode (macOS)

```bash
xcodebuild -project mDNSResponder.xcodeproj \
    -scheme "Build Some" \
    -configuration Release \
    ARCHS=arm64 \
    SDKROOT=macosx
```

### Using Make (POSIX platforms)

```bash
cd mDNSPosix
make os=linux         # For Linux
make os=freebsd       # For FreeBSD
# Darwin uses Xcode
```

### Manual Build

```bash
export CC=clang
export CFLAGS="-arch arm64 -O2 -I../mDNSCore -I../mDNSShared"

# Build core library
cd mDNSCore
clang ${CFLAGS} -c mDNS.c DNSCommon.c DNSDigest.c uDNS.c

# Build client library
cd ../mDNSShared
clang ${CFLAGS} -c dnssd_ipc.c dnssd_clientlib.c

# Create library
ar rcs libdns_sd.a *.o ../mDNSCore/*.o

# Build dns-sd tool
cd ../Clients
clang ${CFLAGS} -o dns-sd dns-sd.c -L../mDNSShared -ldns_sd
```

## Public API

### Service Registration

```c
#include <dns_sd.h>

DNSServiceRef sdRef;
DNSServiceErrorType err;

// Register a service
err = DNSServiceRegister(
    &sdRef,
    0,                          // flags
    kDNSServiceInterfaceIndexAny,
    "My Service",               // name
    "_http._tcp",               // type
    "local.",                   // domain
    NULL,                       // host
    htons(8080),                // port
    0, NULL,                    // TXT record
    RegisterCallback,           // callback
    NULL                        // context
);

// Process events
DNSServiceProcessResult(sdRef);

// Cleanup
DNSServiceRefDeallocate(sdRef);
```

### Service Discovery

```c
#include <dns_sd.h>

// Browse for services
err = DNSServiceBrowse(
    &sdRef,
    0,
    kDNSServiceInterfaceIndexAny,
    "_http._tcp",
    "local.",
    BrowseCallback,
    NULL
);
```

### Name Resolution

```c
#include <dns_sd.h>

// Resolve hostname
err = DNSServiceGetAddrInfo(
    &sdRef,
    0,
    kDNSServiceInterfaceIndexAny,
    kDNSServiceProtocol_IPv4,
    "myhost.local.",
    GetAddrInfoCallback,
    NULL
);
```

## Command-Line Tool

### dns-sd Usage

```bash
# Browse for services
dns-sd -B _http._tcp local.

# Resolve a service
dns-sd -L "Web Server" _http._tcp local.

# Register a service
dns-sd -R "My Service" _http._tcp local. 8080

# Lookup hostname
dns-sd -G v4 myhost.local.

# Query DNS records
dns-sd -Q example.local. A
```

## Output Files

| File | Location | Description |
|------|----------|-------------|
| `mDNSResponder` | `/usr/sbin/` | Main daemon |
| `mDNSResponderHelper` | `/usr/sbin/` | Privileged helper |
| `dns-sd` | `/usr/bin/` | Command-line tool |
| `libdns_sd.dylib` | `/usr/lib/` | Client library |
| `dns_sd.h` | `/usr/include/` | Public header |

## launchd Integration

mDNSResponder plist:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.apple.mDNSResponder</string>
    <key>ProgramArguments</key>
    <array>
        <string>/usr/sbin/mDNSResponder</string>
    </array>
    <key>MachServices</key>
    <dict>
        <key>com.apple.mDNSResponder</key>
        <true/>
    </dict>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
</dict>
</plist>
```

## Patches for ARM64

### Network interface handling

```c
#if defined(__arm64__)
// Handle ARM64-specific network interface details
#endif
```

### Endianness

mDNS is network-byte-order aware, but verify:

```c
// DNS uses network byte order (big-endian)
uint16_t port_network = htons(port_host);
uint16_t port_host = ntohs(port_network);
```

## Verification

```bash
# Start daemon (needs root)
sudo ./mDNSResponder

# Test browsing
./dns-sd -B _services._dns-sd._udp local.

# Test registration
./dns-sd -R "Test" _test._tcp local. 1234

# Test resolution
./dns-sd -G v4 $(hostname).local.
```

## References

- [Apple Open Source - mDNSResponder](https://opensource.apple.com/source/mDNSResponder/)
- [Bonjour Overview](https://developer.apple.com/bonjour/)
- [DNS-SD RFC 6763](https://tools.ietf.org/html/rfc6763)
- [mDNS RFC 6762](https://tools.ietf.org/html/rfc6762)

## Next Steps

After building mDNSResponder:

1. Configure launchd to start on boot
2. Test service discovery on local network
3. Integrate with other network services
