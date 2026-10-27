# XNU on Raspberry Pi 3 (BCM2837)

I am trying to run XNU/Hackintosh, if possible. You can back me on this project :)

## Status

The xnu-8796.141.3 kernel (the iOS 16 / macOS 13.5 generation) builds in CI for the
BCM2837 machine config and **boots on QEMU `raspi3b` up to an idle IOKit**:
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
