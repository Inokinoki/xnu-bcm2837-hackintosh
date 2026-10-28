#!/bin/sh
# Boot an xnu-bcm2837 kernel on QEMU raspi3b through the loader.
#
#   [RAMDISK=image | SDIMG=image] [CMDLINE=...] tools/pi3-qemu-boot.sh KERNEL [SECONDS]
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
# SDSNAPSHOT=1 keeps the image unmodified (QEMU snapshot=on). SDFORMAT=qcow2 with a qcow2 overlay
# (qemu-img create -f qcow2 -b root.img -F raw overlay.qcow2) keeps the guest's writes between runs.
# SDIMG=image attaches it as the SD card (a power-of-two size) and roots on it (rd=sdroot0).
# CMDLINE overrides the default boot-args.
set -- "$KERNEL" "$OUT/payload.bin"
if [ -n "${RAMDISK:-}" ]; then
    set -- "$@" --ramdisk "$RAMDISK"
    : "${CMDLINE:=debug=0xc serial=3 cpus=1 keepsyms=1 kt_fixed_zones=120 -noprogress rd=md0}"
fi
if [ -n "${SDIMG:-}" ]; then
    : "${CMDLINE:=debug=0xc serial=3 cpus=1 keepsyms=1 kt_fixed_zones=120 -noprogress rd=sdroot0}"
fi
[ -n "${CMDLINE:-}" ] && set -- "$@" --cmdline "$CMDLINE"
# FB=WxH: the loader asks the VideoCore for a framebuffer, the ADT gets /arm-io/disp0.
[ -n "${FB:-}" ] && set -- "$@" --fb "$FB"
# IOS_DT=d22ap.adt: look like the iPhone X (see tools/im4p-extract.py for getting that device tree).
[ -n "${IOS_DT:-}" ] && set -- "$@" --ios-dt "$IOS_DT"
python3 "$HERE/tools/mkpi_payload.py" "$@"

# 3. run; QEMU's generic loader puts the payload at 0x3c000000
rm -f "$OUT/uart1.log"
# HID=1: the PL011 UART (guest uart0) listens on $OUT/hid.sock for the guest's input commands
# (tools/qemu-touch.py sends taps, swipes and keys; xnu patch 0065, BCM2837HIDUart).
if [ -n "${HID:-}" ]; then
    rm -f "$OUT/hid.sock"
    HIDSERIAL="unix:$OUT/hid.sock,server=on,wait=off"
fi
set +e
# LOADVM=tag restores a QEMU snapshot made with tools/qemu-monitor.py SOCK "savevm tag" (needs a qcow2 SD).
# SCREENDUMP=dir[:seconds]: save a screenshot (PPM) of the guest display every N seconds (default 60).
if [ -n "${SCREENDUMP:-}" ]; then
    SDDIR=${SCREENDUMP%%:*}
    SDEVERY=60
    case "$SCREENDUMP" in *:*) SDEVERY=${SCREENDUMP##*:};; esac
    mkdir -p "$SDDIR"
    rm -f "$OUT/mon.sock"
    python3 "$HERE/tools/qemu-screendump.py" "$OUT/mon.sock" "$SDDIR" "$SDEVERY" &
    SDPID=$!
    MONITOR="-monitor unix:$OUT/mon.sock,server,nowait"
fi
timeout "$SECS" "$QEMU" ${MONITOR:-} ${LOADVM:+-loadvm "$LOADVM"} ${QEMU_ARGS:-} -M raspi3b -kernel "$OUT/loader.elf" \
    -device loader,file="$OUT/payload.bin",addr=0x3c000000,force-raw=on \
    ${SDIMG:+-drive file="$SDIMG",if=sd,format=${SDFORMAT:-raw}${SDSNAPSHOT:+,snapshot=on}} \
    -display none -serial "${HIDSERIAL:-null}" -serial file:"$OUT/uart1.log" \
    -D "$OUT/qemu.log" -d ${QEMU_DEBUG:-guest_errors} -no-reboot
rc=$?
[ -n "${SDPID:-}" ] && kill "$SDPID" 2>/dev/null
set -e
echo "qemu exit=$rc (124 = still running at the timeout)"
echo "uart1 log: $OUT/uart1.log"
