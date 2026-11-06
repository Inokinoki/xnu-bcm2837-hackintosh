#!/usr/bin/env python3
"""Build a small, read-only-style HFS+ root image from a directory, without mounting.

  mkhfsroot.py DIR OUT.img [--size 8M] [--name BCM2837Root]

For bring-up and tests (a handful of directories and regular files, no
symlinks, hard links, xattrs or journal). The catalog is a single leaf node, so
the tree is limited to a few hundred entries. A real iOS root needs
mkfs.hfsplus + mount + rsync as root (see the notes in README.md).
Check the result with: fsck.hfsplus -n OUT.img
"""
import argparse, os, struct, sys, time

BLOCK = 4096
NODE = 16384
EPOCH = 2082844800		# 1904 -> 1970


def u16(v): return struct.pack('>H', v)
def u32(v): return struct.pack('>I', v)
def u64(v): return struct.pack('>Q', v)


def utf16(name):
    return name.encode('utf-16-be')


def fork(size, extents, clump=BLOCK):
    """HFSPlusForkData: extents = [(start, count)], up to 8."""
    total = sum(c for _, c in extents)
    ext = b''.join(u32(s) + u32(c) for s, c in extents)
    ext += bytes(8 * (8 - len(extents)))
    return u64(size) + u32(clump) + u32(total) + ext


def cat_key(parent, name):
    n = utf16(name)
    body = u32(parent) + u16(len(name)) + n
    return u16(len(body)) + body


def sort_key(parent, name):
    # FastUnicodeCompare folds case; ASCII lower-casing is enough for test roots.
    return (parent, name.lower())


def perms(mode, uid=0, gid=0):
    return u32(uid) + u32(gid) + bytes([0, 0]) + u16(mode) + u32(0)


def folder_rec(cnid, valence, now):
    return (u16(1) + u16(0) + u32(valence) + u32(cnid) + u32(now) * 4 + u32(0) +
            perms(0o40755) + bytes(16) + bytes(16) + u32(0) + u32(0))


def file_rec(cnid, size, extents, now, mode):
    return (u16(2) + u16(2) + u32(0) + u32(cnid) + u32(now) * 4 + u32(0) +
            perms(0o100000 | mode) + bytes(16) + bytes(16) + u32(0) + u32(0) +
            fork(size, extents) + fork(0, []))


def thread_rec(kind, parent, name):
    return u16(kind) + u16(0) + u32(parent) + u16(len(name)) + utf16(name)


