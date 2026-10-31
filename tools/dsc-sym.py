#!/usr/bin/env python3
"""Map runtime addresses to dyld shared cache images and symbols.

  dsc-sym.py CACHE_DIR SLIDE ADDR...          CACHE_DIR = .../com.apple.dyld (all subcache files)
  dsc-sym.py CACHE_DIR SLIDE --log FILE       annotate the "SMP ... bt ..." lines of a console log

The kernel's process sampler (xnu patch 0061) prints runtime addresses and the shared region
slide. Every subcache file is opened in place (they are big: run it where the iOS root is
mounted, e.g. in the docker container, see tools/dsc-sym.sh). Names come from each image's
LC_SYMTAB (exported/global symbols; the cache strips local ones), so a frame inside a static
function shows the nearest exported symbol before it.
"""
import bisect, glob, os, re, struct, sys


class Cache:
    def __init__(self, d):
        self.files = {}
        self.maps = []          # (address, size, fileoff, path)
        for p in sorted(glob.glob(os.path.join(d, 'dyld_shared_cache_arm64*'))):
            if p.endswith('.symbols'):
                continue
            f = open(p, 'rb')
            h = f.read(0x200)
            if h[:8] != b'dyld_v1 ':
                continue
            mo, mc = struct.unpack_from('<II', h, 0x10)
            f.seek(mo)
            for i in range(mc):
                a, s, fo, _, _ = struct.unpack('<QQQII', f.read(32))
                self.maps.append((a, s, fo, p))
            self.files[p] = f
            if p.endswith('dyld_shared_cache_arm64'):
                self.main = p
                io, ic = struct.unpack_from('<II', h, 0x1c0)
                f.seek(io)
                raw = f.read(32 * ic)
                self.images = []
                for i in range(ic):
                    addr, _, _, poff, _ = struct.unpack_from('<QQQII', raw, 32 * i)
                    f.seek(poff)
                    self.images.append((addr, f.read(256).split(b'\0')[0].decode()))
                self.images.sort()
        self.maps.sort()
        self.addrs = [a for a, _ in self.images]
        self.syms = {}

    def read(self, va, n):
        for a, s, fo, p in self.maps:
            if a <= va < a + s:
                f = self.files[p]
                f.seek(fo + va - a)
                return f.read(n)
        raise KeyError(hex(va))

    def symbols(self, base):
        """Sorted [(offset, name)] of the defined symbols of the image whose header is at base."""
        if base in self.syms:
            return self.syms[base]
        out = []
        try:
            hdr = self.read(base, 32)
            ncmds, = struct.unpack_from('<I', hdr, 16)
            lc = self.read(base + 32, struct.unpack_from('<I', hdr, 20)[0])
            off, symtab, linkedit = 0, None, None
            for _ in range(ncmds):
                cmd, size = struct.unpack_from('<II', lc, off)
                if cmd == 0x2:
                    symtab = struct.unpack_from('<4I', lc, off + 8)
                elif cmd == 0x19 and lc[off + 8:off + 24].rstrip(b'\0') == b'__LINKEDIT':
                    linkedit = struct.unpack_from('<4Q', lc, off + 24)   # vmaddr vmsize fileoff filesize
                off += size
            if symtab and linkedit:
                symoff, nsyms, stroff, strsize = symtab
                va = lambda fo: linkedit[0] + fo - linkedit[2]
                nl = self.read(va(symoff), nsyms * 16)
                strs = self.read(va(stroff), strsize)
                for i in range(nsyms):
                    strx, ntype, nsect, _, value = struct.unpack_from('<IBBHQ', nl, 16 * i)
                    if ntype & 0x0e == 0x0e and nsect and value >= base:      # N_SECT, in this image
                        out.append((value - base, strs[strx:strs.index(b'\0', strx)].decode(errors='replace')))
        except Exception:
            pass
        out.sort()
        self.syms[base] = out
        return out

    def name(self, va):
        k = bisect.bisect_right(self.addrs, va) - 1
        if k < 0:
            return '?'
        base, path = self.images[k]
        lib = path.rsplit('/', 1)[-1]
        s = self.symbols(base)
        j = bisect.bisect_right([o for o, _ in s], va - base) - 1
        if j >= 0:
            return f'{lib}`{s[j][1]}+0x{va - base - s[j][0]:x}'
        return f'{lib}+0x{va - base:x}'


def main():
    c = Cache(sys.argv[1])
    slide = int(sys.argv[2], 0)
    if sys.argv[3] == '--log':
        hexre = re.compile(r'0x[0-9a-f]{6,}')
        for line in open(sys.argv[4], errors='replace'):
            if line.startswith('SMP ') and ' pc ' in line:
                head, _, bt = line.partition(' bt')
                m = re.match(r'(SMP \S+ t\d+) pc (\S+) lr (\S+)', head)
                pcs = [int(m.group(2), 16), int(m.group(3), 16)] + [int(x, 16) for x in hexre.findall(bt)]
                print(m.group(1), ' <- '.join(c.name(a - slide) if a >= 0x180000000 else hex(a) for a in pcs))
        return
    for a in sys.argv[3:]:
        v = int(a, 0)
        print(hex(v), c.name(v - slide) if v >= 0x180000000 else '(not in the cache)')


if __name__ == '__main__':
    main()
