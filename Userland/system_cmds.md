# Building system_cmds for ARM64

system_cmds contains essential system administration and management utilities for Darwin/macOS.

## Overview

system_cmds provides system utilities including:

- `ac` - Login accounting
- `accton` - Accounting control
- `arch` - Print architecture
- `at` / `atq` / `atrm` / `batch` - Job scheduling
- `chpass` / `chfn` / `chsh` - Change user info
- `dmesg` - Display kernel messages
- `dynamic_pager` - Dynamic pager daemon
- `fs_usage` - File system usage
- `getty` - Terminal setup
- `hostinfo` - Host information
- `iostat` - I/O statistics
- `latency` - System latency
- `login` - User login
- `lsmp` - List Mach ports
- `lsvfs` - List virtual file systems
- `machine` - Machine type
- `mkfile` - Create files
- `newgrp` - Change group
- `nologin` - Deny login
- `nvram` - NVRAM utility
- `pagesize` - Display page size
- `passwd` - Change password
- `proc_uuid_policy` - Process UUID policy
- `purge` - Force disk cache purge
- `pwd_mkdb` - Password database
- `reboot` / `halt` / `shutdown` - System control
- `sa` - System accounting
- `sysctl` - Kernel state
- `sync` - Sync filesystems
- `taskpolicy` - Task policy
- `trace` - Process tracing
- `vm_stat` - Virtual memory statistics
- `vifs` / `vipw` - Edit system files
- `zprint` - Zone allocator info

## Source

Download from Apple Open Source:
- **URL**: https://opensource.apple.com/source/system_cmds/
- **Recommended Version**: system_cmds-880.100.5 or latest

```bash
curl -O https://opensource.apple.com/tarballs/system_cmds/system_cmds-880.100.5.tar.gz
tar xzf system_cmds-880.100.5.tar.gz
cd system_cmds-880.100.5
```

## Dependencies

| Dependency | Purpose | Required |
|------------|---------|----------|
| [Libc](Libc.md) | C standard library | ✅ Yes |
| XNU Headers | Kernel interfaces | ✅ Yes |
| IOKit | Hardware access | Some commands |
| [CoreFoundation](CoreFoundation.md) | Property lists | Some commands |
| OpenDirectory | User management | passwd, login |

## Project Structure

```
system_cmds/
├── dmesg/
│   └── dmesg.c
├── sysctl/
│   └── sysctl.c
├── reboot/
│   ├── reboot.c
│   └── halt.c
├── vm_stat/
│   └── vm_stat.c
├── login/
│   └── login.c
├── passwd/
│   └── passwd.c
├── iostat/
│   └── iostat.c
└── ... (other commands)
```

## Build Instructions

### Using Xcode

```bash
xcodebuild -project system_cmds.xcodeproj \
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

# Simple commands
clang ${CFLAGS} -o dmesg dmesg/dmesg.c
clang ${CFLAGS} -o arch arch/arch.c
clang ${CFLAGS} -o pagesize pagesize/pagesize.c
clang ${CFLAGS} -o sync sync/sync.c
clang ${CFLAGS} -o hostinfo hostinfo/hostinfo.c

# sysctl (may need additional flags)
clang ${CFLAGS} -o sysctl sysctl/sysctl.c

# vm_stat
clang ${CFLAGS} -o vm_stat vm_stat/vm_stat.c -framework IOKit
```

## Key Commands

### dmesg - Kernel Messages

```c
// Display kernel ring buffer
dmesg              // All messages
dmesg | tail -20   // Last 20 messages
```

### sysctl - Kernel Parameters

```c
// Read kernel parameters
sysctl -a                     // All parameters
sysctl kern.ostype            // OS type
sysctl hw.ncpu                // CPU count
sysctl hw.memsize             // Memory size

// Write parameters (requires root)
sysctl -w kern.maxfiles=65536
```

### vm_stat - Virtual Memory

```c
// Display VM statistics
vm_stat                // Current stats
vm_stat 1              // Update every 1 second
```

### reboot / halt / shutdown

```c
// System control (requires root)
reboot                 // Restart system
halt                   // Stop system
shutdown -h now        // Halt now
shutdown -r +5         // Reboot in 5 minutes
```

## Output Binaries

| Binary | Location | Description |
|--------|----------|-------------|
| `reboot`, `halt` | `/sbin/` | System control |
| `dmesg`, `sync` | `/sbin/` | Kernel utilities |
| `sysctl` | `/usr/sbin/` | Kernel config |
| `vm_stat`, `iostat` | `/usr/bin/` | Statistics |
| `login`, `passwd` | `/usr/bin/` | User management |

## Patches for ARM64

### Mach-specific code

```c
// Include Mach headers for ARM64
#include <mach/mach.h>
#include <mach/mach_host.h>

#if defined(__arm64__)
// ARM64-specific Mach code
#endif
```

### sysctl MIB differences

```c
// Some sysctl MIBs may differ on ARM64
#if defined(__arm64__)
// Use ARM64-appropriate MIBs
#endif
```

## Special Considerations

### Privileged Commands

Several commands require root privileges:

```bash
# These need to be setuid root or run as root
reboot
halt
shutdown
passwd
login
nvram
```

### IOKit Dependencies

Some commands need IOKit framework:

```bash
clang ${CFLAGS} -framework IOKit -o iostat iostat/iostat.c
clang ${CFLAGS} -framework IOKit -o vm_stat vm_stat/vm_stat.c
```

## Verification

```bash
# Test built commands
./arch
./pagesize
./hostinfo
./sysctl kern.ostype
./vm_stat
./dmesg | head
```

## References

- [Apple Open Source - system_cmds](https://opensource.apple.com/source/system_cmds/)
- [sysctl man page](https://www.freebsd.org/cgi/man.cgi?sysctl)

## Next Steps

After building system_cmds:

1. Build [network_cmds](network_cmds.md) for network utilities
2. Build [diskdev_cmds](diskdev_cmds.md) for disk utilities
3. Set up proper permissions (setuid for privileged commands)
