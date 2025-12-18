# Apple Open Source Utilities List

This document lists all Darwin/macOS utilities available from Apple Open Source that can be built for ARM64.

> **Last checked**: December 2024  
> **Source**: https://opensource.apple.com/tarballs/

## Legend

| Symbol | Meaning |
|--------|---------|
| ✅ | Documentation available in this repo |
| 📦 | Available on Apple Open Source |
| 🔧 | Build instructions needed |

---

## Core System Components

| Component | Status | Description |
|-----------|--------|-------------|
| [xnu](https://opensource.apple.com/source/xnu/) | 📦 | XNU Kernel |
| [Libc](Libc.md) | ✅ | C Standard Library |
| [Libsystem](https://opensource.apple.com/source/Libsystem/) | 📦 | System library umbrella |
| [libpthread](https://opensource.apple.com/source/libpthread/) | 📦 | POSIX threads |
| [libplatform](https://opensource.apple.com/source/libplatform/) | 📦 | Platform abstractions |
| [libmalloc](https://opensource.apple.com/source/libmalloc/) | 📦 | Memory allocation |
| [libutil](https://opensource.apple.com/source/libutil/) | 📦 | Utility functions |
| [libclosure](https://opensource.apple.com/source/libclosure/) | 📦 | Blocks runtime |
| [Libc++](https://opensource.apple.com/source/Libc++/) | 📦 | C++ Standard Library |
| [libcxx](https://opensource.apple.com/source/libcxx/) | 📦 | LLVM C++ library |

## Init System & IPC

| Component | Status | Description |
|-----------|--------|-------------|
| [launchd](launchd.md) | ✅ | Init system (PID 1) |
| [libdispatch](libdispatch.md) | ✅ | Grand Central Dispatch |
| [libxpc](libxpc.md) | ✅ | XPC IPC library |

## Dynamic Linking

| Component | Status | Description |
|-----------|--------|-------------|
| [dyld](dyld.md) | ✅ | Dynamic linker/loader |
| [cctools](https://opensource.apple.com/source/cctools/) | 📦 | Compiler tools (otool, etc.) |
| [ld64](https://opensource.apple.com/source/ld64/) | 📦 | Linker |

## Frameworks

| Component | Status | Description |
|-----------|--------|-------------|
| [CF (CoreFoundation)](CoreFoundation.md) | ✅ | Core services framework |
| [objc4](https://opensource.apple.com/source/objc4/) | 📦 | Objective-C runtime |
| [Security](Security.md) | ✅ | Security framework |
| [IOKit](https://opensource.apple.com/source/IOKit/) | 📦 | I/O Kit framework |
| [IOKitUser](https://opensource.apple.com/source/IOKitUser/) | 📦 | IOKit user library |
| [IOKitTools](https://opensource.apple.com/source/IOKitTools/) | 📦 | IOKit utilities |

## Shell Commands

| Component | Status | Description |
|-----------|--------|-------------|
| [shell_cmds](shell_cmds.md) | ✅ | echo, pwd, test, hostname, kill, etc. |
| [basic_cmds](https://opensource.apple.com/source/basic_cmds/) | 📦 | Basic utilities |
| [misc_cmds](https://opensource.apple.com/source/misc_cmds/) | 📦 | Miscellaneous commands |
| [adv_cmds](https://opensource.apple.com/source/adv_cmds/) | 📦 | Advanced commands (ps, finger, etc.) |
| [developer_cmds](https://opensource.apple.com/source/developer_cmds/) | 📦 | Developer utilities |

## File Commands

| Component | Status | Description |
|-----------|--------|-------------|
| [file_cmds](file_cmds.md) | ✅ | ls, cp, mv, rm, chmod, stat, etc. |
| [text_cmds](https://opensource.apple.com/source/text_cmds/) | 📦 | Text utilities (cat, head, tail, wc, etc.) |

## System Commands

| Component | Status | Description |
|-----------|--------|-------------|
| [system_cmds](system_cmds.md) | ✅ | dmesg, sysctl, reboot, vm_stat, etc. |
| [kext_tools](https://opensource.apple.com/source/kext_tools/) | 📦 | Kernel extension tools |
| [dtrace](https://opensource.apple.com/source/dtrace/) | 📦 | Dynamic tracing |
| [BootCache](https://opensource.apple.com/source/BootCache/) | 📦 | Boot cache optimization |

## Network Commands

| Component | Status | Description |
|-----------|--------|-------------|
| [network_cmds](network_cmds.md) | ✅ | ifconfig, ping, netstat, arp, route, etc. |
| [mDNSResponder](mDNSResponder.md) | ✅ | Bonjour/mDNS |
| [configd](https://opensource.apple.com/source/configd/) | 📦 | System configuration daemon |
| [Libinfo](https://opensource.apple.com/source/Libinfo/) | 📦 | Name resolution library |

## Disk Commands

| Component | Status | Description |
|-----------|--------|-------------|
| [diskdev_cmds](diskdev_cmds.md) | ✅ | mount, fsck, fdisk, newfs, etc. |
| [hfs](https://opensource.apple.com/source/hfs/) | 📦 | HFS+ filesystem |
| [msdosfs](https://opensource.apple.com/source/msdosfs/) | 📦 | FAT filesystem |
| [ntfs](https://opensource.apple.com/source/ntfs/) | 📦 | NTFS (read-only) |
| [smbfs](https://opensource.apple.com/source/smbfs/) | 📦 | SMB filesystem |

## Text Processing

| Component | Status | Description |
|-----------|--------|-------------|
| [grep](https://opensource.apple.com/source/grep/) | 📦 | Pattern matching |
| [awk](https://opensource.apple.com/source/awk/) | 📦 | Pattern processing |
| [sed](https://opensource.apple.com/source/sed/) | 📦 | Stream editor |
| [less](https://opensource.apple.com/source/less/) | 📦 | Pager |
| [more](https://opensource.apple.com/source/more/) | 📦 | Pager (simple) |
| [bc](https://opensource.apple.com/source/bc/) | 📦 | Calculator |
| [dc](https://opensource.apple.com/source/dc/) | 📦 | RPN calculator |

## Editors

| Component | Status | Description |
|-----------|--------|-------------|
| [vim](https://opensource.apple.com/source/vim/) | 📦 | Vi IMproved |
| [nano](https://opensource.apple.com/source/nano/) | 📦 | Simple editor |

## Shells

| Component | Status | Description |
|-----------|--------|-------------|
| [bash](https://opensource.apple.com/source/bash/) | 📦 | Bourne Again Shell |
| [zsh](https://opensource.apple.com/source/zsh/) | 📦 | Z Shell |
| [tcsh](https://opensource.apple.com/source/tcsh/) | 📦 | TENEX C Shell |

## Security & Crypto

| Component | Status | Description |
|-----------|--------|-------------|
| [CommonCrypto](https://opensource.apple.com/source/CommonCrypto/) | 📦 | Cryptographic library |
| [OpenSSL](https://opensource.apple.com/source/OpenSSL/) | 📦 | SSL/TLS library |
| [OpenSSH](https://opensource.apple.com/source/OpenSSH/) | 📦 | SSH client/server |
| [sudo](https://opensource.apple.com/source/sudo/) | 📦 | Superuser do |

## Network Utilities

| Component | Status | Description |
|-----------|--------|-------------|
| [curl](https://opensource.apple.com/source/curl/) | 📦 | URL transfer tool |
| [rsync](https://opensource.apple.com/source/rsync/) | 📦 | Remote sync |

## Compression

| Component | Status | Description |
|-----------|--------|-------------|
| [gzip](https://opensource.apple.com/source/gzip/) | 📦 | GNU zip |
| [bzip2](https://opensource.apple.com/source/bzip2/) | 📦 | Block compression |
| [xz](https://opensource.apple.com/source/xz/) | 📦 | XZ compression |
| [zip](https://opensource.apple.com/source/zip/) | 📦 | ZIP archiver |
| [unzip](https://opensource.apple.com/source/unzip/) | 📦 | ZIP extractor |

## Scripting Languages

| Component | Status | Description |
|-----------|--------|-------------|
| [python](https://opensource.apple.com/source/python/) | 📦 | Python interpreter |
| [ruby](https://opensource.apple.com/source/ruby/) | 📦 | Ruby interpreter |
| [perl](https://opensource.apple.com/source/perl/) | 📦 | Perl interpreter |
| [tcl](https://opensource.apple.com/source/tcl/) | 📦 | Tcl interpreter |

## Build Tools

| Component | Status | Description |
|-----------|--------|-------------|
| [bsd_make](https://opensource.apple.com/source/bsd_make/) | 📦 | BSD make |
| [bmake](https://opensource.apple.com/source/bmake/) | 📦 | NetBSD make |
| [gnumake](https://opensource.apple.com/source/gnumake/) | 📦 | GNU make |

## Libraries

| Component | Status | Description |
|-----------|--------|-------------|
| [ncurses](https://opensource.apple.com/source/ncurses/) | 📦 | Terminal handling |
| [libedit](https://opensource.apple.com/source/libedit/) | 📦 | Command line editing |
| [libiconv](https://opensource.apple.com/source/libiconv/) | 📦 | Character conversion |

## System Daemons

| Component | Status | Description |
|-----------|--------|-------------|
| [notifyd](https://opensource.apple.com/source/notifyd/) | 📦 | Notification daemon |
| [syslog](https://opensource.apple.com/source/syslog/) | 📦 | System logging |
| [asl](https://opensource.apple.com/source/asl/) | 📦 | Apple System Log |
| [OpenDirectory](https://opensource.apple.com/source/OpenDirectory/) | 📦 | Directory services |
| [DirectoryService](https://opensource.apple.com/source/DirectoryService/) | 📦 | Legacy directory services |

---

## Summary

| Category | Available | Documented |
|----------|-----------|------------|
| Core System | 10 | 1 |
| Init/IPC | 3 | 3 |
| Dynamic Linking | 3 | 1 |
| Frameworks | 6 | 3 |
| Shell Commands | 5 | 1 |
| File Commands | 2 | 1 |
| System Commands | 4 | 1 |
| Network Commands | 4 | 2 |
| Disk Commands | 5 | 1 |
| Text Processing | 7 | 0 |
| Editors | 2 | 0 |
| Shells | 3 | 0 |
| Security/Crypto | 4 | 1 |
| Network Utilities | 2 | 0 |
| Compression | 5 | 0 |
| Scripting | 4 | 0 |
| Build Tools | 3 | 0 |
| Libraries | 3 | 0 |
| System Daemons | 5 | 1 |
| **Total** | **79** | **13** |

## Priority Build Order

For a minimal bootable Darwin system:

1. **Phase 1 - Boot**: xnu, dyld, launchd, Libsystem
2. **Phase 2 - Core**: Libc, libpthread, libdispatch, libxpc
3. **Phase 3 - Shell**: bash or zsh, shell_cmds, file_cmds, text_cmds
4. **Phase 4 - System**: system_cmds, network_cmds, diskdev_cmds
5. **Phase 5 - Services**: configd, mDNSResponder, notifyd, syslog

## Building Notes

Most command packages can be built with:

```bash
# Download
curl -O https://opensource.apple.com/tarballs/PACKAGE/PACKAGE-VERSION.tar.gz
tar xzf PACKAGE-VERSION.tar.gz
cd PACKAGE-VERSION

# Build with Xcode
xcodebuild -project *.xcodeproj \
    -alltargets \
    -configuration Release \
    ARCHS=arm64 \
    SDKROOT=macosx

# Or manual build for simple commands
clang -arch arm64 -O2 -o command command.c
```

## References

- [Apple Open Source](https://opensource.apple.com/)
- [Apple Open Source Tarballs](https://opensource.apple.com/tarballs/)
- [macOS Release Sources](https://opensource.apple.com/releases/)
