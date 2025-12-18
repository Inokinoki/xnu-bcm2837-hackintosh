# Building diskdev_cmds for ARM64

diskdev_cmds contains disk and device management utilities for Darwin/macOS.

## Overview

diskdev_cmds provides disk utilities including:

- `dev_mkdb` - Device database
- `diskutil` - Disk utility (wrapper)
- `edquota` - Edit quotas
- `fdisk` - Partition editor
- `fsck` - File system check
- `fsck_hfs` - HFS+ check
- `fstyp` - File system type
- `fuser` - File users
- `mount` / `umount` - Mount file systems
- `mount_devfs` - Mount devfs
- `mount_fdesc` - Mount fdesc
- `newfs` - Create file system
- `newfs_hfs` - Create HFS+ file system
- `newfs_msdos` - Create FAT file system
- `quot` - Disk usage by user
- `quota` - Display quotas
- `quotacheck` - Check quotas
- `quotaon` / `quotaoff` - Quota control
- `repquota` - Quota report
- `setclass` - Set file class
- `tunefs` - Tune file system
- `vsdbutil` - Volume status DB
- `vndevice` - Virtual node device

## Source

Download from Apple Open Source:
- **URL**: https://opensource.apple.com/source/diskdev_cmds/
- **Recommended Version**: diskdev_cmds-667.100.1 or latest

```bash
curl -O https://opensource.apple.com/tarballs/diskdev_cmds/diskdev_cmds-667.100.1.tar.gz
tar xzf diskdev_cmds-667.100.1.tar.gz
cd diskdev_cmds-667.100.1
```

## Dependencies

| Dependency | Purpose | Required |
|------------|---------|----------|
| [Libc](Libc.md) | C standard library | ✅ Yes |
| XNU Headers | Disk structures | ✅ Yes |
| IOKit | Disk access | ✅ Yes |
| [CoreFoundation](CoreFoundation.md) | Property lists | Some commands |
| hfs | HFS+ support | fsck_hfs, newfs_hfs |

## Project Structure

```
diskdev_cmds/
├── mount.tproj/
│   └── mount.c
├── umount.tproj/
│   └── umount.c
├── fsck.tproj/
│   └── fsck.c
├── newfs.tproj/
│   └── newfs.c
├── fdisk.tproj/
│   ├── fdisk.c
│   ├── disk.c
│   └── mbr.c
├── quota.tproj/
│   └── quota.c
└── ... (other commands)
```

## Build Instructions

### Using Xcode

```bash
xcodebuild -project diskdev_cmds.xcodeproj \
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

# mount/umount
clang ${CFLAGS} -o mount mount.tproj/mount.c
clang ${CFLAGS} -o umount umount.tproj/umount.c

# fsck
clang ${CFLAGS} -o fsck fsck.tproj/fsck.c

# fdisk
clang ${CFLAGS} -o fdisk fdisk.tproj/*.c

# quota commands
clang ${CFLAGS} -o quota quota.tproj/quota.c
```

## Key Commands

### mount / umount

```bash
mount                           # Show mounted filesystems
mount -t hfs /dev/disk0s1 /mnt  # Mount HFS+ partition
mount -o ro /dev/disk0s1 /mnt   # Mount read-only
umount /mnt                     # Unmount
umount -f /mnt                  # Force unmount
```

### fdisk - Partition Table

```bash
fdisk -i /dev/rdisk0            # Initialize MBR
fdisk -e /dev/rdisk0            # Edit interactively
fdisk /dev/rdisk0               # Show partition table
```

### fsck - File System Check

```bash
fsck -y /dev/disk0s1            # Check and repair
fsck -n /dev/disk0s1            # Check only
fsck_hfs /dev/disk0s1           # Check HFS+
```

### newfs - Create File System

```bash
newfs /dev/rdisk0s1             # Create UFS
newfs_hfs /dev/rdisk0s1         # Create HFS+
newfs_msdos /dev/rdisk0s1       # Create FAT
```

## Output Binaries

| Binary | Location | Description |
|--------|----------|-------------|
| `mount`, `umount` | `/sbin/` | Mount utilities |
| `fsck`, `fsck_hfs` | `/sbin/` | Filesystem check |
| `newfs`, `newfs_hfs` | `/sbin/` | Create filesystems |
| `fdisk` | `/sbin/` | Partition editor |
| `quota*` | `/usr/sbin/` | Quota management |

## HFS+ Tools

HFS+ specific tools require the hfs kernel extension:

```bash
# fsck_hfs
clang ${CFLAGS} -o fsck_hfs fsck_hfs.tproj/*.c -framework IOKit

# newfs_hfs
clang ${CFLAGS} -o newfs_hfs newfs_hfs.tproj/*.c -framework IOKit
```

## Patches for ARM64

### Disk I/O alignment

```c
// Ensure proper disk I/O alignment
#if defined(__arm64__)
#define DISK_ALIGNMENT 4096  // 4K alignment for ARM64
#endif
```

### Partition table structures

```c
// MBR/GPT structure handling
#pragma pack(push, 1)
struct mbr_partition {
    uint8_t  boot_indicator;
    uint8_t  start_head;
    // ... properly packed
};
#pragma pack(pop)
```

## Security Considerations

### Privileged Operations

All disk operations require root privileges:

```bash
# These commands need root
sudo mount /dev/disk0s1 /mnt
sudo fsck /dev/disk0s1
sudo fdisk /dev/disk0
```

### Device Access

Ensure proper device file permissions:

```bash
# Block devices
ls -la /dev/disk*

# Raw devices
ls -la /dev/rdisk*
```

## Verification

```bash
# Test built commands (need root for most)
./mount
df -h
sudo ./fsck -n /dev/disk0s1
./fdisk /dev/disk0
```

## Related Projects

| Project | Description |
|---------|-------------|
| hfs | HFS+ filesystem implementation |
| apfs | APFS filesystem implementation |
| msdosfs | FAT filesystem implementation |

## References

- [Apple Open Source - diskdev_cmds](https://opensource.apple.com/source/diskdev_cmds/)
- [HFS+ specification](https://developer.apple.com/library/archive/technotes/tn/tn1150.html)

## Next Steps

After building diskdev_cmds:

1. Build [hfs](https://opensource.apple.com/source/hfs/) for HFS+ support
2. Create disk images for testing
3. Set up initial root filesystem
