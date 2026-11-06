iOS-platform-only patches for xnu-8796.141.3 on the BCM2837.

`.github/workflows/xnu-8796.141.3-bcm2837-ios.yml` applies `../patches-8796.141.3/` (shared with the
macOS-platform build, which is untouched) and then the files here, built with `SDKROOT=iphoneos`
(PLATFORM=iPhoneOS, `XNU_TARGET_OS_IOS`, iOS user VA limits). Name new patches `10NN-ios-*.patch` so
they apply after the shared ones.
