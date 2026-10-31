#!/bin/bash
# Stage Apple's open source HFS for the BCM2837 built-in filesystem (bsd/sweet_hfs).
# dxb runs patches/*.sh from the XNU source root before applying *.patch.
set -euo pipefail

[[ "${MACHINE_CONFIG:-}" == BCM2837 ]] || exit 0
[[ "${MACOS_VERSION:-}" == 13.5 ]] || {
    echo 'BCM2837 HFS integration requires xnu-8796.141.3 (macOS 13.5)' >&2
    exit 1
}
[[ -f bsd/kern/bsd_init.c ]] || exit 1

# hfs-627.100.6 is paired with xnu-8796.141.3 in Apple's macos-135
# release.json. Fetch the immutable commit, never a moving branch/tag.
hfs_sha=31d5ec238dfab485e78a9a30b8b92d13e8914f03
hfs_tmp=$(mktemp -d)
trap 'rm -rf "$hfs_tmp"' EXIT
git init -q "$hfs_tmp"
git -C "$hfs_tmp" fetch -q --depth 1 \
    https://github.com/apple-oss-distributions/hfs "$hfs_sha"
git -C "$hfs_tmp" checkout -q FETCH_HEAD
[[ "$(git -C "$hfs_tmp" rev-parse HEAD)" == "$hfs_sha" ]]

python3 - "$hfs_tmp" <<'PY'
from pathlib import Path
import shutil
import sys

source = Path(sys.argv[1])
target = Path('bsd/sweet_hfs')
if target.exists():
    raise SystemExit(f'refusing to overwrite existing HFS sources: {target}')
# Preserve upstream copyright/license headers; no downloaded sources in git.
for directory in ('core', 'hfs_encodings'):
    shutil.copytree(source / directory, target / directory)

# BCM2837 has no AppleKeyStore (content protection is not built, see
# sweet_hfs_compat.h); its header is only needed for the key-wrapping API.
path = target / 'core' / 'hfs_iokit.h'
text = path.read_text()
include = '#include <AppleKeyStore/AppleKeyStoreFSServices.h>\n'
first = 'int hfs_unwrap_key('
end = '__END_DECLS'
if text.count(include) != 1 or text.count(first) != 1 or text.count(end) != 1:
    raise SystemExit(f'HFS source changed: {path}')
text = text.replace(include, '#if CONFIG_PROTECT\n' + include + '#endif\n')
i, j = text.index(first), text.index(end)
text = text[:i] + '#if CONFIG_PROTECT\n' + text[i:j].rstrip('\n') + '\n#endif\n\n' + text[j:]
path.write_text(text)

# kext-config.h picks the iOS feature set (CONFIG_PROTECT, no quota/named streams) when the SDK's
# TargetConditionals.h says TARGET_OS_IPHONE, which an iPhoneOS-platform kernel build does. BCM2837 always
# wants the OS X set (no AppleKeyStore), whatever platform the kernel is built for.
path = target / 'core' / 'kext-config.h'
text = path.read_text()
ios = '#if (TARGET_OS_IPHONE && !TARGET_OS_SIMULATOR) // iOS (real hardware)'
if text.count(ios) != 1:
    raise SystemExit(f'HFS source changed: {path}')
path.write_text(text.replace(ios, '#if 0 // BCM2837: always the OS X feature set'))
PY

# Kernel builds use -nostdinc; HFS's kext-config.h needs the SDK's target macros.
hfs_sdk=$(xcrun --sdk macosx --show-sdk-path)
cp "$hfs_sdk/usr/include/TargetConditionals.h" bsd/sweet_hfs/
# An iPhoneOS-platform kernel build makes the SDK header say TARGET_OS_IPHONE (HFS then drops its
# encodings, quota, named streams, ...); BCM2837 always wants the OS X view of HFS.
cat >> bsd/sweet_hfs/TargetConditionals.h <<'EOF'

/* BCM2837: HFS is always built with the OS X feature set, whatever platform the kernel targets. */
#undef TARGET_OS_OSX
#undef TARGET_OS_MAC
#undef TARGET_OS_IPHONE
#undef TARGET_OS_IOS
#undef TARGET_OS_SIMULATOR
#undef TARGET_OS_EMBEDDED
#undef TARGET_OS_MACCATALYST
#undef TARGET_IPHONE_SIMULATOR
#define TARGET_OS_OSX 1
#define TARGET_OS_MAC 1
#define TARGET_OS_IPHONE 0
#define TARGET_OS_IOS 0
#define TARGET_OS_SIMULATOR 0
#define TARGET_OS_EMBEDDED 0
#define TARGET_OS_MACCATALYST 0
#define TARGET_IPHONE_SIMULATOR 0
EOF
echo "Staged hfs-627.100.6 ($hfs_sha) for BCM2837"
