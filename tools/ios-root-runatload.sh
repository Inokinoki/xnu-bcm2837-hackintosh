#!/bin/sh
# Make launchd start on-demand daemons at boot (RunAtLoad=true in their plists), inside a qcow2 overlay of the
# iOS root (see ios-root-set-name.sh for how the volume is mounted; the base image is not touched).
#
#   tools/ios-root-runatload.sh BASE.qcow2 NEW.qcow2 LABEL... [-- QEMU_UTILS_ROOT]
#
# e.g. LABEL=com.apple.chronod (the WidgetKit daemon; nothing ever looks its service up, widgets stay "Waiting...").
set -eu
BASE=$(realpath "${1:?usage: $0 BASE.qcow2 NEW.qcow2 LABEL... [-- QEMU_UTILS_ROOT]}"); NEW=$(realpath -m "${2:?}"); shift 2
LABELS=""; QR=""
while [ $# -gt 0 ]; do
    if [ "$1" = "--" ]; then QR=${2:-}; break; fi
    LABELS="$LABELS $1"; shift
done
if [ -n "$QR" ]; then QI="env LD_LIBRARY_PATH=$QR/usr/lib/x86_64-linux-gnu $QR/usr/bin/qemu-img"; else QI=qemu-img; fi
rm -f "$NEW"
$QI create -q -f qcow2 -b "$BASE" -F qcow2 "$NEW"
docker image inspect pi-ios-root-nbd >/dev/null 2>&1 || {
    printf 'FROM pi-ios-root\nRUN apt-get update -qq && apt-get install -y -qq qemu-utils && rm -rf /var/lib/apt/lists/*\n' |
        docker build -q -t pi-ios-root-nbd -
}
docker run --rm --privileged -e NEW="$NEW" -e LABELS="$LABELS" -v /lib/modules:/lib/modules:ro \
    -v "$(dirname "$NEW")":"$(dirname "$NEW")" -v "$(dirname "$BASE")":"$(dirname "$BASE")" pi-ios-root-nbd sh -c '
set -e
modprobe nbd max_part=0
qemu-nbd -c /dev/nbd0 -f qcow2 "$NEW"
sleep 1
mkdir -p /m && mount -t hfsplus -o rw /dev/nbd0 /m
python3 - <<PY
import glob, os, plistlib
labels = os.environ["LABELS"].split()
for d in ("/m/System/Library/LaunchDaemons", "/m/System/Library/LaunchAgents", "/m/Library/LaunchDaemons"):
    for p in glob.glob(d + "/*.plist"):
        raw = open(p, "rb").read()
        try:
            pl = plistlib.loads(raw)
        except Exception:
            continue
        if pl.get("Label") in labels:
            fmt = plistlib.FMT_BINARY if raw[:6] == b"bplist" else plistlib.FMT_XML
            pl["RunAtLoad"] = True
            open(p, "wb").write(plistlib.dumps(pl, fmt=fmt))
            print("RunAtLoad:", pl["Label"], os.path.relpath(p, "/m"))
PY
umount /m; qemu-nbd -d /dev/nbd0 >/dev/null'
