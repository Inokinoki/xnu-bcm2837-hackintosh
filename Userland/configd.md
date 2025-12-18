# Building configd for ARM64

configd is the system configuration daemon that manages network configuration and other system settings on Darwin/macOS.

## Overview

configd provides:

- **System Configuration Framework** - APIs for system settings
- **Network Configuration** - Interface, DNS, proxy settings
- **Dynamic Store** - Runtime configuration database
- **Preferences** - Persistent configuration
- **Network Detection** - Reachability monitoring
- **Location Services** - Network location awareness

## Components

| Component | Description |
|-----------|-------------|
| `configd` | Configuration daemon |
| `scutil` | Configuration utility CLI |
| `SystemConfiguration.framework` | Client framework |
| `SCNetworkReachability` | Network reachability API |
| `SCDynamicStore` | Runtime config store |

## Source

Download from Apple Open Source:
- **URL**: https://opensource.apple.com/source/configd/
- **Recommended Version**: configd-1109.140.1 or latest

```bash
curl -O https://opensource.apple.com/tarballs/configd/configd-1109.140.1.tar.gz
tar xzf configd-1109.140.1.tar.gz
cd configd-1109.140.1
```

## Dependencies

| Dependency | Purpose | Required |
|------------|---------|----------|
| [Libc](Libc.md) | C standard library | ✅ Yes |
| [CoreFoundation](CoreFoundation.md) | Property lists, runloop | ✅ Yes |
| [libdispatch](libdispatch.md) | Event handling | ✅ Yes |
| [libxpc](libxpc.md) | IPC | ✅ Yes |
| [Security](Security.md) | Authorization | Optional |
| IOKit | Network interfaces | ✅ Yes |

## Project Structure

```
configd/
├── configd.tproj/
│   ├── configd.c           # Main daemon
│   └── ...
├── scutil.tproj/
│   └── scutil.c            # CLI utility
├── SystemConfiguration.fproj/
│   ├── SCDynamicStore.c    # Dynamic store
│   ├── SCNetwork*.c        # Network APIs
│   └── ...
├── Plugins/
│   ├── IPMonitor/          # IP configuration
│   ├── InterfaceNamer/     # Interface naming
│   ├── KernelEventMonitor/ # Kernel events
│   └── ...
└── dnsinfo/
    └── ...                  # DNS configuration
```

## Build Instructions

### Using Xcode

```bash
xcodebuild -project configd.xcodeproj \
    -alltargets \
    -configuration Release \
    ARCHS=arm64 \
    SDKROOT=macosx
```

### Building Components

```bash
# Build SystemConfiguration framework
xcodebuild -target SystemConfiguration

# Build configd daemon
xcodebuild -target configd

# Build scutil CLI
xcodebuild -target scutil
```

## scutil Usage

### View Configuration

```bash
# Show DNS configuration
scutil --dns

# Show proxy configuration
scutil --proxy

# Show network reachability
scutil -r www.apple.com

# Interactive mode
scutil
> list
> show State:/Network/Global/IPv4
> quit
```

### Modify Configuration

```bash
# Set computer name
scutil --set ComputerName "MyMac"

# Set hostname
scutil --set HostName "mymac.local"

# Set local hostname (Bonjour)
scutil --set LocalHostName "mymac"
```

## API Examples

### SCDynamicStore

```c
#include <SystemConfiguration/SystemConfiguration.h>

// Create dynamic store session
SCDynamicStoreRef store = SCDynamicStoreCreate(
    NULL,
    CFSTR("MyApp"),
    callback,
    NULL
);

// Get a value
CFPropertyListRef value = SCDynamicStoreCopyValue(
    store,
    CFSTR("State:/Network/Global/IPv4")
);

// Set a value
SCDynamicStoreSetValue(
    store,
    CFSTR("State:/MyApp/Config"),
    configDict
);

CFRelease(store);
```

### Network Reachability

```c
#include <SystemConfiguration/SystemConfiguration.h>

// Check if host is reachable
SCNetworkReachabilityRef target = SCNetworkReachabilityCreateWithName(
    NULL,
    "www.apple.com"
);

SCNetworkReachabilityFlags flags;
if (SCNetworkReachabilityGetFlags(target, &flags)) {
    if (flags & kSCNetworkReachabilityFlagsReachable) {
        printf("Host is reachable\n");
    }
}

CFRelease(target);
```

## Output Files

| File | Location | Description |
|------|----------|-------------|
| `configd` | `/usr/libexec/` | Configuration daemon |
| `scutil` | `/usr/sbin/` | CLI utility |
| `SystemConfiguration.framework` | `/System/Library/Frameworks/` | Client framework |

## launchd Integration

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.apple.configd</string>
    <key>ProgramArguments</key>
    <array>
        <string>/usr/libexec/configd</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>MachServices</key>
    <dict>
        <key>com.apple.SystemConfiguration.configd</key>
        <true/>
    </dict>
</dict>
</plist>
```

## Configuration Files

| File | Purpose |
|------|---------|
| `/Library/Preferences/SystemConfiguration/` | System config prefs |
| `/Library/Preferences/SystemConfiguration/preferences.plist` | Main preferences |
| `/Library/Preferences/SystemConfiguration/NetworkInterfaces.plist` | Network interfaces |
| `/var/run/resolv.conf` | Generated DNS config |

## Patches for ARM64

### Plugin loading

Ensure plugins are built for ARM64:

```c
#if defined(__arm64__)
// ARM64 plugin path adjustments if needed
#endif
```

### Network interface detection

Adjust for ARM64/embedded network interfaces:

```c
// May need to handle different interface naming
// on Raspberry Pi (eth0, wlan0 vs en0, en1)
```

## References

- [Apple Open Source - configd](https://opensource.apple.com/source/configd/)
- [System Configuration Programming Guidelines](https://developer.apple.com/library/archive/documentation/Networking/Conceptual/SystemConfigFrameworks/)
- [SCNetworkReachability Reference](https://developer.apple.com/documentation/systemconfiguration/scnetworkreachability)

## See Also

- [network_cmds](network_cmds.md) - Network utilities
- [mDNSResponder](mDNSResponder.md) - Bonjour daemon
