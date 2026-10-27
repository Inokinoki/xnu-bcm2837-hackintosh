#!/bin/sh
# Run a packed kernel on QEMU raspi3b under gdb and report the first panic:
# the format string, its arguments and the caller.
#
#   tools/pi3-qemu-panic.sh KERNEL OUTDIR [BREAK_SYMBOL]
#
# OUTDIR is what tools/pi3-qemu-boot.sh left (loader.elf, payload.bin).
# Needs QEMU (qemu-system-aarch64) and GDB (gdb-multiarch).
set -eu
KERNEL=${1:?usage: $0 KERNEL OUTDIR [BREAK_SYMBOL]}
OUT=${2:?usage: $0 KERNEL OUTDIR [BREAK_SYMBOL]}
SYM=${3:-panic}
QEMU=${QEMU:-qemu-system-aarch64}
GDB=${GDB:-gdb-multiarch}
HERE=$(cd "$(dirname "$0")" && pwd)
PORT=${PORT:-1234}

ADDR=$(python3 "$HERE/macho_sym.py" "$KERNEL" -n "$SYM" | awk '{print $2}')
[ "$ADDR" != "not" ] && [ -n "$ADDR" ] || { echo "no symbol $SYM"; exit 1; }

timeout 120 "$QEMU" -M raspi3b -kernel "$OUT/loader.elf" \
    -device loader,file="$OUT/payload.bin",addr=0x3c000000,force-raw=on \
    -display none -serial null -serial file:"$OUT/uart1.gdb.log" \
    -S -gdb tcp::"$PORT" -no-reboot >/dev/null 2>&1 &
QPID=$!
sleep 2
timeout 100 "$GDB" -batch -ex "set architecture aarch64" -ex "target remote localhost:$PORT" \
    -ex "hbreak *$ADDR" -ex continue \
    -ex "info registers x0 x1 x2 x3 x4 x5 x30" -ex 'x/s $x0' -ex detach 2>&1 |
    grep -v '^warning\|Remote debugging\|determining\|target architecture' | tee "$OUT/panic.txt"
kill "$QPID" 2>/dev/null || true
CALLER=$(awk '/^x30/ {print $2}' "$OUT/panic.txt")
[ -n "$CALLER" ] && python3 "$HERE/macho_sym.py" "$KERNEL" "$CALLER"
