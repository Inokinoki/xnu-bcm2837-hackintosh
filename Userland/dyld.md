# Building dyld (Dynamic Linker) for ARM64

dyld is Darwin's dynamic linker/loader. It is responsible for loading Mach-O executables and their dependent dynamic libraries at runtime.

## Overview

dyld provides:

- Loading Mach-O executables and dynamic libraries
- Symbol resolution and binding
- Lazy and non-lazy symbol binding
- Library search paths and @rpath support
- dlopen/dlsym/dlclose APIs
- Two-level namespace support
- Code signing verification (on Apple platforms)

## Source

Download from Apple Open Source:
- **Latest**: https://opensource.apple.com/source/dyld/
- **Recommended Version**: dyld-832.7.3 (macOS 11.x compatible)

```bash
curl -O https://opensource.apple.com/tarballs/dyld/dyld-832.7.3.tar.gz
tar xzf dyld-832.7.3.tar.gz
cd dyld-832.7.3
```

## Dependencies

| Dependency | Purpose | Required |
|------------|---------|----------|
| XNU Headers | Kernel interfaces, Mach-O definitions | ✅ Yes |
| [Libc](Libc.md) | C library (bootstrapped) | ✅ Yes |
| ld64 | Linker (for building dyld) | ✅ Yes |

## Architecture

dyld's loading process:

```
┌─────────────────────────────────────────────────────────────┐
│                      XNU Kernel                              │
│  1. Parse Mach-O header                                      │
│  2. Map segments into memory                                 │
│  3. Load dyld at LC_LOAD_DYLINKER address                   │
│  4. Jump to dyld entry point                                 │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                        dyld                                  │
│  1. Initialize dyld itself (no dependencies!)               │
│  2. Load main executable's dependencies                     │
│  3. Recursively load all dependencies                       │
│  4. Bind symbols (lazy and non-lazy)                        │
│  5. Run initializers (+load, __attribute__((constructor)))  │
│  6. Call main()                                             │
└─────────────────────────────────────────────────────────────┘
```

## Project Structure

```
dyld/
├── src/
│   ├── dyld.cpp                 # Main dyld implementation
│   ├── dyld2.cpp                # dyld2 loader
│   ├── dyld3/                   # dyld3 (closure-based) loader
│   │   ├── Closure.cpp
│   │   ├── ClosureBuilder.cpp
│   │   └── ...
│   ├── ImageLoader.cpp          # Image loading logic
│   ├── ImageLoaderMachO.cpp     # Mach-O specific loading
│   └── ...
├── include/
│   ├── dlfcn.h                  # dlopen/dlsym APIs
│   └── mach-o/
│       ├── dyld.h
│       └── ...
├── dyld3/                       # dyld3 specific code
├── testing/                     # Test cases
└── unit-tests/
```

## Build Instructions

### Special Considerations

dyld is unique because:

1. It cannot depend on any dynamic libraries during initialization
2. It must be completely self-contained
3. It bootstraps the entire dynamic linking system

### Environment Setup

```bash
export SDKROOT=$(xcrun --sdk macosx --show-sdk-path)
export XNU_HEADERS=/path/to/xnu/BUILD/dst/usr/include
export ARCH_FLAGS="-arch arm64"

export CXXFLAGS="${ARCH_FLAGS} -I${XNU_HEADERS} -std=c++17 -fno-rtti -fno-exceptions"
export LDFLAGS="${ARCH_FLAGS} -static"
```

### Building with Xcode

```bash
xcodebuild -project dyld.xcodeproj \
    -target dyld \
    -configuration Release \
    ARCHS=arm64 \
    VALID_ARCHS=arm64 \
    SDKROOT=macosx
```

### Key Build Flags

dyld requires specific flags:

```bash
# No RTTI or exceptions (self-contained)
-fno-rtti
-fno-exceptions

# Static linking for dyld itself
-static

# Position independent code
-fPIC

# No standard library (uses custom implementations)
-nostdlib (for some components)
```

## Patches for ARM64 (Raspberry Pi)

### 1. Disable arm64e/PAC

```cpp
// In src/dyld.cpp and related files
#if defined(__arm64__) && !defined(__ARM64E__)
#define SUPPORT_POINTER_AUTHENTICATION 0
#endif
```

### 2. Disable Code Signing

For development, disable code signature verification:

```cpp
// In ImageLoaderMachO.cpp
#define SKIP_CODESIGN_CHECK 1
```

### 3. Embedded Configuration

```bash
export CXXFLAGS="${CXXFLAGS} -DCONFIG_EMBEDDED=1"
```

### 4. dyld3 vs dyld2

dyld3 uses pre-computed closures for faster launch. For initial port, dyld2 may be simpler:

