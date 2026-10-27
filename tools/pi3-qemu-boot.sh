#!/bin/sh
# Boot an xnu-bcm2837 kernel on QEMU raspi3b through the loader.
#
#   [RAMDISK=image] [CMDLINE=...] tools/pi3-qemu-boot.sh KERNEL [SECONDS]
#
# Needs an aarch64 gcc (CC, default aarch64-linux-gnu-gcc), qemu-system-aarch64
# (QEMU, default qemu-system-aarch64) and python3. The mini UART (what the
# kernel's Pi 3 driver uses) is QEMU's serial1; the log lands in OUT/uart1.log.
set -eu
KERNEL=${1:?usage: $0 KERNEL [SECONDS]}
SECS=${2:-60}
CC=${CC:-aarch64-linux-gnu-gcc}
QEMU=${QEMU:-qemu-system-aarch64}
HERE=$(cd "$(dirname "$0")/.." && pwd)
OUT=${OUT:-$HERE/build/qemu-pi3}
mkdir -p "$OUT"

# 1. loader (loader/*.S, loader/*.c, loader/link.ld) at 0x80000
$CC -c -march=armv8-a "$HERE/loader/start.S" -o "$OUT/start.o"
$CC -c -march=armv8-a -mgeneral-regs-only -ffreestanding -fno-builtin \
    -fno-stack-protector -fno-pic -Wall -Wextra -O2 "$HERE/loader/main.c" -o "$OUT/main.o"
$CC -nostdlib -static -T "$HERE/loader/link.ld" -o "$OUT/loader.elf" "$OUT/start.o" "$OUT/main.o"

# 2. payload: the kernel's segments + ADT + command line, placed at PAYLOAD_PA
# RAMDISK=image makes the payload carry a RAM disk root (boot-arg rd=md0);
# CMDLINE overrides the default boot-args.
set -- "$KERNEL" "$OUT/payload.bin"
if [ -n "${RAMDISK:-}" ]; then
    set -- "$@" --ramdisk "$RAMDISK"
    : "${CMDLINE:=debug=0xc serial=3 cpus=1 keepsyms=1 kt_fixed_zones=120 -noprogress rd=md0}"
fi
[ -n "${CMDLINE:-}" ] && set -- "$@" --cmdline "$CMDLINE"
python3 "$HERE/tools/mkpi_payload.py" "$@"

# 3. run; QEMU's generic loader puts the payload at 0x3c000000
rm -f "$OUT/uart1.log"
set +e
timeout "$SECS" "$QEMU" -M raspi3b -kernel "$OUT/loader.elf" \
    -device loader,file="$OUT/payload.bin",addr=0x3c000000,force-raw=on \
    -display none -serial null -serial file:"$OUT/uart1.log" \
    -D "$OUT/qemu.log" -d int,guest_errors -no-reboot
rc=$?
set -e
echo "qemu exit=$rc (124 = still running at the timeout)"
echo "uart1 log: $OUT/uart1.log"
