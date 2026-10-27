# XNU on Raspberry Pi 3 (BCM2837)

I am trying to run XNU/Hackintosh, if possible. You can back me on this project :)

## Status

The xnu-8796.141.3 kernel (the iOS 16 / macOS 13.5 generation) builds in CI for the
BCM2837 machine config and **boots on QEMU `raspi3b` to userspace**: the kernel mounts an HFS+ RAM disk root (`rd=md0`, Apple's open source hfs-627.100.6 built in) and runs `/sbin/launchd`, currently a test PID 1: `tools/mkpi-init.sh /tmp/init`, put it at `sbin/launchd` in a directory, `tools/mkhfsroot.py DIR root.img`, then `RAMDISK=root.img tools/pi3-qemu-boot.sh KERNEL`. (A Mach-O RAM disk image works too: mockfs serves it as launchd.) Earlier it stopped at an idle IOKit:
virtual memory, zones, the logging subsystem and the BCM2837 platform expert come
up and the kernel then sits in the idle thread. Not yet done: a root filesystem,
`launchd`, any driver besides the mini UART, and a run on real hardware.

Boot output (mini UART, QEMU `raspi3b`):

```
Darwin Kernel Version 22.6.0: Mon Aug 14 05:06:07 UTC 2023; runner:xnu-8796.141.3
vm_page_bootstrap: 169052 free pages, 11172 wired pages ...
VM bootstrap done: 61 maps, 112 entries and 115 holes left
Firehose configured: 16 chunks, 8 io pages
BCM2837: starting device-tree platform expert
BCM2837: platform expert registered
```

## Roadmap

XNU Kernel:

- [x] Compile Mach-O (xnu-8796.141.3, `xnu/patches-8796.141.3/`, built by `.github/workflows/xnu-8796.141.3-bcm2837.yml`)
- [x] Mach-O loader (`loader/`): EL3/EL2 to EL1, copy the segments, boot_args and a minimal ADT, jump
- [x] Make sure the kernel is bootable (on QEMU `raspi3b`; real hardware untested)
- [x] Make sure UART works (the mini UART, set up without an ADT)
- [ ] Root filesystem and `launchd`
- [ ] Try to make a VC4 driver

Hackintosh:

- [ ] Try to make an ARM64 macOS sysroot

## How it is built and booted

- `xnu/patches-8796.141.3/` are applied on top of xnu-8796.141.3 by
  [blacktop/darwin-xnu-build](https://github.com/blacktop/darwin-xnu-build) on a macOS runner.
  The kernel is plain arm64 (no PAC), built for the Cortex-A53, with 4K pages and the
  standard non-large-memory layout (linked at `0xfffffff007004000`).
- `tools/mkpi_payload.py` packs the kernel Mach-O, a generated ADT (`tools/pi_adt.py`) and the
  command line; `loader/` is the Pi-side image that unpacks it.
- `tools/pi3-qemu-boot.sh KERNEL [SECONDS]` builds the loader, packs the kernel and boots QEMU
  `raspi3b`; the kernel console is QEMU's second serial port (the mini UART).
  `tools/pi3-qemu-panic.sh` catches the first panic under gdb; `tools/macho_sym.py` looks up symbols.

Needs: an aarch64 gcc, `qemu-system-aarch64`, `gdb-multiarch` (optional) and Python 3.

The first attempt used xnu-7195.81.3 ([notes](Build/XNU-7195.81.3.md), patches in `xnu/patches-7195.81.3/`).
It is kept for reference but superseded: iOS 16 userland needs the xnu-8796.141.3 kernel.

## 16K user pages on the 4K kernel

iOS 16 userland is built for 16K pages. `tools/pi-pagesize.S` (build with
`SRC=pi-pagesize.S tools/mkpi-init.sh OUT`, run as `/sbin/launchd`) shows what a process sees on this
4K-page kernel (QEMU `raspi3b`): `hw.pagesize` = 0x4000, commpage user page shift = 14 (kernel shift 12),
a 64K anonymous mmap is 16K aligned, and a 4K `mprotect` inside a 16K block fails. So user maps use 16K
pages on top of 4K hardware pages. Real dyld and libsystem are still untested (they need the dyld shared
cache, about 2 GB, so the root must be on block storage, not a RAM disk).

## Root on the SD card

`bsd/dev/bcm2837_sd.c` (xnu patch 0038) drives the Pi 3 EMMC controller (SDHCI, polled PIO, 1-bit bus)
and exposes the whole card as `/dev/sdroot0`; boot with `rd=sdroot0`. Patch 0039 lets a non-RAM-disk
root continue unsealed. On QEMU: `SDIMG=root.img tools/pi3-qemu-boot.sh KERNEL` (the image size must
be a power of two; `tools/mkhfsroot.py DIR root.img --size 8M` makes a bootable HFS+ one). Read-only use
is tested (HFS mounts, init runs as PID 1); the write path (CMD24/25), the 4-bit bus, SD clock rates and
real hardware are untested.

## iOS 16 userland on QEMU

`tools/mkios-root.sh DIR ios16-root.img 16G` builds an HFS+ root from the iPhone10,3 iOS 16.7.16 (20H392) IPSW
images (OS 087-86698-044, SystemOS 087-86593-047, AppOS 087-86715-047 dmgs, e.g. fetched with
`tools/remotezip.py`) in a privileged docker container (apfs-fuse, hfsprogs, rsync; see `tools/ios-root-docker/`).
The image (about 12 GB used) stays out of git. Boot it as the SD card:

```sh
CMDLINE="debug=0xc serial=3 cpus=1 keepsyms=1 kt_fixed_zones=120 -noprogress rd=sdroot0 unentitled_ios_sim_launch=1 ignition_level=1" \
SDSNAPSHOT=1 SDIMG=ios16-root.img tools/pi3-qemu-boot.sh KERNEL 300
```

`unentitled_ios_sim_launch=1` lets the macOS-configured kernel run iOS binaries; `ignition_level=1` makes
dyld use `/System/Library/Caches/com.apple.dyld` (the image has hard links there); add
`launchd_unsecure_cache=1` (a number, not a path) so `launchd_cache_loader` accepts the unsigned launchd.plist
and skips the AMFI lookup. The image carries `tools/ios-root-tweaks.py`'s changes (`_PanicOnCrash` renamed).

Observed on QEMU `raspi3b` (xnu patches 0040-0048): Apple's launchd (Darwin Bootstrapper 7.0.0) maps the dyld
shared cache (16K code signature pages are accepted, not verified: patch 0040), runs all its boot tasks
(fsck, mount, data protection, MSU, corecrypto FIPS self test, keybag, launchd_cache_loader), finishes early boot
and starts the regular daemons: xpcproxy, watchdogd, SpringBoard, backboardd, mediaserverd, mDNSResponder,
bluetoothd, lockdownd, locationd ... In a 15 minute run there is no kernel panic, but SpringBoard, backboardd
and mediaserverd crash-loop ("Too many corpses being created"): there is no display, IOSurface, HID or GPU
driver. Not done: those drivers (the Pi 3 has a VideoCore mailbox framebuffer), a real AppleMobileFileIntegrity,
networking; no hardware test. It is slow (QEMU TCG: minutes to early boot).
