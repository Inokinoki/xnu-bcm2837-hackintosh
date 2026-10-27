#!/usr/bin/env python3
"""Look up symbols in an xnu Mach-O kernel (LC_SYMTAB), no Apple tools needed.

  macho_sym.py KERNEL ADDR...      nearest symbol at or below each hex address
  macho_sym.py KERNEL -n NAME...   address of each symbol (with or without '_')
"""
import bisect, struct, sys


def load(path):
    buf = open(path, 'rb').read()
    ncmds, = struct.unpack_from('<I', buf, 16)
    off, symoff, nsyms, stroff = 32, 0, 0, 0
    for _ in range(ncmds):
        cmd, size = struct.unpack_from('<II', buf, off)
        if cmd == 0x2:		# LC_SYMTAB
            symoff, nsyms, stroff, _ = struct.unpack_from('<4I', buf, off + 8)
        off += size
    syms = []
    for i in range(nsyms):
        strx, ntype, _, _, value = struct.unpack_from('<IBBHQ', buf, symoff + 16 * i)
        if ntype & 0x0e == 0x0e and value:	# N_SECT
            end = buf.index(b'\0', stroff + strx)
            syms.append((value, buf[stroff + strx:end].decode(errors='replace')))
    syms.sort()
    return syms


def main():
    syms = load(sys.argv[1])
    args = sys.argv[2:]
    if args and args[0] == '-n':
        names = {name: value for value, name in syms}
        for n in args[1:]:
            v = names.get(n) or names.get('_' + n)
            print(n, hex(v) if v else 'not found')
        return
    keys = [v for v, _ in syms]
    for a in args:
        t = int(a, 16)
        i = bisect.bisect_right(keys, t) - 1
        print(a, '->', syms[i][1], '+', hex(t - syms[i][0]) if i >= 0 else '?')


if __name__ == '__main__':
    main()
