#!/bin/sh
# Set the iOS device name (Settings > General > About > Name) and drop MobileGestalt's cache so it is
# rebuilt from the device tree (/product product-name, see DEVICE_NAME in pi3-qemu-boot.sh), inside a
# qcow2 overlay of the iOS root; the base image is not touched. Needs docker and the pi-ios-root image.
#
#   tools/ios-root-set-name.sh BASE.qcow2 NEW.qcow2 "Raspberry Pi 3B" [QEMU_UTILS_ROOT]
#
# BASE.qcow2 is the overlay (or raw root) to build on; NEW.qcow2 is created on top of it. QEMU_UTILS_ROOT is
# where qemu-img lives if it is not installed (the directory that contains usr/bin/qemu-img).
set -eu
BASE=$(realpath "${1:?usage: $0 BASE.qcow2 NEW.qcow2 NAME}"); NEW=$(realpath -m "${2:?}"); NAME=${3:?}
QR=${4:-}
HERE=$(cd "$(dirname "$0")" && pwd)
if [ -n "$QR" ]; then QI="env LD_LIBRARY_PATH=$QR/usr/lib/x86_64-linux-gnu $QR/usr/bin/qemu-img"; else QI=qemu-img; fi
FMT=qcow2; case "$BASE" in *.img|*.raw) FMT=raw;; esac
rm -f "$NEW"
$QI create -q -f qcow2 -b "$BASE" -F "$FMT" "$NEW"
# derived image with qemu-nbd (the root volume is read through /dev/nbd0 and mounted as HFS+)
docker image inspect pi-ios-root-nbd >/dev/null 2>&1 || {
    printf 'FROM pi-ios-root\nRUN apt-get update -qq && apt-get install -y -qq qemu-utils && rm -rf /var/lib/apt/lists/*\n' |
        docker build -q -t pi-ios-root-nbd -
}
docker run --rm --privileged -e NEW="$NEW" -e NAME="$NAME" -v /lib/modules:/lib/modules:ro \
    -v "$(dirname "$NEW")":"$(dirname "$NEW")" -v "$(dirname "$BASE")":"$(dirname "$BASE")" \
    -v "$HERE/ios-root-set-name.py":/set-name.py:ro pi-ios-root-nbd sh -c '
set -e
modprobe nbd max_part=0
qemu-nbd -c /dev/nbd0 -f qcow2 "$NEW"
sleep 1
# the guest never unmounts: replay its journal with fsck, then clear the journaled flag in both volume
# headers, because Linux only mounts non-journaled HFS+ read-write
fsck.hfsplus -f -y /dev/nbd0 || true
python3 - <<PY
import struct
f = open("/dev/nbd0", "r+b")
size = f.seek(0, 2)
for off in (1024, size - 1024):
    f.seek(off); h = bytearray(f.read(512))
    assert h[:2] in (b"H+", b"HX"), h[:2]
    attrs = struct.unpack(">I", h[4:8])[0]
    h[4:8] = struct.pack(">I", attrs & ~0x2000)
    f.seek(off); f.write(h)
f.close()
PY
mkdir -p /m && mount -t hfsplus -o rw /dev/nbd0 /m
python3 /set-name.py /m "$NAME" || rc=$?
umount /m; qemu-nbd -d /dev/nbd0 >/dev/null
exit ${rc:-0}'
