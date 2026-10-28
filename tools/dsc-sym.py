#!/usr/bin/env python3
"""Map addresses to dyld shared cache images (library path + offset).

  dsc-sym.py MAIN_CACHE SLIDE ADDR...        MAIN_CACHE = .../dyld_shared_cache_arm64
  dsc-sym.py MAIN_CACHE SLIDE --log FILE     annotate the "SMP ... bt ..." lines of a console log

The kernel's process sampler (xnu patch 0061) prints runtime addresses and the shared region
slide. Only the image list of the main cache file is read, so this gives the library and the
offset inside it, not function names.
"""
import bisect, re, struct, sys


def load(path):
    d = open(path, 'rb').read()
    assert d[:8] == b'dyld_v1 ', 'not a dyld shared cache'
    io, ic = struct.unpack_from('<II', d, 0x1c0)
    if not ic:
        io, ic = struct.unpack_from('<II', d, 0x18)
    imgs = []
    for i in range(ic):
        addr, _, _, poff, _ = struct.unpack_from('<QQQII', d, io + 32 * i)
        end = d.index(b'\0', poff)
        imgs.append((addr, d[poff:end].decode()))
    imgs.sort()
    return imgs


def lookup(imgs, va):
    k = bisect.bisect_right([a for a, _ in imgs], va) - 1
    if k < 0:
        return '?'
    addr, path = imgs[k]
    return f'{path.rsplit("/", 1)[-1]}+0x{va - addr:x}'


def main():
    imgs = load(sys.argv[1])
    slide = int(sys.argv[2], 0)
    if sys.argv[3] == '--log':
        hexre = re.compile(r'0x[0-9a-f]{6,}')
        for line in open(sys.argv[4], errors='replace'):
            if line.startswith('SMP ') and ' pc ' in line:
                head, _, bt = line.partition(' bt')
                m = re.match(r'(SMP \S+ t\d+) pc (\S+) lr (\S+)', head)
                pcs = [int(m.group(2), 16), int(m.group(3), 16)] + [int(x, 16) for x in hexre.findall(bt)]
                print(m.group(1), ' <- '.join(lookup(imgs, a - slide) if a >= 0x180000000 else hex(a) for a in pcs))
        return
    for a in sys.argv[3:]:
        v = int(a, 0)
        print(hex(v), lookup(imgs, v - slide) if v >= 0x180000000 else '(not in the cache)')


if __name__ == '__main__':
    main()
