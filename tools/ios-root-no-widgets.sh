#!/bin/sh
# Remove the widget stacks from the home screen layout (SpringBoard's IconState.plist), inside a qcow2 overlay of
# the iOS root. The default layout holds Weather, Calendar, Maps, Notes, News ... widgets, but those apps are not in
# the root image (only the services and a handful of apps are), so the widgets stay "Waiting...".
#
#   tools/ios-root-no-widgets.sh BASE.qcow2 NEW.qcow2 [QEMU_UTILS_ROOT]
#
# BASE.qcow2 may hold a journaled HFS+ volume: the journal is replayed with fsck and the journaled flag cleared
# (Linux mounts HFS+ read-write only without a journal), as in ios-root-set-name.sh. The base is not touched.
set -eu
BASE=$(realpath "${1:?usage: $0 BASE.qcow2 NEW.qcow2 [QEMU_UTILS_ROOT]}"); NEW=$(realpath -m "${2:?}"); QR=${3:-}
if [ -n "$QR" ]; then QI="env LD_LIBRARY_PATH=$QR/usr/lib/x86_64-linux-gnu $QR/usr/bin/qemu-img"; else QI=qemu-img; fi
rm -f "$NEW"
$QI create -q -f qcow2 -b "$BASE" -F qcow2 "$NEW"
docker image inspect pi-ios-root-nbd >/dev/null 2>&1 || {
    printf 'FROM pi-ios-root\nRUN apt-get update -qq && apt-get install -y -qq qemu-utils && rm -rf /var/lib/apt/lists/*\n' |
        docker build -q -t pi-ios-root-nbd -
}
docker run --rm --privileged -e NEW="$NEW" -v /lib/modules:/lib/modules:ro \
    -v "$(dirname "$NEW")":"$(dirname "$NEW")" -v "$(dirname "$BASE")":"$(dirname "$BASE")" pi-ios-root-nbd sh -c '
set -e
modprobe nbd max_part=0
qemu-nbd -c /dev/nbd0 -f qcow2 "$NEW"
sleep 1
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
python3 - <<PY
import plistlib
p = "/m/private/var/mobile/Library/SpringBoard/IconState.plist"
raw = open(p, "rb").read()
fmt = plistlib.FMT_BINARY if raw[:6] == b"bplist" else plistlib.FMT_XML
d = plistlib.loads(raw)
removed = 0
for page in d.get("iconLists", []):
    keep = [i for i in page if not isinstance(i, dict)]
    removed += len(page) - len(keep)
    page[:] = keep
open(p, "wb").write(plistlib.dumps(d, fmt=fmt))
print("IconState.plist: removed", removed, "widget stacks")
PY
umount /m; qemu-nbd -d /dev/nbd0 >/dev/null'
