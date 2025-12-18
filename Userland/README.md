# Darwin Userland Build Guide

This directory contains documentation for building the Darwin userland components for ARM64, targeting Raspberry Pi 3 (BCM2837).

## Overview

The Darwin userland consists of the core system libraries and daemons that run on top of the XNU kernel. Unlike Linux, Darwin uses a unique init system called `launchd` which manages all system services and user processes.

## Build Order

The Darwin userland components have interdependencies and must be built in a specific order. Here is the recommended build sequence:

### Phase 1: Core Libraries

1. **[Libc](Libc.md)** - The C standard library (libSystem.B.dylib)
2. **[libdispatch](libdispatch.md)** - Grand Central Dispatch (GCD), Apple's concurrent programming library
3. **[libxpc](libxpc.md)** - XPC (inter-process communication) library

### Phase 2: System Services

4. **[launchd](launchd.md)** - The init system and service manager (PID 1)
5. **[dyld](dyld.md)** - Dynamic linker/loader
6. **[CoreFoundation](CoreFoundation.md)** - Core services framework

### Phase 3: System Utilities

7. **[shell_cmds](shell_cmds.md)** - Basic shell commands (echo, pwd, test, etc.)
8. **[file_cmds](file_cmds.md)** - File utilities (ls, cp, mv, rm, chmod, etc.)
9. **[system_cmds](system_cmds.md)** - System utilities (dmesg, sysctl, reboot, etc.)
10. **[network_cmds](network_cmds.md)** - Network utilities (ifconfig, ping, netstat, etc.)
11. **[diskdev_cmds](diskdev_cmds.md)** - Disk utilities (mount, fsck, fdisk, etc.)

### Phase 4: System Daemons

12. **[mDNSResponder](mDNSResponder.md)** - Bonjour/mDNS daemon
13. **[Security](Security.md)** - Security framework and securityd

## Prerequisites

Before building the userland, ensure you have:

- A working XNU kernel build (see [Build/XNU-7195.81.3.md](../Build/XNU-7195.81.3.md))
- macOS development environment with Xcode
- Apple Open Source project sources from [opensource.apple.com](https://opensource.apple.com/)

## Source Availability

All Darwin userland components are available from Apple's Open Source portal:

### Core Components

| Component | Source URL |
|-----------|------------|
| launchd | https://opensource.apple.com/source/launchd/ |
| libdispatch | https://opensource.apple.com/source/libdispatch/ |
| libxpc | https://opensource.apple.com/source/libxpc/ |
| Libc | https://opensource.apple.com/source/Libc/ |
| dyld | https://opensource.apple.com/source/dyld/ |
| CF (CoreFoundation) | https://opensource.apple.com/source/CF/ |

### Command-Line Utilities

| Component | Source URL |
|-----------|------------|
| shell_cmds | https://opensource.apple.com/source/shell_cmds/ |
| file_cmds | https://opensource.apple.com/source/file_cmds/ |
| system_cmds | https://opensource.apple.com/source/system_cmds/ |
| network_cmds | https://opensource.apple.com/source/network_cmds/ |
| diskdev_cmds | https://opensource.apple.com/source/diskdev_cmds/ |
| text_cmds | https://opensource.apple.com/source/text_cmds/ |
| basic_cmds | https://opensource.apple.com/source/basic_cmds/ |

### System Daemons & Frameworks

| Component | Source URL |
|-----------|------------|
| mDNSResponder | https://opensource.apple.com/source/mDNSResponder/ |
| Security | https://opensource.apple.com/source/Security/ |
| configd | https://opensource.apple.com/source/configd/ |
| CommonCrypto | https://opensource.apple.com/source/CommonCrypto/ |

## Cross-Compilation Notes

When cross-compiling for ARM64 (Raspberry Pi 3), you'll need to:

1. Set up the appropriate SDK and toolchain
2. Disable arm64e/PAC extensions (same as kernel build)
3. Configure for embedded/non-macOS target where appropriate

## Directory Structure

```
Userland/
├── README.md              # This file
│
├── # Core Components
├── Libc.md                # C library build instructions
├── libdispatch.md         # libdispatch (GCD) build instructions
├── libxpc.md              # libxpc build instructions
├── launchd.md             # launchd build instructions
├── dyld.md                # Dynamic linker build instructions
├── CoreFoundation.md      # CoreFoundation build instructions
│
├── # Command-Line Utilities
├── shell_cmds.md          # Shell commands (echo, pwd, etc.)
├── file_cmds.md           # File commands (ls, cp, mv, etc.)
├── system_cmds.md         # System commands (dmesg, sysctl, etc.)
├── network_cmds.md        # Network commands (ifconfig, ping, etc.)
├── diskdev_cmds.md        # Disk commands (mount, fsck, etc.)
│
├── # System Daemons
├── mDNSResponder.md       # Bonjour/mDNS daemon
└── Security.md            # Security framework
```

## Current Status

### Core Components

| Component | Status | Notes |
|-----------|--------|-------|
| Libc | 🔴 Not Started | Core dependency |
| libdispatch | 🟡 System Available | Available on macOS |
| libxpc | 🔴 Not Started | Dependency of launchd |
| launchd | 🔴 Not Started | Primary target |
| dyld | 🔴 Not Started | Required for dynamic linking |
| CoreFoundation | 🔴 Not Started | Many userland deps |

### Utilities

| Component | Status | Notes |
|-----------|--------|-------|
| shell_cmds | 🔴 Not Started | Basic shell utilities |
| file_cmds | 🔴 Not Started | File operations |
| system_cmds | 🔴 Not Started | System management |
| network_cmds | 🔴 Not Started | Network tools |
| diskdev_cmds | 🔴 Not Started | Disk utilities |

### Daemons

| Component | Status | Notes |
|-----------|--------|-------|
| mDNSResponder | 🔴 Not Started | Bonjour networking |
| Security | 🔴 Not Started | Security framework |

## Automated Builds

### CI/CD

This project uses GitHub Actions to test building userland components. See:

- **Workflow**: [`.github/workflows/userland-build.yml`](../.github/workflows/userland-build.yml)
- **Status**: Check the Actions tab for build results

The CI:
- Checks Apple Open Source availability for each component
- Verifies system libdispatch on macOS runners
- Attempts to build available components
- Validates documentation completeness

### Build Script

A helper script is provided for local builds:

```bash
# Build all components
./scripts/build-userland.sh

# Build specific component
./scripts/build-userland.sh libdispatch
./scripts/build-userland.sh launchd

# Download sources only
./scripts/build-userland.sh --download

# Clean build directories
./scripts/build-userland.sh --clean

# Show help
./scripts/build-userland.sh --help
```

#### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `SOURCES_DIR` | `./sources` | Source download directory |
| `BUILD_DIR` | `./build` | Build output directory |
| `SYSROOT_DIR` | `./sysroot` | Install sysroot directory |
| `TARGET_ARCH` | `arm64` | Target architecture |
| `JOBS` | auto | Parallel build jobs |

## Minimal System

To boot a minimal Darwin system, you need at minimum:

1. **XNU Kernel** - The kernel itself
2. **dyld** - Dynamic linker (loaded by kernel)
3. **launchd** - Init system (PID 1)
4. **libSystem** - Core library (Libc + libdispatch + others)
5. **Shell** - /bin/sh (from shell_cmds or bash)
6. **Basic utilities** - ls, cp, cat, etc.

## Contributing

If you successfully build any of these components, please contribute your patches and build instructions!
