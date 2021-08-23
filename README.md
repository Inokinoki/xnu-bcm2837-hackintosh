# XNU on Raspberry Pi 3 (BCM2837)

I am trying to run XNU/Hackitosh, if possible. You can back me on this project :)

## Roadmap

XNU Kernel:

- [x] Compile Mach-O

Then, there are two options. Either :

- [ ] Convert to an ELF Kernel
- [ ] Load ELF Kernel

or, we can write an Mach-O loader in ELF format, which can be loaded by Raspberry Pi:

- [ ] Maybe a Mach-O loader

After one of this, the kernel can be debugged and further developped:

- [ ] Make sure the kernel bootable
- [ ] Make sure UART work
- [ ] Try to make a VC4 driver

Hackintosh:

- [ ] Try to make an ARM64 macOS sysroot

## Build

The following kernel version(s) can be successfully built at the moment:

- [XNU 7195.81.3](Build/XNU-7195.81.3.md)

See the doc for detailed build steps and patches.
