# Building file_cmds for ARM64

file_cmds contains essential file manipulation utilities for Darwin/macOS.

## Overview

file_cmds provides file operation utilities including:

- `chflags` - Change file flags
- `chmod` - Change file modes
- `chown` / `chgrp` - Change ownership
- `cksum` - Display file checksums
- `compress` / `uncompress` - File compression
- `cp` - Copy files
- `dd` - Convert and copy files
- `df` - Display free disk space
- `du` - Display disk usage
- `install` - Install binaries
- `ipcrm` / `ipcs` - IPC utilities
- `ln` - Create links
- `ls` - List directory contents
- `mkdir` - Make directories
- `mkfifo` - Make FIFOs
- `mknod` - Make special files
- `mtree` - Map directory hierarchy
- `mv` - Move files
- `pathchk` - Check pathnames
- `pax` - Portable archive exchange
- `rm` - Remove files
- `rmdir` - Remove directories
- `shar` - Create shell archives
- `split` - Split files
- `stat` - Display file status
- `touch` - Change file times
- `xattr` - Extended attributes

## Source

Download from Apple Open Source:
- **URL**: https://opensource.apple.com/source/file_cmds/
- **Recommended Version**: file_cmds-321.100.10 or latest

```bash
curl -O https://opensource.apple.com/tarballs/file_cmds/file_cmds-321.100.10.tar.gz
tar xzf file_cmds-321.100.10.tar.gz
cd file_cmds-321.100.10
```

## Dependencies

| Dependency | Purpose | Required |
|------------|---------|----------|
| [Libc](Libc.md) | C standard library | ✅ Yes |
| XNU Headers | System calls, stat structures | ✅ Yes |
| libutil | Utility functions | Optional |

## Project Structure

```
file_cmds/
├── ls/
│   ├── ls.c
│   ├── ls.h
│   ├── cmp.c
│   ├── print.c
│   └── util.c
├── cp/
│   ├── cp.c
│   └── utils.c
├── mv/
│   └── mv.c
├── rm/
│   └── rm.c
├── chmod/
│   └── chmod.c
├── chown/
│   └── chown.c
├── stat/
│   └── stat.c
└── ... (other commands)
```

## Build Instructions

### Using Xcode

```bash
xcodebuild -project file_cmds.xcodeproj \
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

# Build ls (multiple source files)
clang ${CFLAGS} -o ls ls/ls.c ls/cmp.c ls/print.c ls/util.c

# Build simple commands
clang ${CFLAGS} -o cp cp/cp.c cp/utils.c
clang ${CFLAGS} -o mv mv/mv.c
clang ${CFLAGS} -o rm rm/rm.c
clang ${CFLAGS} -o mkdir mkdir/mkdir.c
clang ${CFLAGS} -o chmod chmod/chmod.c
clang ${CFLAGS} -o touch touch/touch.c
clang ${CFLAGS} -o stat stat/stat.c
```

## Key Commands

### ls - List Directory Contents

The most complex command in file_cmds:

```c
// ls supports many options
ls -la          // Long format, all files
ls -lh          // Human-readable sizes
ls -R           // Recursive listing
ls --color      // Colored output (if supported)
```

### cp - Copy Files

```c
cp source dest              // Copy file
cp -r source_dir dest_dir   // Copy directory recursively
cp -p source dest           // Preserve attributes
```

### stat - File Status

```c
stat filename               // Display file information
stat -f "%z" filename       // File size only
```

## Output Binaries

| Binary | Location | Description |
|--------|----------|-------------|
| `ls`, `cp`, `mv`, `rm` | `/bin/` | Core file utilities |
| `chmod`, `chown` | `/bin/` | Permission utilities |
| `stat`, `touch` | `/usr/bin/` | File info utilities |

## Patches for ARM64

### stat structure differences

```c
// Handle potential struct stat differences
#if defined(__APPLE__) && defined(__arm64__)
// Use appropriate stat variant
#endif
```

### Extended attributes

```c
// xattr support for ARM64
#include <sys/xattr.h>
// Use listxattr, getxattr, setxattr
```

## Verification

```bash
# Test built commands
./ls -la /
./stat /etc/passwd
./mkdir test_dir && ./rmdir test_dir
./touch testfile && ./rm testfile
```

## References

- [Apple Open Source - file_cmds](https://opensource.apple.com/source/file_cmds/)
- [POSIX file utilities](https://pubs.opengroup.org/onlinepubs/9699919799/)

## Next Steps

After building file_cmds:

1. Build [system_cmds](system_cmds.md) for system utilities
2. Build [network_cmds](network_cmds.md) for network tools
3. Create minimal root filesystem
