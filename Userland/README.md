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

### Phase 3: Additional Components

5. **[dyld](dyld.md)** - Dynamic linker/loader
6. **[CoreFoundation](CoreFoundation.md)** - Core services framework
7. **[IOKit](IOKit.md)** - I/O Kit user-space libraries

## Prerequisites

Before building the userland, ensure you have:

- A working XNU kernel build (see [Build/XNU-7195.81.3.md](../Build/XNU-7195.81.3.md))
- macOS development environment with Xcode
- Apple Open Source project sources from [opensource.apple.com](https://opensource.apple.com/)

## Source Availability

All Darwin userland components are available from Apple's Open Source portal:

| Component | Source URL |
|-----------|------------|
| launchd | https://opensource.apple.com/source/launchd/ |
| libdispatch | https://opensource.apple.com/source/libdispatch/ |
| xpc | https://opensource.apple.com/source/libxpc/ |
| Libc | https://opensource.apple.com/source/Libc/ |
| dyld | https://opensource.apple.com/source/dyld/ |
| CF (CoreFoundation) | https://opensource.apple.com/source/CF/ |

## Cross-Compilation Notes

When cross-compiling for ARM64 (Raspberry Pi 3), you'll need to:

1. Set up the appropriate SDK and toolchain
2. Disable arm64e/PAC extensions (same as kernel build)
3. Configure for embedded/non-macOS target where appropriate

## Directory Structure

```
Userland/
├── README.md           # This file
├── launchd.md          # launchd build instructions
├── libdispatch.md      # libdispatch (GCD) build instructions
├── libxpc.md           # libxpc build instructions
├── Libc.md             # C library build instructions
├── dyld.md             # Dynamic linker build instructions
└── CoreFoundation.md   # CoreFoundation build instructions
```

## Current Status

| Component | Status | Notes |
|-----------|--------|-------|
| launchd | 🔴 Not Started | Primary target |
| libdispatch | 🔴 Not Started | Dependency of launchd |
| libxpc | 🔴 Not Started | Dependency of launchd |
| Libc | 🔴 Not Started | Core dependency |
| dyld | 🔴 Not Started | Required for dynamic linking |
| CoreFoundation | 🔴 Not Started | Many userland deps |

## Contributing

If you successfully build any of these components, please contribute your patches and build instructions!
