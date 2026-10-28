#!/usr/bin/env python3
"""Extract the payload of an IM4P (DER) file, e.g. an IPSW DeviceTree.*.im4p.

  im4p-extract.py IN.im4p OUT [DECODER]

The payload is LZFSE ("bvx2") compressed for device trees. DECODER is a program
taking IN OUT (tools/ios-root-docker/lzfse-dec.c, built in the pi-ios-root container).
Without a decoder the compressed payload is written as it is.
"""
import subprocess, sys, tempfile


def tlv(b, o):
    t, l = b[o], b[o + 1]
    o += 2
    if l & 0x80:
        n = l & 0x7f
        l = int.from_bytes(b[o:o + n], 'big')
        o += n
    return t, l, o


def payload(d):
    t, l, o = tlv(d, 0)
    assert t == 0x30
    end = o + l
    idx = 0
    while o < end:
        t, l, o2 = tlv(d, o)
        if idx == 0:
            assert d[o2:o2 + l] == b'IM4P', 'not an IM4P'
        if idx == 3:
            assert t == 0x04, 'payload is not an OCTET STRING'
            return d[o2:o2 + l]
        o = o2 + l
        idx += 1
    raise SystemExit('no payload')


if __name__ == '__main__':
    data = payload(open(sys.argv[1], 'rb').read())
    if data[:4] == b'bvx2' and len(sys.argv) > 3:
        with tempfile.NamedTemporaryFile() as tmp:
            tmp.write(data)
            tmp.flush()
            subprocess.run([sys.argv[3], tmp.name, sys.argv[2]], check=True)
    else:
        open(sys.argv[2], 'wb').write(data)
