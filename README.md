# XNU on Raspberry Pi 3 (BCM2837)

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

Hackintosh:

- [ ] Try to make an ARM64 macOS sysroot

## Build

The following kernel version(s) can be successfully built at the moment:

- [XNU 7195.81.3](Build/XNU-7195.81.3.md)

See the doc for detailed build steps and patches.
