# Building bash for ARM64

Bash (Bourne Again Shell) is the default shell for many Unix-like systems and an essential component for a usable Darwin system.

## Overview

Bash provides:

- Interactive command-line shell
- Shell scripting language
- Job control
- Command history
- Tab completion
- Aliases and functions
- POSIX sh compatibility

## Source

Download from Apple Open Source:
- **URL**: https://opensource.apple.com/source/bash/
- **Recommended Version**: bash-130.40.1 or latest

```bash
curl -O https://opensource.apple.com/tarballs/bash/bash-130.40.1.tar.gz
tar xzf bash-130.40.1.tar.gz
cd bash-130.40.1
```

Alternatively, use upstream GNU Bash:
- **URL**: https://ftp.gnu.org/gnu/bash/

## Dependencies

| Dependency | Purpose | Required |
|------------|---------|----------|
| [Libc](Libc.md) | C standard library | ✅ Yes |
| [ncurses](https://opensource.apple.com/source/ncurses/) | Terminal handling | ✅ Yes |
| [libedit](https://opensource.apple.com/source/libedit/) | Line editing | Optional |

## Build Instructions

### Using Apple Source

```bash
cd bash-130.40.1/bash-5.x

# Configure
./configure \
    --host=aarch64-apple-darwin \
    --prefix=/usr \
    --without-bash-malloc \
    --enable-static-link

# Build
make -j$(sysctl -n hw.ncpu)

# Install
make install DESTDIR=/path/to/sysroot
```

### Using Xcode (if xcodeproj available)

```bash
xcodebuild -project bash.xcodeproj \
    -alltargets \
    -configuration Release \
    ARCHS=arm64 \
    SDKROOT=macosx
```

### Cross-compilation for ARM64

```bash
export CC="clang -arch arm64"
export CFLAGS="-arch arm64 -isysroot $(xcrun --sdk macosx --show-sdk-path)"
export LDFLAGS="-arch arm64"

./configure \
    --host=aarch64-apple-darwin \
    --prefix=/usr

make -j$(sysctl -n hw.ncpu)
```

## Configuration Files

Bash reads configuration from:

| File | Purpose |
|------|---------|
| `/etc/profile` | System-wide login shell config |
| `/etc/bashrc` | System-wide interactive shell config |
| `~/.bash_profile` | User login shell config |
| `~/.bashrc` | User interactive shell config |
| `~/.bash_logout` | User logout script |

### Minimal /etc/profile

```bash
# /etc/profile - System-wide profile

# Set PATH
export PATH="/usr/bin:/bin:/usr/sbin:/sbin"

# Set prompt
export PS1='\u@\h:\w\$ '

# Source global bashrc
if [ -f /etc/bashrc ]; then
    . /etc/bashrc
fi
```

### Minimal /etc/bashrc

```bash
# /etc/bashrc - System-wide bashrc

# Set umask
umask 022

# Enable color ls
alias ls='ls -G'

# History settings
export HISTSIZE=1000
export HISTFILESIZE=2000
```

## Output Binaries

| Binary | Location | Description |
|--------|----------|-------------|
| `bash` | `/bin/bash` | Bash shell |
| `sh` | `/bin/sh` | Symlink to bash (or POSIX mode) |

## Shell Initialization

For launchd to start user sessions with bash:

```xml
<!-- /System/Library/LaunchDaemons/com.apple.getty.plist -->
<dict>
    <key>Label</key>
    <string>com.apple.getty</string>
    <key>ProgramArguments</key>
    <array>
        <string>/usr/libexec/getty</string>
        <string>std.9600</string>
        <string>console</string>
    </array>
</dict>
```

## Patches for ARM64

### Disable bash malloc

Bash includes its own malloc implementation that may conflict:

```bash
./configure --without-bash-malloc
```

### Signal handling

Ensure proper signal handling for ARM64:

```c
#if defined(__arm64__) || defined(__aarch64__)
// ARM64 signal handling adjustments if needed
#endif
```

## Verification

```bash
# Check version
./bash --version

# Test basic functionality
./bash -c 'echo "Hello from bash"'

# Test scripting
./bash -c 'for i in 1 2 3; do echo $i; done'

# Test job control
./bash -c 'sleep 10 & jobs'
```

## References

- [Apple Open Source - bash](https://opensource.apple.com/source/bash/)
- [GNU Bash Manual](https://www.gnu.org/software/bash/manual/)
- [Bash Reference Manual](https://www.gnu.org/software/bash/manual/bash.html)

## See Also

- [zsh](https://opensource.apple.com/source/zsh/) - Z Shell (alternative)
- [tcsh](https://opensource.apple.com/source/tcsh/) - TENEX C Shell
- [shell_cmds](shell_cmds.md) - Shell utilities