```cpp
// Force dyld2 mode
#define SUPPORT_DYLD3 0
```

## Key Components

### Image Loading

```cpp
// ImageLoader hierarchy
ImageLoader              // Base class
├── ImageLoaderMachO     // Mach-O loading
│   ├── ImageLoaderMachOCompressed  // Modern compressed LINKEDIT
│   └── ImageLoaderMachOClassic     // Classic symbol tables
```

### Symbol Binding

```cpp
// Lazy binding (on first call)
// - Uses dyld_stub_binder
// - Resolved through indirect symbol table

// Non-lazy binding (at load time)
// - Resolved during image loading
// - Required for data references
```

### dlopen API

```cpp
#include <dlfcn.h>

// Load a library at runtime
void *handle = dlopen("/usr/lib/libfoo.dylib", RTLD_LAZY);

// Look up a symbol
void *sym = dlsym(handle, "function_name");

// Call the function
typedef int (*func_t)(void);
func_t func = (func_t)sym;
int result = func();

// Close the library
dlclose(handle);
```

## Output Files

| File | Location | Description |
|------|----------|-------------|
| `dyld` | `/usr/lib/dyld` | Dynamic linker executable |
| `libdyld.dylib` | `/usr/lib/system/` | dyld support library |
| `dlfcn.h` | `/usr/include/` | dlopen API header |
| `mach-o/*.h` | `/usr/include/mach-o/` | Mach-O headers |

## Integration with XNU

The kernel locates dyld via the `LC_LOAD_DYLINKER` load command in Mach-O:

```
Load command:
      cmd LC_LOAD_DYLINKER
  cmdsize 32
     name /usr/lib/dyld (offset 12)
```

XNU's process:

1. Parse executable's Mach-O header
2. Find `LC_LOAD_DYLINKER` command
3. Map dyld into process address space
4. Set up initial stack with argc, argv, envp, apple[]
5. Jump to dyld's entry point

## Environment Variables

dyld behavior can be controlled via environment variables:

| Variable | Description |
|----------|-------------|
| `DYLD_PRINT_LIBRARIES` | Print libraries as they're loaded |
| `DYLD_PRINT_BINDINGS` | Print symbol bindings |
| `DYLD_PRINT_INITIALIZERS` | Print initializer calls |
| `DYLD_LIBRARY_PATH` | Additional library search paths |
| `DYLD_INSERT_LIBRARIES` | Libraries to inject |
| `DYLD_IMAGE_SUFFIX` | Suffix for library names (e.g., _debug) |

## Verification

### Test Dynamic Loading

```c
// test_dyld.c
#include <stdio.h>
#include <dlfcn.h>

int main() {
    // Test dlopen
    void *handle = dlopen("/usr/lib/libSystem.B.dylib", RTLD_LAZY);
    if (!handle) {
        fprintf(stderr, "dlopen failed: %s\n", dlerror());
        return 1;
    }
    
    printf("Successfully loaded libSystem.B.dylib\n");
    
    // Test dlsym
    void *sym = dlsym(handle, "malloc");
    if (sym) {
        printf("Found malloc at %p\n", sym);
    }
    
    dlclose(handle);
    return 0;
}
```

### Check dyld Version

```bash
# Print dyld version
dyld_info -version /usr/lib/dyld

# Or use otool
otool -L /bin/ls
```

## Known Issues

### 1. Closure Generation

dyld3 closures require support from the build system:

```bash
# May need to disable for initial port
-DSUPPORT_DYLD3=0
```

### 2. Shared Cache

dyld uses a shared cache for system libraries:

```bash
# Location: /System/Library/dyld/dyld_shared_cache_arm64
# May need to build with update_dyld_shared_cache
```

### 3. Thread Local Variables

TLS requires coordination with libpthread:

```cpp
// Ensure __thread / _Thread_local support
```

## Building the Shared Cache

For a complete system, you need the dyld shared cache:

```bash
# Build shared cache (run on macOS)
update_dyld_shared_cache -force -root /path/to/sysroot
```

## References

- [Apple Open Source - dyld](https://opensource.apple.com/source/dyld/)
- [WWDC 2017 - App Startup Time](https://developer.apple.com/videos/play/wwdc2017/413/)
- [dyld source documentation](https://opensource.apple.com/source/dyld/dyld-832.7.3/doc/)
- [Mach-O Programming Topics](https://developer.apple.com/library/archive/documentation/DeveloperTools/Conceptual/MachOTopics/)

## Next Steps

After building dyld:

1. Build [launchd](launchd.md) (uses dynamic linking)
2. Create shared cache for system libraries
3. Test complete boot with XNU → dyld → launchd
