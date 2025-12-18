# Building shell_cmds for ARM64

shell_cmds contains essential shell utilities that are fundamental to any Unix-like operating system. These are the basic commands users interact with daily.

## Overview

shell_cmds provides core shell utilities including:

- `echo` - Display text
- `pwd` - Print working directory
- `test` / `[` - Condition evaluation
- `expr` - Expression evaluation
- `basename` / `dirname` - Path manipulation
- `env` - Environment manipulation
- `false` / `true` - Return exit codes
- `hexdump` - Display file in hex
- `hostname` - Show/set hostname
- `id` - Display user identity
- `jot` - Generate data sequences
- `kill` - Send signals to processes
- `lastcomm` - Show last commands
- `locate` - Find files by name
- `logname` - Display login name
- `nice` / `renice` - Process priority
- `nohup` - Run immune to hangups
- `path_helper` - Path setup helper
- `printenv` - Print environment
- `script` - Record terminal session
- `seq` - Print sequences
- `shlock` - Create lock files
- `sleep` - Delay execution
- `su` - Substitute user
- `tee` - Pipe fitting
- `time` - Time command execution
- `uname` - System information
- `users` - Show logged in users
- `w` / `who` - Who is logged in
- `whereis` - Locate programs
- `xargs` - Build argument lists
- `yes` - Output repeated string

## Source

Download from Apple Open Source:
- **URL**: https://opensource.apple.com/source/shell_cmds/
- **Recommended Version**: shell_cmds-216.60.1 or latest available

```bash
# Find latest version
curl -s https://opensource.apple.com/tarballs/shell_cmds/ | grep -o 'shell_cmds-[0-9.]*\.tar\.gz' | sort -V | tail -1

# Download
curl -O https://opensource.apple.com/tarballs/shell_cmds/shell_cmds-216.60.1.tar.gz
tar xzf shell_cmds-216.60.1.tar.gz
cd shell_cmds-216.60.1
```

## Dependencies

| Dependency | Purpose | Required |
|------------|---------|----------|
| [Libc](Libc.md) | C standard library | ✅ Yes |
| XNU Headers | System calls | ✅ Yes |

## Project Structure

```
shell_cmds/
├── echo/
│   └── echo.c
├── pwd/
│   └── pwd.c
├── hostname/
│   └── hostname.c
├── kill/
│   └── kill.c
├── sleep/
│   └── sleep.c
├── uname/
│   └── uname.c
├── xargs/
│   └── xargs.c
└── ... (other commands)
```

## Build Instructions

### Using Xcode

```bash
xcodebuild -project shell_cmds.xcodeproj \
    -alltargets \
    -configuration Release \
    ARCHS=arm64 \
    SDKROOT=macosx \
    DSTROOT=/path/to/install
```

### Manual Build (Individual Commands)

Most commands are simple single-file programs:

```bash
# Set up environment
export CC=clang
export CFLAGS="-arch arm64 -isysroot $(xcrun --sdk macosx --show-sdk-path)"
export LDFLAGS="-arch arm64"

# Build individual commands
clang ${CFLAGS} -o echo echo/echo.c
clang ${CFLAGS} -o pwd pwd/pwd.c
clang ${CFLAGS} -o hostname hostname/hostname.c
clang ${CFLAGS} -o sleep sleep/sleep.c
clang ${CFLAGS} -o uname uname/uname.c
```

### Batch Build Script

```bash
#!/bin/bash
CFLAGS="-arch arm64 -O2"
DESTDIR="${DESTDIR:-/usr/local/bin}"

for cmd in echo pwd hostname kill sleep true false test env basename dirname; do
    if [ -d "$cmd" ] && [ -f "$cmd/$cmd.c" ]; then
        echo "Building $cmd..."
        clang ${CFLAGS} -o "${DESTDIR}/$cmd" "$cmd/$cmd.c"
    fi
done
```

## Output Binaries

| Binary | Location | Description |
|--------|----------|-------------|
| Various | `/bin/` | Core utilities |
| Various | `/usr/bin/` | Additional utilities |

## Patches for ARM64

shell_cmds are generally portable and require minimal patching:

```c
// Ensure proper architecture detection
#if defined(__arm64__) || defined(__aarch64__)
// ARM64 specific code if needed
#endif
```

## Verification

```bash
# Test built commands
./echo "Hello, Darwin!"
./pwd
./hostname
./uname -a
./sleep 1 && echo "Sleep works"
```

## References

- [Apple Open Source - shell_cmds](https://opensource.apple.com/source/shell_cmds/)
- [FreeBSD shell utilities](https://www.freebsd.org/cgi/man.cgi) (shared heritage)

## Next Steps

After building shell_cmds:

1. Build [file_cmds](file_cmds.md) for file operations
2. Build [system_cmds](system_cmds.md) for system utilities
3. Install to target sysroot
