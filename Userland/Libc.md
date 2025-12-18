# Building Libc (Darwin C Library) for ARM64

Libc is the C standard library implementation for Darwin. It provides the fundamental runtime support for all userland programs, including system calls, memory allocation, and POSIX APIs.

## Overview

Darwin's Libc provides:

- POSIX C standard library functions
- System call wrappers
- String and memory manipulation
- File I/O operations
- Dynamic memory allocation (malloc)
- Thread support integration
- Math library functions

**Note**: Darwin's Libc is bundled as part of `libSystem.B.dylib`, which combines Libc, libm, libpthread, and other core libraries.

## Source

Download from Apple Open Source:
- **Latest**: https://opensource.apple.com/source/Libc/
- **Recommended Version**: Libc-1439.141.1 (macOS 11.x compatible)

```bash
curl -O https://opensource.apple.com/tarballs/Libc/Libc-1439.141.1.tar.gz
tar xzf Libc-1439.141.1.tar.gz
cd Libc-1439.141.1
```

## Related Projects

Darwin's C library is split across multiple projects:

| Project | Description |
|---------|-------------|
| Libc | Core C library |
| libpthread | POSIX threads |
| libmalloc | Memory allocation |
| libplatform | Platform abstractions |
| xnu/libsyscall | System call stubs |
| Libm | Math library |

## Dependencies

| Dependency | Purpose | Required |
|------------|---------|----------|
| XNU Headers | Kernel interfaces, syscall numbers | ✅ Yes |
| libsyscall | System call stubs | ✅ Yes |
| Compiler | Clang with Darwin support | ✅ Yes |

## Project Structure

```
Libc/
├── arm/                     # ARM architecture-specific
│   └── ...
├── gen/                     # General functions
│   ├── getcwd.c
│   ├── getenv.c
│   └── ...
├── stdio/                   # Standard I/O
│   ├── fopen.c
│   ├── printf.c
│   └── ...
├── stdlib/                  # Standard library
│   ├── malloc.c (or via libmalloc)
│   ├── strtol.c
│   └── ...
├── string/                  # String functions
│   ├── strcpy.c
│   ├── memcpy.c
│   └── ...
├── sys/                     # System calls
│   └── ...
├── include/                 # Headers
│   ├── stdio.h
│   ├── stdlib.h
│   └── ...
└── Makefile
```

## Build Instructions

### Prerequisites

1. Build XNU headers first
2. Build libsyscall (from XNU project)

### Environment Setup

```bash
export SDKROOT=$(xcrun --sdk macosx --show-sdk-path)
export ARCH_FLAGS="-arch arm64"
export XNU_HEADERS=/path/to/xnu/BUILD/dst/usr/include

export CFLAGS="${ARCH_FLAGS} -I${XNU_HEADERS} -DLIBC_ALIAS_C=1"
export LDFLAGS="${ARCH_FLAGS}"
```

### Building with Xcode

```bash
xcodebuild -project Libc.xcodeproj \
    -target Libc \
    -configuration Release \
    ARCHS=arm64 \
    VALID_ARCHS=arm64 \
    SDKROOT=macosx
```

### Manual Build

```bash
# Compile source files from each subdirectory
clang ${CFLAGS} -c gen/*.c
clang ${CFLAGS} -c stdio/*.c
clang ${CFLAGS} -c stdlib/*.c
clang ${CFLAGS} -c string/*.c
# ... continue for other directories

# Link into shared library
clang ${LDFLAGS} -dynamiclib -o libSystem.B.dylib *.o \
    -install_name /usr/lib/libSystem.B.dylib
```

## Patches for ARM64 (Raspberry Pi)

### 1. Disable arm64e Assembly

Many functions have arm64e optimized assembly. Fall back to C or arm64:

```c
// In arm64 assembly files
#if !defined(__ARM64E__)
// Use arm64 implementation
#endif
```

### 2. Configure for Embedded

```bash
export CFLAGS="${CFLAGS} -DCONFIG_EMBEDDED=1"
```

### 3. System Call Numbers

