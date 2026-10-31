#!/bin/sh
# Run tools/dsc-sym.py in the pi-ios-root container with the iOS root image mounted read-only.
#
#   tools/dsc-sym.sh ROOT.img SLIDE --log FILE        (or: ROOT.img SLIDE ADDR...)
set -eu
IMG=$(realpath "${1:?usage: $0 ROOT.img SLIDE (--log FILE | ADDR...)}"); SLIDE=${2:?}; shift 2
HERE=$(cd "$(dirname "$0")" && pwd)
ARGS=""
MNT=""
if [ "${1:-}" = "--log" ]; then MNT="-v $(realpath "$2"):/log.txt:ro"; ARGS="--log /log.txt"; else ARGS="$*"; fi
docker run --rm --privileged -v /lib/modules:/lib/modules:ro -v "$IMG":/root.img:ro $MNT \
    -v "$HERE/dsc-sym.py":/dsc-sym.py:ro pi-ios-root sh -c "modprobe hfsplus; mkdir -p /m; mount -t hfsplus -o ro,loop,force /root.img /m && python3 /dsc-sym.py /m/System/Library/Caches/com.apple.dyld $SLIDE $ARGS; umount /m"
