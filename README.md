# Trying to run XNU on Raspberry Pi 3 (BCM2837)

I am trying to run XNU/Hackitosh, if possible. You can support me for this project :)

## Roadmap

XNU:

- Compile Mach-O
- Compile ELF Kernel

Raspberry Pi:

- Maybe a Mach-O loader
- Load ELF Kernel

Hackintosh:

- Try to make an ARM64 macOS sysroot

## Build

The kernel can be built with the following command:

```
make SDKROOT=macosx ARCH_CONFIGS=ARM64 MACHINE_CONFIGS=BCM2837 KERNEL_CONFIGS=RELEASE/DEVELOPEMENT
```
