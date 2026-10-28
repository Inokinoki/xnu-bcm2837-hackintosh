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
s = socket.socket(socket.AF_UNIX)
s.connect(sock_path)
s.settimeout(5)
try:
    s.recv(4096)
except OSError:
    pass
n = 0
while True:
    time.sleep(every)
    path = os.path.abspath(os.path.join(outdir, f'shot-{n:03d}.ppm'))
    try:
        s.sendall(f'screendump {path}\n'.encode())
        s.recv(4096)
    except OSError:
        break
    if os.path.exists(path):
        shutil.copyfile(path, os.path.join(outdir, 'last.ppm'))
    n += 1
