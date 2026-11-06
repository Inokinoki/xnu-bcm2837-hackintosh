#!/bin/sh
# Put the removable system apps (Weather, Calendar, Maps, Notes, ... 32 of them, about 500 MB) where the other system
# apps live. The IPSW stages them in /private/var/staged_system_apps and a device installs them at first boot; here
# nothing does, so the home screen widgets for them stayed "Waiting...". Copying them into /Applications lets
# LaunchServices register them on the guest's first boot. Work on a root that has not booted yet (an overlay of the
# pristine image), or delete the LaunchServices database first.
#
#   tools/ios-root-install-apps.sh BASE NEW.qcow2 [QEMU_UTILS_ROOT]
#
# BASE is the raw image or a qcow2; NEW.qcow2 is created on top of it. The base is not touched.
set -eu
BASE=$(realpath "${1:?usage: $0 BASE NEW.qcow2 [QEMU_UTILS_ROOT]}"); NEW=$(realpath -m "${2:?}"); QR=${3:-}
if [ -n "$QR" ]; then QI="env LD_LIBRARY_PATH=$QR/usr/lib/x86_64-linux-gnu $QR/usr/bin/qemu-img"; else QI=qemu-img; fi
FMT=qcow2; case "$BASE" in *.img|*.raw) FMT=raw;; esac
rm -f "$NEW"
$QI create -q -f qcow2 -b "$BASE" -F "$FMT" "$NEW"
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
n=0
for a in /m/private/var/staged_system_apps/*.app; do
    b=$(basename "$a")
    if [ -e "/m/Applications/$b" ]; then echo "skip $b (already in /Applications)"; continue; fi
    mkdir -p "/m/Applications/$b"
    rsync -aH --numeric-ids "$a/" "/m/Applications/$b/"
    n=$((n + 1))
done
echo "installed $n apps into /Applications"
df -h /m | tail -1
umount /m; qemu-nbd -d /dev/nbd0 >/dev/null'
