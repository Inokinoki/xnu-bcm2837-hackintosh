# Building libxpc for ARM64

libxpc is Apple's inter-process communication (IPC) library that provides structured data transport between processes. It is a core dependency for launchd and many Darwin system services.

## Overview

XPC provides:

- Type-safe structured message passing
- Connection-oriented IPC
- Launchd integration for on-demand service activation
- Automatic connection management
- Security through sandboxing integration

## Source

Download from Apple Open Source:
- **Latest**: https://opensource.apple.com/source/libxpc/
- **Recommended Version**: libxpc-1336.261.2 (macOS 11.x compatible)

```bash
curl -O https://opensource.apple.com/tarballs/libxpc/libxpc-1336.261.2.tar.gz
tar xzf libxpc-1336.261.2.tar.gz
cd libxpc-1336.261.2
```

**Note**: XPC source may be partially available. Some implementations are in the launchd project.

## Dependencies

| Dependency | Purpose | Required |
|------------|---------|----------|
| [libdispatch](libdispatch.md) | Async event handling | ✅ Yes |
| [Libc](Libc.md) | C standard library | ✅ Yes |
| XNU Headers | Mach ports, kernel interfaces | ✅ Yes |
| Mach Services | Underlying transport | ✅ Yes |

## Architecture

XPC is built on top of Mach messaging and provides a higher-level abstraction:

```
┌─────────────────┐     ┌─────────────────┐
│   Client App    │     │   XPC Service   │
├─────────────────┤     ├─────────────────┤
│   libxpc.dylib  │◄───►│   libxpc.dylib  │
├─────────────────┤     ├─────────────────┤
│   Mach Ports    │◄───►│   Mach Ports    │
├─────────────────┤     ├─────────────────┤
│   XNU Kernel    │     │   XNU Kernel    │
└─────────────────┘     └─────────────────┘
```

## Project Structure

```
libxpc/
├── src/
│   ├── connection.c         # XPC connections
│   ├── dictionary.c         # XPC dictionary type
│   ├── array.c              # XPC array type
│   ├── data.c               # XPC data types
│   ├── activity.c           # XPC activity
│   └── ...
├── xpc/
│   ├── xpc.h                # Main public header
│   ├── connection.h         # Connection APIs
│   └── ...
├── private/
│   └── ...                  # Private headers
└── launchd/
    └── ...                  # launchd integration
```

## XPC Types

XPC provides these fundamental types:

| Type | Description |
|------|-------------|
| `xpc_object_t` | Base type for all XPC objects |
| `xpc_connection_t` | Connection to an XPC service |
| `xpc_dictionary_t` | Key-value dictionary |
| `xpc_array_t` | Ordered array |
| `xpc_string_t` | UTF-8 string |
| `xpc_data_t` | Binary data |
| `xpc_int64_t` | 64-bit signed integer |
| `xpc_uint64_t` | 64-bit unsigned integer |
| `xpc_bool_t` | Boolean value |
| `xpc_fd_t` | File descriptor |

## Build Instructions

### Environment Setup

```bash
export SDKROOT=$(xcrun --sdk macosx --show-sdk-path)
export ARCH_FLAGS="-arch arm64"

# Dependencies
export LIBDISPATCH_PATH=/path/to/libdispatch/install
export XNU_HEADERS=/path/to/xnu/BUILD/dst/usr/include

export CFLAGS="${ARCH_FLAGS} -I${XNU_HEADERS} -I${LIBDISPATCH_PATH}/include"
export LDFLAGS="-L${LIBDISPATCH_PATH}/lib -ldispatch"
```

### Building with Xcode

```bash
xcodebuild -project libxpc.xcodeproj \
    -target libxpc \
    -configuration Release \
    ARCHS=arm64 \
    VALID_ARCHS=arm64 \
    HEADER_SEARCH_PATHS="${XNU_HEADERS} ${LIBDISPATCH_PATH}/include"
```

### Manual Build

```bash
# Compile source files
clang ${CFLAGS} -c src/connection.c -o connection.o
clang ${CFLAGS} -c src/dictionary.c -o dictionary.o
clang ${CFLAGS} -c src/array.c -o array.o
# ... compile remaining files

# Create dynamic library
clang ${LDFLAGS} -dynamiclib -o libxpc.dylib *.o \
    -install_name /usr/lib/system/libxpc.dylib \
    -ldispatch
```

## Patches for ARM64 (Raspberry Pi)

### 1. Disable arm64e Features

```c
// Remove PAC-related code
#if defined(__arm64__) && !defined(__ARM64E__)
#undef XPC_USE_PAC
#endif
```

### 2. Mach Port Bootstrap

Ensure proper Mach bootstrap integration:

```c
// XPC relies on launchd for service lookup
// May need to implement minimal bootstrap for testing
```

### 3. Embedded Configuration