def btree_header_node(node_size, depth, root, nleaf, first, last, total, free,
                      max_key, attrs, key_cmp=0):
    desc = u32(0) + u32(0) + bytes([1, 0]) + u16(3) + u16(0)
    hdr = (u16(depth) + u32(root) + u32(nleaf) + u32(first) + u32(last) + u16(node_size) +
           u16(max_key) + u32(total) + u32(free) + u16(0) + u32(node_size * 1) + bytes([0, key_cmp]) +
           u32(attrs) + bytes(64))
    assert len(hdr) == 106
    user = bytes(128)
    map_off = 14 + 106 + 128
    map_len = node_size - map_off - 8
    bitmap = bytearray(map_len)
    for n in range(total - free):
        bitmap[n // 8] |= 0x80 >> (n % 8)
    node = bytearray(node_size)
    node[:14] = desc
    node[14:14 + 106] = hdr
    node[120:248] = user
    node[map_off:map_off + map_len] = bitmap
    offs = [14, 14 + 106, 14 + 106 + 128, map_off + map_len]
    for i, o in enumerate(offs):
        struct.pack_into('>H', node, node_size - 2 * (i + 1), o)
    return bytes(node)


def leaf_node(node_size, records):
    node = bytearray(node_size)
    node[:14] = u32(0) + u32(0) + bytes([0xff, 1]) + u16(len(records)) + u16(0)
    off = 14
    offs = []
    for r in records:
        if len(r) & 1:
            r += b'\0'
        assert off + len(r) + 2 * (len(records) + 1) <= node_size, 'catalog does not fit one node'
        node[off:off + len(r)] = r
        offs.append(off)
        off += len(r)
    offs.append(off)
    for i, o in enumerate(offs):
        struct.pack_into('>H', node, node_size - 2 * (i + 1), o)
    return bytes(node)


def build(root_dir, size, volname):
    now = int(time.time()) + EPOCH
    total_blocks = size // BLOCK
    entries = []		# (cnid, parent, name, is_dir, data|None, mode)
    ids = {root_dir: 2}
    next_id = [16]
    children = {root_dir: 0}

    def walk(d):
        for name in sorted(os.listdir(d)):
            p = os.path.join(d, name)
            if os.path.islink(p):
                raise SystemExit(f'symlinks are not supported: {p}')
            cnid = next_id[0]
            next_id[0] += 1
            parent = ids[d]
            children[d] += 1
            if os.path.isdir(p):
                ids[p] = cnid
                children[p] = 0
                entries.append([cnid, parent, name, True, None, 0o755, p])
                walk(p)
            else:
                data = open(p, 'rb').read()
                entries.append([cnid, parent, name, False, data, os.stat(p).st_mode & 0o777, p])
    walk(root_dir)

    # layout: block 0 header, then allocation file, extents file, catalog file, file data
    bitmap_blocks = (total_blocks // 8 + BLOCK - 1) // BLOCK
    alloc_start = 1
    ext_start = alloc_start + bitmap_blocks
    ext_blocks = NODE // BLOCK
    cat_start = ext_start + ext_blocks
    cat_nodes = 4
    cat_blocks = cat_nodes * NODE // BLOCK
    nxt = cat_start + cat_blocks
    files = {}
    for e in entries:
        if not e[3]:
            n = max(1, (len(e[4]) + BLOCK - 1) // BLOCK)
            files[e[0]] = (nxt, n)
            nxt += n
    used = nxt
    assert used + 1 <= total_blocks, 'image too small'

    recs = []
    recs.append((sort_key(1, volname), cat_key(1, volname) + folder_rec(2, children[root_dir], now)))
    recs.append((sort_key(2, ''), cat_key(2, '') + thread_rec(3, 1, volname)))
    for cnid, parent, name, is_dir, data, mode, _ in entries:
        if is_dir:
            body = folder_rec(cnid, children[_], now)
            kind = 3
        else:
            start, n = files[cnid]
            body = file_rec(cnid, len(data), [(start, n)], now, mode)
            kind = 4
        recs.append((sort_key(parent, name), cat_key(parent, name) + body))
        recs.append((sort_key(cnid, ''), cat_key(cnid, '') + thread_rec(kind, parent, name)))
    recs.sort(key=lambda r: r[0])
    leaf = leaf_node(NODE, [r[1] for r in recs])

    max_key = 516
    cat = (btree_header_node(NODE, 1, 1, len(recs), 1, 1, cat_nodes, cat_nodes - 2, max_key, 6, 0xcf) +
           leaf + bytes(NODE * (cat_nodes - 2)))
    extfile = btree_header_node(NODE, 0, 0, 0, 0, 0, 1, 0, 10, 4, 0)
    # extents overflow file: one header node, no records
    extfile = btree_header_node(NODE, 0, 0, 0, 0, 0, 1, 0, 10, 4, 0)

    img = bytearray(size)
    # allocation bitmap: everything below `used` plus the last block (alternate header)
    bm = bytearray(bitmap_blocks * BLOCK)
    for b in list(range(used)) + [total_blocks - 1]:
        bm[b // 8] |= 0x80 >> (b % 8)
    img[alloc_start * BLOCK:alloc_start * BLOCK + len(bm)] = bm
    img[ext_start * BLOCK:ext_start * BLOCK + len(extfile)] = extfile
    img[cat_start * BLOCK:cat_start * BLOCK + len(cat)] = cat
    for e in entries:
        if not e[3]:
            start, _ = files[e[0]]
            img[start * BLOCK:start * BLOCK + len(e[4])] = e[4]

    nfiles = sum(1 for e in entries if not e[3])
    nfolders = sum(1 for e in entries if e[3])
    vh = (b'H+' + u16(4) + u32(0x100) + u32(0x31302e30) + u32(0) +
          u32(now) * 4 + u32(nfiles) + u32(nfolders) + u32(BLOCK) + u32(total_blocks) +
          u32(total_blocks - used - 1) + u32(used) + u32(BLOCK) + u32(BLOCK) +
          u32(next_id[0]) + u32(1) + u64(1) + bytes(32) +
          fork(len(bm), [(alloc_start, bitmap_blocks)]) +
          fork(len(extfile), [(ext_start, ext_blocks)], NODE) +
          fork(len(cat), [(cat_start, cat_blocks)], NODE) +
          fork(0, []) + fork(0, []))
    vh += bytes(512 - len(vh))
    img[1024:1536] = vh
    img[size - 1024:size - 512] = vh
    return bytes(img)


def parse_size(s):
    mult = {'K': 1 << 10, 'M': 1 << 20, 'G': 1 << 30}
    return int(s[:-1]) * mult[s[-1].upper()] if s[-1].upper() in mult else int(s)


if __name__ == '__main__':
    ap = argparse.ArgumentParser()
    ap.add_argument('dir')
    ap.add_argument('out')
    ap.add_argument('--size', default='8M')
    ap.add_argument('--name', default='BCM2837Root')
    a = ap.parse_args()
    size = parse_size(a.size) // BLOCK * BLOCK
    open(a.out, 'wb').write(build(a.dir.rstrip('/'), size, a.name))
    print(f'{a.out}: {size} bytes')
