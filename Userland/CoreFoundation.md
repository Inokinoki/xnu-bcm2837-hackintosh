# Building CoreFoundation for ARM64

CoreFoundation (CF) is Apple's C-based framework providing fundamental data types and services. It's the foundation for many higher-level frameworks and is required by numerous Darwin userland components.

## Overview

CoreFoundation provides:

- Core data types (CFString, CFArray, CFDictionary, CFData, etc.)
- Property list (plist) parsing and serialization
- Run loops for event handling
- URL and stream handling
- Plugin architecture
- Date, time, and calendar support
- Internationalization support

## Source

Download from Apple Open Source:
- **Latest**: https://opensource.apple.com/source/CF/
- **Recommended Version**: CF-1677.104 (macOS 11.x compatible)
- **Swift Open Source**: https://github.com/apple/swift-corelibs-foundation

```bash
# Option 1: Apple Open Source
curl -O https://opensource.apple.com/tarballs/CF/CF-1677.104.tar.gz
tar xzf CF-1677.104.tar.gz
cd CF-1677.104

# Option 2: Swift Foundation (cross-platform)
git clone https://github.com/apple/swift-corelibs-foundation.git
cd swift-corelibs-foundation/CoreFoundation
```

## Dependencies

| Dependency | Purpose | Required |
|------------|---------|----------|
| [Libc](Libc.md) | C library | ✅ Yes |
| [libdispatch](libdispatch.md) | Run loop integration | ✅ Yes |
| ICU | Unicode support | ✅ Yes |
| libxml2 | XML parsing | Optional |
| zlib | Compression | Optional |

## Project Structure

```
CF/
├── CFBase.c                    # Base runtime
├── CFRuntime.c                 # Object runtime
├── CFString.c                  # String type
├── CFArray.c                   # Array type
├── CFDictionary.c              # Dictionary type
├── CFData.c                    # Data type
├── CFNumber.c                  # Number types
├── CFDate.c                    # Date/time
├── CFRunLoop.c                 # Run loops
├── CFPropertyList.c            # Plist support
├── CFURL.c                     # URL handling
├── CFStream.c                  # Stream I/O
├── CFPlugIn.c                  # Plugin system
├── ForFoundationOnly.h         # Foundation bridge
├── CoreFoundation.h            # Main header
└── Makefile / CMakeLists.txt
```

## Key Types

| Type | Description | Mutable Version |
|------|-------------|-----------------|
| `CFStringRef` | Unicode string | `CFMutableStringRef` |
| `CFArrayRef` | Ordered collection | `CFMutableArrayRef` |
| `CFDictionaryRef` | Key-value mapping | `CFMutableDictionaryRef` |
| `CFDataRef` | Raw bytes | `CFMutableDataRef` |
| `CFNumberRef` | Numeric values | - |
| `CFBooleanRef` | Boolean values | - |
| `CFDateRef` | Date/time | - |
| `CFURLRef` | URL | - |
| `CFRunLoopRef` | Event loop | - |

## Build Instructions

### Option A: CMake (Swift Open Source Version)

```bash
cd swift-corelibs-foundation/CoreFoundation

mkdir build && cd build

cmake .. \
    -DCMAKE_C_COMPILER=clang \
    -DCMAKE_OSX_ARCHITECTURES=arm64 \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=/usr/local \
    -DCF_DEPLOYMENT_SWIFT=OFF

make -j$(sysctl -n hw.ncpu)
make install DESTDIR=/path/to/install
```

### Option B: Xcode (Apple Version)

```bash
export SDKROOT=$(xcrun --sdk macosx --show-sdk-path)
export LIBDISPATCH_PATH=/path/to/libdispatch
export ICU_PATH=/path/to/icu

xcodebuild -project CF.xcodeproj \
    -target CoreFoundation \
    -configuration Release \
    ARCHS=arm64 \
    VALID_ARCHS=arm64 \
    HEADER_SEARCH_PATHS="${LIBDISPATCH_PATH}/include ${ICU_PATH}/include"
```

### Option C: Manual Build

```bash
# Environment
export CC=clang
export CFLAGS="-arch arm64 -I/path/to/libdispatch/include -I/path/to/icu/include"
export LDFLAGS="-arch arm64 -L/path/to/libdispatch/lib -ldispatch"

# Compile core files
clang ${CFLAGS} -c CFBase.c -o CFBase.o
clang ${CFLAGS} -c CFRuntime.c -o CFRuntime.o
clang ${CFLAGS} -c CFString.c -o CFString.o
# ... compile remaining files

# Link
clang ${LDFLAGS} -dynamiclib -o CoreFoundation.framework/CoreFoundation *.o \
    -install_name /System/Library/Frameworks/CoreFoundation.framework/CoreFoundation \
    -ldispatch -licucore
```

## Patches for ARM64 (Raspberry Pi)

### 1. Disable arm64e Features

```c
// In CFBase.c and related files
#if defined(__arm64__) && !defined(__ARM64E__)
#define CF_USE_POINTER_AUTHENTICATION 0
#endif
```

### 2. ICU Configuration

CoreFoundation needs ICU for Unicode support:

```bash
# Build ICU for ARM64 first
# Then point CF to it
export CFLAGS="${CFLAGS} -I/path/to/icu/include"
export LDFLAGS="${LDFLAGS} -L/path/to/icu/lib -licuuc -licui18n"
```

### 3. Embedded Mode

