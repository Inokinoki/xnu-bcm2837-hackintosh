#!/bin/sh
# Build the iOS 16 HFS+ root image in a privileged docker container.
#
#   tools/mkios-root.sh DIR OUT.img [SIZE]
#
# DIR holds the three IPSW disk images (OS 087-86698-044.dmg, SystemOS 087-86593-047.dmg,
# AppOS 087-86715-047.dmg for iPhone10,3 20H392); OUT.img lands next to DIR's parent
# argument path. SIZE defaults to 16G (a power of two, so QEMU accepts it as an SD card).
# Needs docker and the host kernel's hfsplus module. Keep the output out of git.
set -eu
DIR=$(realpath "${1:?usage: $0 DIR OUT.img [SIZE]}")
OUT=${2:?usage: $0 DIR OUT.img [SIZE]}
SIZE=${3:-16G}
HERE=$(cd "$(dirname "$0")" && pwd)
OUTDIR=$(realpath "$(dirname "$OUT")")
docker build -q -t pi-ios-root "$HERE/ios-root-docker" >/dev/null
docker run --rm --privileged -v /lib/modules:/lib/modules:ro \
    -v "$DIR":/ipsw:ro -v "$OUTDIR":/out -v "$HERE/ios-root-docker/mkios-root.sh":/mkios-root.sh:ro \
    pi-ios-root /mkios-root.sh /ipsw/087-86698-044.dmg /ipsw/087-86593-047.dmg /ipsw/087-86715-047.dmg \
    "/out/$(basename "$OUT")" "$SIZE"
