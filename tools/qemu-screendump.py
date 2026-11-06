#!/usr/bin/env python3
"""Save a QEMU screenshot every N seconds through the HMP monitor socket.

  qemu-screendump.py SOCKET OUTDIR [SECONDS]

QEMU's screendump pads every PPM row to a multiple of 4 bytes (a 1125 pixel wide image has 3375 bytes
of pixels per row but 3376 in the file), which skews any reader that expects packed rows by one
byte per row. The files written here are rewritten with packed rows.

Started by tools/pi3-qemu-boot.sh (SCREENDUMP=dir:seconds). Files are OUTDIR/shot-NNN.ppm;
the last one is also OUTDIR/last.ppm. Ends when the monitor connection closes.
"""
import os, shutil, socket, sys, time

sock_path, outdir = sys.argv[1], sys.argv[2]
every = float(sys.argv[3]) if len(sys.argv) > 3 else 60.0
os.makedirs(outdir, exist_ok=True)
for _ in range(200):
    if os.path.exists(sock_path):
        break
    time.sleep(0.1)


def pack_ppm(path):
    """Rewrite a QEMU PPM (rows padded to 4 bytes) with packed rows."""
    d = open(path, 'rb').read()
    magic, dims, maxval, data = d.split(b'\n', 3)
    w, h = (int(v) for v in dims.split())
    stride = (w * 3 + 3) // 4 * 4
    if stride != w * 3 and len(data) >= stride * h:
        rows = (data[y * stride:y * stride + w * 3] for y in range(h))
        open(path, 'wb').write(b'\n'.join((magic, dims, maxval)) + b'\n' + b''.join(rows))


def hmp(cmd):
    """One HMP command on a fresh connection (the monitor socket takes one client at a time)."""
    s = socket.socket(socket.AF_UNIX)
    s.settimeout(10)
    s.connect(sock_path)
    try:
        s.recv(4096)
        s.sendall((cmd + '\n').encode())
        time.sleep(0.5)
        s.recv(4096)
    finally:
        s.close()


n = 0
while True:
    time.sleep(every)
    path = os.path.abspath(os.path.join(outdir, f'shot-{n:03d}.ppm'))
    try:
        hmp(f'screendump {path}')
    except (OSError, ConnectionError):
        if not os.path.exists(sock_path):
            break
        continue
    if os.path.exists(path):
        pack_ppm(path)
        shutil.copyfile(path, os.path.join(outdir, 'last.ppm'))
    n += 1
