#!/bin/sh
# Build the test PID 1 (tools/pi-init.S) as a static, ad-hoc signed arm64 Mach-O.
#
#   [CC=aarch64-linux-gnu-gcc] [OBJCOPY=aarch64-linux-gnu-objcopy] tools/mkpi-init.sh OUT
#
# mockfs serves a RAM disk that is itself a Mach-O as /sbin/launchd, so this
# image is a complete root: RAMDISK=OUT tools/pi3-qemu-boot.sh KERNEL
set -eu
OUT=${1:?usage: $0 OUT}
CC=${CC:-aarch64-linux-gnu-gcc}
OBJCOPY=${OBJCOPY:-aarch64-linux-gnu-objcopy}
HERE=$(cd "$(dirname "$0")" && pwd)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
$CC -c -x assembler-with-cpp "$HERE/pi-init.S" -o "$TMP/init.o"
$CC -nostdlib -static -Wl,-Ttext=0 -o "$TMP/init.elf" "$TMP/init.o"
$OBJCOPY -O binary -j .text "$TMP/init.elf" "$TMP/init.bin"
python3 -I "$HERE/mkinit.py" "$TMP/init.bin" "$OUT"
chmod 755 "$OUT"
