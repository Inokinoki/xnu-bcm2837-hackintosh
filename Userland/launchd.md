# Building launchd for ARM64

launchd is the init system and service manager for Darwin. It is the first user-space process (PID 1) started by the XNU kernel and is responsible for bootstrapping the entire userland.

## Overview

launchd replaces traditional Unix init systems and provides:

- System and user service management
- On-demand daemon launching
- Process supervision and restart policies
- XPC-based inter-process communication
- Scheduled job execution (like cron)

## Source

Download from Apple Open Source:
- **Latest**: https://opensource.apple.com/source/launchd/
- **Recommended Version**: launchd-1336.261.2 (macOS 11.x compatible with XNU 7195.81.3)

```bash
# Download source
curl -O https://opensource.apple.com/tarballs/launchd/launchd-1336.261.2.tar.gz
tar xzf launchd-1336.261.2.tar.gz
cd launchd-1336.261.2
```

## Dependencies

launchd requires the following components to be built first:

| Dependency | Purpose | Required |
|------------|---------|----------|
| [libdispatch](libdispatch.md) | Grand Central Dispatch (async/concurrent programming) | ✅ Yes |
| [libxpc](libxpc.md) | XPC inter-process communication | ✅ Yes |
| [Libc](Libc.md) | C standard library | ✅ Yes |
| XNU Headers | Kernel headers for system calls | ✅ Yes |

## Project Structure

```
launchd/
├── src/
│   ├── launchd.c          # Main launchd daemon
│   ├── launchctl.c        # launchctl command-line tool
│   ├── bootstrap.c        # Mach bootstrap server
│   └── ...
├── liblaunch/
│   ├── liblaunch.c        # Client library
│   ├── libvproc.c         # Process management
│   └── ...
├── support/
│   └── launchd.plist      # Property list definitions
└── xcodeproject/
    └── launchd.xcodeproj
```

## Build Instructions

### Prerequisites

Ensure you have built:
1. XNU kernel headers installed
2. libdispatch built and installed
3. libxpc built and installed

### Environment Setup

```bash
# Set SDK and architecture
export SDKROOT=$(xcrun --sdk macosx --show-sdk-path)
export ARCH_FLAGS="-arch arm64"
export DEPLOYMENT_TARGET="-mmacos-version-min=11.0"

# Point to your built dependencies
export LIBDISPATCH_PATH=/path/to/libdispatch/install
export LIBXPC_PATH=/path/to/libxpc/install
export XNU_HEADERS=/path/to/xnu/BUILD/dst/usr/include

# Combined flags
export CFLAGS="${ARCH_FLAGS} ${DEPLOYMENT_TARGET} -I${XNU_HEADERS} -I${LIBDISPATCH_PATH}/include -I${LIBXPC_PATH}/include"
export LDFLAGS="-L${LIBDISPATCH_PATH}/lib -L${LIBXPC_PATH}/lib"
```

### Patches for ARM64 (Non-Apple Silicon)

Similar to the XNU kernel build, we need to disable arm64e/PAC features:

#### 1. Disable Pointer Authentication

In any source files that reference PAC:

```c
// Comment out or conditionally compile PAC-related code
#if !defined(__arm64__) || defined(__ARM64E__)
// PAC-related code here
#endif
```

#### 2. Remove arm64e Architecture References

Search for and replace `arm64e` with `arm64` in build configurations.

#### 3. Embedded Target Configuration

launchd may need to be configured for embedded targets:

```bash
# Add to CFLAGS if needed
export CFLAGS="${CFLAGS} -DCONFIG_EMBEDDED=1"
```

### Building with Xcode

```bash
# Open the Xcode project
open xcodeproject/launchd.xcodeproj

# Or build from command line
xcodebuild -project xcodeproject/launchd.xcodeproj \
    -target launchd \
    -configuration Release \
    ARCHS=arm64 \
    VALID_ARCHS=arm64 \
    SDKROOT=macosx
```

### Building with Make (if available)

```bash
# Some versions include a Makefile
make ARCH=arm64 SDKROOT=macosx
```

## Output Binaries

After a successful build, you should have:

| Binary | Location | Description |
|--------|----------|-------------|
| `launchd` | `/sbin/launchd` | The init daemon (PID 1) |
| `launchctl` | `/bin/launchctl` | Command-line management tool |
| `liblaunch.dylib` | `/usr/lib/system/` | Client library |

## Configuration Files

launchd uses property list (plist) files for configuration:

```
/System/Library/LaunchDaemons/     # System daemons
/Library/LaunchDaemons/            # Third-party system daemons
/System/Library/LaunchAgents/      # System agents (per-user)
/Library/LaunchAgents/             # Third-party agents
~/Library/LaunchAgents/            # User agents
```

### Example Launch Daemon plist

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.example.mydaemon</string>
    <key>ProgramArguments</key>
    <array>
        <string>/usr/local/bin/mydaemon</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
</dict>
</plist>
```

## Integration with XNU

launchd is loaded by the kernel as follows:

1. XNU finishes hardware initialization
2. Kernel executes `/sbin/launchd` as PID 1
3. launchd reads `/System/Library/LaunchDaemons/`
4. System services are started in dependency order
5. Login window or console is presented

## Debugging

### Enable Verbose Logging

```bash
# Set environment variable before boot
launchctl setenv LAUNCHD_LOG_LEVEL debug
```

### Check launchd Status

```bash
launchctl list                    # List all jobs
launchctl print system            # Print system domain
launchctl print user/$(id -u)     # Print user domain
```

## Known Issues

### 1. XPC Dependency

launchd heavily depends on XPC for service communication. Ensure libxpc is properly built and linked.

### 2. Mach Bootstrap

The Mach bootstrap server functionality requires proper kernel support. Verify XNU Mach subsystem is working.

### 3. Security Features

Some security features (like code signing verification) may need to be disabled for testing:

```c
// In appropriate source files
#define DISABLE_CODESIGN_CHECK 1
```

## Testing

### Minimal Boot Test

1. Build launchd and place at `/sbin/launchd`
2. Create minimal `/System/Library/LaunchDaemons/`
3. Boot XNU kernel
4. Verify launchd starts and reaches multi-user state

### launchctl Test

```bash
# Test launchctl communication with launchd
launchctl version
launchctl print system
```

## References

- [launchd Wikipedia](https://en.wikipedia.org/wiki/Launchd)
- [Apple launchd Documentation](https://developer.apple.com/library/archive/documentation/MacOSX/Conceptual/BPSystemStartup/Chapters/CreatingLaunchdJobs.html)
- [launchd.plist man page](https://www.manpagez.com/man/5/launchd.plist/)
- [Apple Open Source](https://opensource.apple.com/source/launchd/)

## Next Steps

After building launchd:

1. Build essential system daemons (configd, diskarbitrationd, etc.)
2. Create minimal system plist configuration
3. Test boot sequence with XNU kernel
4. Implement remaining userland utilities
