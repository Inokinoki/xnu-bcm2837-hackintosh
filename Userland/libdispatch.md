# Building libdispatch (Grand Central Dispatch) for ARM64

libdispatch, also known as Grand Central Dispatch (GCD), is Apple's library for concurrent programming. It is a core dependency for launchd and many other Darwin components.

## Overview

libdispatch provides:

- Dispatch queues for concurrent and serial execution
- Dispatch sources for event handling (timers, signals, file descriptors)
- Dispatch groups for synchronizing multiple tasks
- Dispatch semaphores and barriers
- Quality of Service (QoS) classes

## Source

Download from Apple Open Source:
- **Latest**: https://opensource.apple.com/source/libdispatch/
- **Recommended Version**: libdispatch-1271.120.2 (macOS 11.x compatible)
- **Swift Open Source**: https://github.com/apple/swift-corelibs-libdispatch

```bash
# Option 1: Apple Open Source
curl -O https://opensource.apple.com/tarballs/libdispatch/libdispatch-1271.120.2.tar.gz
tar xzf libdispatch-1271.120.2.tar.gz
cd libdispatch-1271.120.2

# Option 2: Swift open-source version (more portable)
git clone https://github.com/apple/swift-corelibs-libdispatch.git
cd swift-corelibs-libdispatch
```

## Dependencies

| Dependency | Purpose | Required |
|------------|---------|----------|
| XNU Headers | Kernel interfaces (Mach, pthread) | ✅ Yes |
| [Libc](Libc.md) | C standard library | ✅ Yes |
| libpthread | POSIX threads | ✅ Yes |
| Blocks Runtime | Clang blocks support | ✅ Yes |

## Project Structure

```
libdispatch/
├── src/
│   ├── queue.c              # Dispatch queue implementation
│   ├── source.c             # Dispatch sources
│   ├── semaphore.c          # Dispatch semaphores
│   ├── apply.c              # dispatch_apply
│   ├── benchmark.c          # Benchmarking utilities
│   └── shims/               # Platform compatibility shims
├── dispatch/
│   ├── dispatch.h           # Main public header
│   ├── queue.h              # Queue APIs
│   ├── source.h             # Source APIs
│   └── ...
├── private/
│   └── ...                  # Private headers
└── os/
    └── ...                  # OS integration headers
```

## Build Instructions

### Option A: Using CMake (Swift Open Source Version)

The Swift open-source version uses CMake and is more portable:

```bash
cd swift-corelibs-libdispatch

mkdir build && cd build

cmake .. \
    -DCMAKE_C_COMPILER=clang \
    -DCMAKE_CXX_COMPILER=clang++ \
    -DCMAKE_OSX_ARCHITECTURES=arm64 \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=/usr/local

make -j$(sysctl -n hw.ncpu)
make install DESTDIR=/path/to/install
```

### Option B: Using Xcode (Apple Version)

```bash
# Set up environment
export SDKROOT=$(xcrun --sdk macosx --show-sdk-path)
export XNU_HEADERS=/path/to/xnu/BUILD/dst/usr/include

# Build with xcodebuild
xcodebuild -project libdispatch.xcodeproj \
    -target libdispatch \
    -configuration Release \
    ARCHS=arm64 \
    VALID_ARCHS=arm64 \
    HEADER_SEARCH_PATHS="${XNU_HEADERS}"
```

### Option C: Manual Build

```bash
# Environment setup
export CC=clang
export CFLAGS="-arch arm64 -I/path/to/xnu/headers -fblocks"
export LDFLAGS="-arch arm64"

# Compile source files
clang ${CFLAGS} -c src/queue.c -o queue.o
clang ${CFLAGS} -c src/source.c -o source.o
clang ${CFLAGS} -c src/semaphore.c -o semaphore.o
# ... compile remaining files

# Create dynamic library
clang ${LDFLAGS} -dynamiclib -o libdispatch.dylib *.o \
    -install_name /usr/lib/system/libdispatch.dylib
```

## Patches for ARM64 (Raspberry Pi)

### 1. Disable arm64e Features

```c
// In src/shims/arch/arm64/internal.h or similar
#if defined(__arm64__) && !defined(__ARM64E__)
// Remove PAC-related code
#undef DISPATCH_USE_PAC
#endif
```

### 2. Configure for Embedded

```bash
# Add to CFLAGS
-DDISPATCH_USE_INTERNAL_WORKQUEUE=1
-DCONFIG_EMBEDDED=1
```

### 3. Workqueue Backend

libdispatch uses kernel workqueues by default. For Raspberry Pi, you may need the internal (pthread-based) implementation:

```c
// Define in build
#define DISPATCH_USE_INTERNAL_WORKQUEUE 1
```

## Headers Installation

Install headers for dependent projects:

```bash
# Create header directories
mkdir -p /path/to/install/usr/include/dispatch
mkdir -p /path/to/install/usr/include/os

# Copy public headers
cp dispatch/*.h /path/to/install/usr/include/dispatch/
cp os/*.h /path/to/install/usr/include/os/
```

## Output Files

| File | Location | Description |
|------|----------|-------------|
| `libdispatch.dylib` | `/usr/lib/system/` | Main shared library |
| `dispatch/*.h` | `/usr/include/dispatch/` | Public headers |
| `os/*.h` | `/usr/include/os/` | OS integration headers |

## Verification

### Simple Test Program

```c
// test_dispatch.c
#include <dispatch/dispatch.h>
#include <stdio.h>

int main() {
    dispatch_queue_t queue = dispatch_get_global_queue(
        DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    
    dispatch_async(queue, ^{
        printf("Hello from libdispatch!\n");
    });
    
    dispatch_main();
    return 0;
}
```

```bash
# Compile and run
clang -fblocks test_dispatch.c -ldispatch -o test_dispatch
./test_dispatch
```

### Verify Library

```bash
# Check library architecture
file libdispatch.dylib

# Check symbols
nm -g libdispatch.dylib | grep dispatch_async
```

## Integration Notes

### Blocks Runtime

libdispatch requires Clang's Blocks runtime. Ensure `-fblocks` is used when compiling:

```bash
clang -fblocks myprogram.c -ldispatch
```

### Thread Local Storage

libdispatch uses thread-local storage extensively. Ensure your runtime supports `__thread` or `_Thread_local`.

### Kernel Support

For optimal performance, libdispatch uses kernel workqueues. Check XNU configuration:

```c
// XNU should have these enabled
#define CONFIG_WORKQUEUE 1
#define CONFIG_PTHREAD_WORKQUEUE 1
```

## Known Issues

### 1. Missing Workqueue Support

If XNU doesn't have workqueue support, use internal implementation:

```bash
-DDISPATCH_USE_INTERNAL_WORKQUEUE=1
```

### 2. QoS Not Supported

Quality of Service may not work on non-Apple hardware. Disable or stub out:

```c
#define DISPATCH_USE_QOS_CLASS 0
```

### 3. Voucher System

The voucher system requires kernel support. May need to be disabled:

```c
#define DISPATCH_USE_VOUCHERS 0
```

## References

- [Grand Central Dispatch - Apple Developer](https://developer.apple.com/documentation/dispatch)
- [Swift libdispatch](https://github.com/apple/swift-corelibs-libdispatch)
- [GCD Internals (objc.io)](https://www.objc.io/issues/2-concurrency/low-level-concurrency-apis/)
- [Apple Open Source](https://opensource.apple.com/source/libdispatch/)

## Next Steps

After building libdispatch:

1. Build [libxpc](libxpc.md) (next dependency for launchd)
2. Verify integration with test programs
3. Install headers and library for launchd build