```bash
# Add to CFLAGS
-DCONFIG_EMBEDDED=1
-DXPC_BUILDING_XPC=1
```

## Key APIs

### Creating XPC Objects

```c
#include <xpc/xpc.h>

// Create a dictionary
xpc_object_t dict = xpc_dictionary_create(NULL, NULL, 0);
xpc_dictionary_set_string(dict, "key", "value");
xpc_dictionary_set_int64(dict, "count", 42);

// Create an array
xpc_object_t array = xpc_array_create(NULL, 0);
xpc_array_append_value(array, xpc_string_create("item"));
```

### Creating Connections

```c
#include <xpc/xpc.h>

// Create connection to a service
xpc_connection_t conn = xpc_connection_create_mach_service(
    "com.example.service",
    NULL,
    XPC_CONNECTION_MACH_SERVICE_PRIVILEGED
);

// Set event handler
xpc_connection_set_event_handler(conn, ^(xpc_object_t event) {
    if (xpc_get_type(event) == XPC_TYPE_ERROR) {
        // Handle error
    } else {
        // Handle message
    }
});

// Activate connection
xpc_connection_resume(conn);

// Send message
xpc_object_t message = xpc_dictionary_create(NULL, NULL, 0);
xpc_dictionary_set_string(message, "command", "hello");
xpc_connection_send_message(conn, message);
```

### XPC Service Handler

```c
#include <xpc/xpc.h>

int main(int argc, const char *argv[]) {
    xpc_main(^(xpc_connection_t peer) {
        // Handle new connection
        xpc_connection_set_event_handler(peer, ^(xpc_object_t event) {
            if (xpc_get_type(event) == XPC_TYPE_DICTIONARY) {
                // Handle request
                const char *cmd = xpc_dictionary_get_string(event, "command");
                
                // Send reply
                xpc_object_t reply = xpc_dictionary_create_reply(event);
                xpc_dictionary_set_string(reply, "result", "success");
                xpc_connection_send_message(peer, reply);
            }
        });
        xpc_connection_resume(peer);
    });
    
    return 0;
}
```

## Output Files

| File | Location | Description |
|------|----------|-------------|
| `libxpc.dylib` | `/usr/lib/system/` | Main shared library |
| `xpc/*.h` | `/usr/include/xpc/` | Public headers |

## Headers Installation

```bash
mkdir -p /path/to/install/usr/include/xpc
cp xpc/*.h /path/to/install/usr/include/xpc/
```

## Verification

### Simple Test

```c
// test_xpc.c
#include <xpc/xpc.h>
#include <stdio.h>

int main() {
    // Create and inspect XPC objects
    xpc_object_t dict = xpc_dictionary_create(NULL, NULL, 0);
    xpc_dictionary_set_string(dict, "hello", "world");
    xpc_dictionary_set_int64(dict, "number", 42);
    
    // Print description
    char *desc = xpc_copy_description(dict);
    printf("XPC Dictionary: %s\n", desc);
    free(desc);
    
    xpc_release(dict);
    return 0;
}
```

```bash
clang test_xpc.c -lxpc -ldispatch -o test_xpc
./test_xpc
```

## Integration with launchd

XPC and launchd are tightly integrated:

1. **Service Registration**: Services register with launchd via plist
2. **On-Demand Launch**: launchd starts services when first XPC connection arrives
3. **Service Discovery**: Clients look up services through launchd's Mach bootstrap
4. **Connection Management**: launchd monitors and manages service lifecycle

### Service plist for XPC

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.example.xpcservice</string>
    <key>MachServices</key>
    <dict>
        <key>com.example.xpcservice</key>
        <true/>
    </dict>
    <key>ProgramArguments</key>
    <array>
        <string>/usr/libexec/xpcservice</string>
    </array>
</dict>
</plist>
```

## Known Issues

### 1. Bootstrap Port

XPC needs the Mach bootstrap port from launchd. For standalone testing:

```c
// May need to set up minimal bootstrap
#include <mach/mach.h>
// Use task_get_bootstrap_port()
```

### 2. Code Signing

XPC enforces code signing by default. May need to disable for development:

```c
#define XPC_SKIP_CODESIGN_CHECK 1
```

### 3. Sandbox Integration

Sandbox features require additional kernel support:

```c
#define XPC_USE_SANDBOX 0  // Disable for initial port
```

## References

- [XPC Services - Apple Developer](https://developer.apple.com/library/archive/documentation/MacOSX/Conceptual/BPSystemStartup/Chapters/CreatingXPCServices.html)
- [Daemons and Services Programming Guide](https://developer.apple.com/library/archive/documentation/MacOSX/Conceptual/BPSystemStartup/Chapters/Introduction.html)
- [Apple Open Source - libxpc](https://opensource.apple.com/source/libxpc/)

## Next Steps

After building libxpc:

1. Build [launchd](launchd.md) (the final target)
2. Test XPC communication between processes
3. Create sample XPC services
