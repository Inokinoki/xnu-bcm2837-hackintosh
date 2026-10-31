#!/usr/bin/env python3
"""Send touch and key input to the guest through the PL011 socket of tools/pi3-qemu-boot.sh (HID=1).

  qemu-touch.py SOCKET tap X Y [HOLD_MS]
  qemu-touch.py SOCKET swipe X1 Y1 X2 Y2 [MS] [STEPS]
  qemu-touch.py SOCKET key power|volup|voldown|home [HOLD_MS]
  qemu-touch.py SOCKET raw 'LINE'

X,Y are framebuffer pixels (1125x2436 for the iPhone X geometry). Examples:
  tap the screen centre:   qemu-touch.py /tmp/pi3/hid.sock tap 562 1218
  swipe up from the bottom edge (unlock / go home):  qemu-touch.py SOCK swipe 562 2400 562 1400 400
"""
import socket, sys, time

KEYS = {'power': 0, 'volup': 1, 'voldown': 2, 'home': 3}


def main():
    s = socket.socket(socket.AF_UNIX)
    s.connect(sys.argv[1])
    send = lambda line: s.sendall((line + '\n').encode())
    cmd, a = sys.argv[2], sys.argv[3:]
    if cmd == 'tap':
        x, y = int(a[0]), int(a[1])
        hold = int(a[2]) if len(a) > 2 else 80
        send(f't 0 d {x} {y}')
        time.sleep(hold / 1000)
        send(f't 0 u {x} {y}')
    elif cmd == 'swipe':
        x1, y1, x2, y2 = (int(v) for v in a[:4])
        ms = int(a[4]) if len(a) > 4 else 300
        steps = int(a[5]) if len(a) > 5 else 12
        send(f't 0 d {x1} {y1}')
        for i in range(1, steps + 1):
            time.sleep(ms / 1000 / steps)
            send(f't 0 m {x1 + (x2 - x1) * i // steps} {y1 + (y2 - y1) * i // steps}')
        send(f't 0 u {x2} {y2}')
    elif cmd == 'key':
        k = KEYS[a[0]]
        hold = int(a[1]) if len(a) > 1 else 100
        send(f'k {k} d')
        time.sleep(hold / 1000)
        send(f'k {k} u')
    elif cmd == 'raw':
        send(a[0])
    else:
        sys.exit(__doc__)
    time.sleep(0.2)


if __name__ == '__main__':
    main()