Verify system call numbers match your XNU build:

```c
// Check in xnu/bsd/kern/syscalls.master
// Ensure Libc's sys/syscall.h matches
```

## Key Components

### Standard I/O (stdio)

```c
// File operations
FILE *fopen(const char *path, const char *mode);
int fclose(FILE *stream);
size_t fread(void *ptr, size_t size, size_t nmemb, FILE *stream);
size_t fwrite(const void *ptr, size_t size, size_t nmemb, FILE *stream);

// Formatted I/O
int printf(const char *format, ...);
int fprintf(FILE *stream, const char *format, ...);
int scanf(const char *format, ...);
```

### Memory Allocation (stdlib)

```c
void *malloc(size_t size);
void *calloc(size_t count, size_t size);
void *realloc(void *ptr, size_t size);
void free(void *ptr);
```

### String Operations (string)

```c
char *strcpy(char *dst, const char *src);
int strcmp(const char *s1, const char *s2);
size_t strlen(const char *s);
void *memcpy(void *dst, const void *src, size_t n);
void *memset(void *b, int c, size_t len);
```

## Output Files

| File | Location | Description |
|------|----------|-------------|
| `libSystem.B.dylib` | `/usr/lib/` | Main system library |
| `libc.a` | `/usr/lib/` | Static library (optional) |
| `*.h` | `/usr/include/` | C headers |

## Headers Installation

```bash
# Core headers
mkdir -p /path/to/install/usr/include
cp -R include/* /path/to/install/usr/include/

# Architecture-specific
mkdir -p /path/to/install/usr/include/arm
cp -R arm/include/* /path/to/install/usr/include/arm/
```

## Verification

### Simple Test

```c
// test_libc.c
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int main() {
    // Test malloc
    char *buf = malloc(100);
    if (!buf) {
        fprintf(stderr, "malloc failed\n");
        return 1;
    }
    
    // Test string functions
    strcpy(buf, "Hello, Darwin Libc!");
    printf("%s\n", buf);
    printf("String length: %zu\n", strlen(buf));
    
    free(buf);
    return 0;
}
```

```bash
clang test_libc.c -o test_libc
./test_libc
```

## libSystem Components

On Darwin, `libSystem.B.dylib` is a combined library that re-exports:

| Library | Description |
|---------|-------------|
| `libsystem_c.dylib` | C library |
| `libsystem_m.dylib` | Math library |
| `libsystem_pthread.dylib` | POSIX threads |
| `libsystem_malloc.dylib` | Memory allocation |
| `libsystem_kernel.dylib` | System call stubs |
| `libdispatch.dylib` | Grand Central Dispatch |
| `libxpc.dylib` | XPC library |

## Known Issues

### 1. Missing System Calls

Some system calls may not exist in your XNU build:

```c
// Stub out or provide alternatives
#ifndef SYS_some_syscall
// Provide fallback implementation
#endif
```

### 2. TLS (Thread Local Storage)

Ensure the dynamic linker (dyld) supports `__thread`:

```c
__thread int thread_local_var;
```

### 3. Symbol Versioning

Darwin uses symbol versioning for compatibility:

```c
// Check for LIBC_ALIAS and symbol suffixes
```

## Building libpthread

libpthread is closely related and often built together:

```bash
# Download
curl -O https://opensource.apple.com/tarballs/libpthread/libpthread-454.120.2.tar.gz
tar xzf libpthread-454.120.2.tar.gz

# Build
cd libpthread-454.120.2
xcodebuild -target libpthread ARCHS=arm64
```

## References

- [Apple Open Source - Libc](https://opensource.apple.com/source/Libc/)
- [FreeBSD Libc](https://www.freebsd.org/cgi/man.cgi?libc) (Darwin Libc shares heritage)
- [POSIX Standard](https://pubs.opengroup.org/onlinepubs/9699919799/)

## Next Steps

After building Libc:

1. Build [libdispatch](libdispatch.md) 
2. Build [libxpc](libxpc.md)
3. Integrate into a minimal sysroot
