#!/usr/bin/env python3
"""Save a QEMU screenshot every N seconds through the HMP monitor socket.

  qemu-screendump.py SOCKET OUTDIR [SECONDS]

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
        shutil.copyfile(path, os.path.join(outdir, 'last.ppm'))
    n += 1
