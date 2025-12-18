# XNU on Raspberry Pi 3 (BCM2837)

[![Userland Build](https://github.com/Inokinoki/xnu-bcm2837-hackintosh/actions/workflows/userland-build.yml/badge.svg)](https://github.com/Inokinoki/xnu-bcm2837-hackintosh/actions/workflows/userland-build.yml)

I am trying to run XNU/Hackintosh, if possible. You can back me on this project :)

## Roadmap

XNU Kernel:

- [x] Compile Mach-O

~Then, there are three options. Either:~

- ~[ ] Convert to an ELF Kernel and then raw image~
- ~[ ] Load the raw image~

~or:~

- ~[x] Convert and load raw image~

~or,~

Then, we can write an Mach-O loader in ELF format, which can be loaded by Raspberry Pi:

- [ ] Maybe an Mach-O loader

The kernel can be debugged and further developed:

- [ ] Make sure the kernel is bootable
- [ ] Make sure UART works
- [ ] Try to make a VC4 driver

Userland:

- [ ] Build launchd (init system)
- [ ] Build libdispatch (Grand Central Dispatch)
- [ ] Build libxpc (IPC library)
- [ ] Build Libc and core libraries
- [ ] Build dyld (dynamic linker)

Hackintosh:

- [ ] Try to make an ARM64 macOS sysroot

## Build

### Kernel

The following kernel version(s) can be successfully built at the moment:

- [XNU 7195.81.3](Build/XNU-7195.81.3.md)

See the doc for detailed build steps and patches.

### Userland

After building the kernel, you need to build the Darwin userland components. See the [Userland](Userland/README.md) directory for build instructions, starting with launchd.

The recommended build order is:

1. [Libc](Userland/Libc.md) - C standard library
2. [libdispatch](Userland/libdispatch.md) - Grand Central Dispatch
3. [libxpc](Userland/libxpc.md) - XPC inter-process communication
4. [launchd](Userland/launchd.md) - Init system (PID 1)
5. [dyld](Userland/dyld.md) - Dynamic linker
6. [CoreFoundation](Userland/CoreFoundation.md) - Core framework

## Any other problems

Please create an issue if you have any problems when building XNU or userland components.