```bash
export CFLAGS="${CFLAGS} -DDEPLOYMENT_TARGET_EMBEDDED=1"
```

### 4. Disable Objective-C Bridging

For pure C usage:

```c
#define CF_BUILDING_CF 1
#define DEPLOYMENT_RUNTIME_C 1
```

## Usage Examples

### Working with Strings

```c
#include <CoreFoundation/CoreFoundation.h>

// Create strings
CFStringRef str = CFSTR("Hello, World!");
CFStringRef str2 = CFStringCreateWithCString(NULL, "Dynamic", kCFStringEncodingUTF8);

// Get length
CFIndex len = CFStringGetLength(str);

// Compare
CFComparisonResult result = CFStringCompare(str, str2, 0);

// Release
CFRelease(str2);
```

### Working with Dictionaries

```c
#include <CoreFoundation/CoreFoundation.h>

// Create dictionary
CFMutableDictionaryRef dict = CFDictionaryCreateMutable(
    NULL, 0, 
    &kCFTypeDictionaryKeyCallBacks,
    &kCFTypeDictionaryValueCallBacks
);

// Add values
CFDictionarySetValue(dict, CFSTR("key"), CFSTR("value"));
CFDictionarySetValue(dict, CFSTR("number"), CFNumberCreate(NULL, kCFNumberIntType, &(int){42}));

// Get value
CFStringRef val = CFDictionaryGetValue(dict, CFSTR("key"));

CFRelease(dict);
```

### Property Lists

```c
#include <CoreFoundation/CoreFoundation.h>

// Parse plist from data
CFDataRef plistData = /* load from file */;
CFPropertyListRef plist = CFPropertyListCreateWithData(
    NULL, plistData, 
    kCFPropertyListImmutable, 
    NULL, NULL
);

// Create plist data
CFDictionaryRef dict = /* create dictionary */;
CFDataRef xmlData = CFPropertyListCreateData(
    NULL, dict,
    kCFPropertyListXMLFormat_v1_0,
    0, NULL
);
```

### Run Loops

```c
#include <CoreFoundation/CoreFoundation.h>

// Get main run loop
CFRunLoopRef runLoop = CFRunLoopGetMain();

// Create timer
CFRunLoopTimerRef timer = CFRunLoopTimerCreate(
    NULL, 
    CFAbsoluteTimeGetCurrent() + 1.0,  // Fire in 1 second
    1.0,                                 // Repeat every 1 second
    0, 0,
    timerCallback,
    NULL
);

// Add to run loop
CFRunLoopAddTimer(runLoop, timer, kCFRunLoopDefaultMode);

// Run
CFRunLoopRun();
```

## Output Files

| File | Location | Description |
|------|----------|-------------|
| `CoreFoundation` | `/System/Library/Frameworks/CoreFoundation.framework/` | Main framework |
| `CoreFoundation.h` | `CoreFoundation.framework/Headers/` | Main header |
| `CoreFoundation.tbd` | (optional) | Text-based stub |

## Framework Structure

```
CoreFoundation.framework/
├── CoreFoundation           # Main binary
├── Headers/
│   ├── CoreFoundation.h
│   ├── CFArray.h
│   ├── CFString.h
│   └── ...
├── Resources/
│   └── Info.plist
└── Versions/
    └── A/
        └── ...
```

## Integration with launchd

launchd uses CoreFoundation for:

- Reading property list configuration files
- Run loop integration
- String handling

```c
// launchd plist parsing
CFURLRef plistURL = CFURLCreateWithFileSystemPath(
    NULL, CFSTR("/System/Library/LaunchDaemons/com.example.plist"),
    kCFURLPOSIXPathStyle, false
);

CFDataRef plistData;
CFURLCreateDataAndPropertiesFromResource(
    NULL, plistURL, &plistData, NULL, NULL, NULL
);

CFPropertyListRef plist = CFPropertyListCreateWithData(
    NULL, plistData, kCFPropertyListImmutable, NULL, NULL
);
```

## Known Issues

### 1. ICU Dependency

CF requires ICU (International Components for Unicode):

```bash
# Build ICU for ARM64
curl -LO https://github.com/unicode-org/icu/releases/download/release-70-1/icu4c-70_1-src.tgz
tar xzf icu4c-70_1-src.tgz
cd icu/source
./configure --host=aarch64-apple-darwin --prefix=/usr/local
make && make install
```

### 2. Toll-Free Bridging

On macOS, CF types bridge to Objective-C (NS types). This requires Objective-C runtime:

```c
// For pure C environments, disable bridging
#define CF_BRIDGING_ENABLED 0
```

### 3. Plugin System

CFPlugIn may need additional configuration:

```c
// Disable if not needed
#define CF_PLUGIN_SUPPORT 0
```

## References

- [Apple Open Source - CF](https://opensource.apple.com/source/CF/)
- [Core Foundation Design Concepts](https://developer.apple.com/library/archive/documentation/CoreFoundation/Conceptual/CFDesignConcepts/)
- [Swift CoreFoundation](https://github.com/apple/swift-corelibs-foundation)
- [Core Foundation Programming Guide](https://developer.apple.com/library/archive/documentation/CoreFoundation/Conceptual/CFDesignConcepts/CFDesignConcepts.html)

## Next Steps

After building CoreFoundation:

1. Test plist parsing with launchd configuration
2. Build higher-level components that depend on CF
3. Consider building Foundation (Objective-C wrapper) if needed
