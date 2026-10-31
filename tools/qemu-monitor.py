#!/usr/bin/env python3
"""Send one HMP command to the QEMU monitor socket of tools/pi3-qemu-boot.sh (SCREENDUMP=...).

  qemu-monitor.py SOCKET 'savevm lock'      (also: loadvm, info snapshots, quit, ...)
"""
import socket, sys, time

s = socket.socket(socket.AF_UNIX)
s.settimeout(float(sys.argv[3]) if len(sys.argv) > 3 else 120)
s.connect(sys.argv[1])
s.recv(4096)
s.sendall((sys.argv[2] + '\n').encode())
time.sleep(1)
try:
    print(s.recv(65536).decode(errors='replace').strip())
except OSError as e:
    print('no reply:', e)
