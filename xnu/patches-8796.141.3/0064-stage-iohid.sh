#!/bin/bash
# Stage the IOHIDFamily sources the iOS 16 userland's HID event system talks to
# (IOHIDEventServiceUserClient, IOHIDEventServiceQueue, IOHIDEvent and their headers) into
# iokit/Kernel/arm/hid. IOHIDFamily is not part of xnu. dxb runs patches/*.sh from the XNU
# source root before applying *.patch; 0064-bcm2837-hid-adapt.patch makes them build in the kernel.
set -euo pipefail

[[ "${MACHINE_CONFIG:-}" == BCM2837 ]] || exit 0
[[ -f iokit/conf/files.arm64 ]] || exit 1

# IOHIDFamily-1915.140.3 (the version the iOS 16.7 userland ships), pinned by commit.
iohid_sha=2365347f5147a1e2a46de21acd08d27fe0906e85
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
git init -q "$tmp"
git -C "$tmp" fetch -q --depth 1 https://github.com/apple-oss-distributions/IOHIDFamily "$iohid_sha"
git -C "$tmp" checkout -q FETCH_HEAD
[[ "$(git -C "$tmp" rev-parse HEAD)" == "$iohid_sha" ]]

target=iokit/Kernel/arm/hid
[[ ! -e $target ]] || { echo "refusing to overwrite $target" >&2; exit 1; }
mkdir -p "$target"
for f in AppleHIDUsageTables.h IOHIDDebug.h IOHIDDeviceKeys.h IOHIDDeviceTypes.h IOHIDEvent.cpp \
    IOHIDEvent.h IOHIDEventData.h IOHIDEventFieldDefs.h IOHIDEventMacroDefs.h IOHIDEventServiceKeys.h \
    IOHIDEventServiceKeys_Private.h IOHIDEventServiceQueue.cpp IOHIDEventServiceQueue.h \
    IOHIDEventServiceTypes.h IOHIDEventServiceUserClient.cpp IOHIDEventServiceUserClient.h \
    IOHIDEventStructDefs.h IOHIDEventTypes.h IOHIDFamilyTrace.h IOHIDKeys.h IOHIDPrivateKeys.h \
    IOHIDProperties.h IOHIDUsageTables.h; do
    cp "$tmp/IOHIDFamily/$f" "$target/$f"
done
for f in IOHIDParameter.h IOHIDShared.h IOHIDTypes.h IOLLEvent.h ev_keymap.h; do
    cp "$tmp/IOHIDSystem/IOKit/hidsystem/$f" "$target/$f"
done
echo "Staged IOHIDFamily-1915.140.3 ($iohid_sha) for BCM2837"
