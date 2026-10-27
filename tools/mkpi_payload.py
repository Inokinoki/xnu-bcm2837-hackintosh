#!/usr/bin/env python3
"""Pack the xnu kernel Mach-O for the BCM2837 loader (loader/payload.h).

  mkpi_payload.py KERNEL OUT [--cmdline "..."] [--ramdisk IMAGE]

The kernel must have no chained fixups (the BCM2837 build has none); its
segments are copied as flat bytes to phys_base + (vmaddr - virt_base) by the
loader. The payload is placed at PAYLOAD_PA by QEMU's loader device or the
firmware-side copy, so its size must stay under the RAM the kernel gets.
"""
import argparse, os, struct, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pi_adt  # noqa: E402

LC_SEGMENT_64, LC_UNIXTHREAD, LC_DYLD_CHAINED_FIXUPS = 0x19, 0x5, 0x80000034
PAGE = 0x1000
MAGIC = b'PIXNUPL1'
BOOT_LINE_LENGTH = 608
CMDLINE = 0x48
SEG_TABLE = CMDLINE + BOOT_LINE_LENGTH	# 0x2a8

# loader/main.c: the kernel's virtual base and the RAM it gets.
VIRT_BASE = 0xfffffff006000000
PHYS_BASE = 0x10000000
MEM_SIZE = 0x2c000000


def parse_macho(buf):
    magic, cputype, cpusub, ftype, ncmds, sizeofcmds, flags, _ = struct.unpack_from('<8I', buf, 0)
    assert magic == 0xfeedfacf, 'not a 64-bit Mach-O'
    segs, entry = [], None
    off = 32
    for _ in range(ncmds):
        cmd, size = struct.unpack_from('<II', buf, off)
        assert cmd != LC_DYLD_CHAINED_FIXUPS, 'kernel has chained fixups: not supported by this loader'
        if cmd == LC_SEGMENT_64:
            name = buf[off + 8:off + 24].split(b'\0')[0].decode()
            vmaddr, vmsize, fileoff, filesize = struct.unpack_from('<4Q', buf, off + 24)
            segs.append(dict(name=name, vmaddr=vmaddr, vmsize=vmsize, fileoff=fileoff, filesize=filesize))
        elif cmd == LC_UNIXTHREAD:
            # arm_thread_state64: x0..x28, fp, lr, sp, pc, cpsr
            entry, = struct.unpack_from('<Q', buf, off + 16 + 32 * 8)
        off += size
    return dict(cputype=cputype, segs=segs, entry=entry)


def build(kernel_path, cmdline, ramdisk_path=None):
    buf = bytearray(open(kernel_path, 'rb').read())
    m = parse_macho(buf)
    segs = [s for s in m['segs'] if s['vmsize']]
    text = m['segs'][0]
    assert text['name'] == '__TEXT' and text['fileoff'] == 0
    assert text['vmaddr'] - VIRT_BASE < 0x2000000, 'kernel does not fit the loader virt_base window'

    kernel_end = max(s['vmaddr'] + s['vmsize'] for s in segs)
    kernel_end = (kernel_end + PAGE - 1) & ~(PAGE - 1)
    kernel_pa_end = kernel_end - VIRT_BASE + PHYS_BASE
    assert kernel_pa_end < PHYS_BASE + MEM_SIZE, 'kernel does not fit the RAM window'

    pieces = [(s['vmaddr'], s['vmsize'], bytes(buf[s['fileoff']:s['fileoff'] + s['filesize']])) for s in segs]

    # A RAM disk is one more segment right after the kernel; kernel_end moves past
    # it so the kernel does not hand those pages out. The ADT tells the md driver.
    ramdisk = None
    if ramdisk_path:
        image = open(ramdisk_path, 'rb').read()
        rd_size = (len(image) + PAGE - 1) & ~(PAGE - 1)
        rd_va = kernel_end
        kernel_end = rd_va + rd_size
        assert kernel_end - VIRT_BASE + PHYS_BASE < PHYS_BASE + MEM_SIZE, 'RAM disk does not fit the RAM window'
        pieces.append((rd_va, rd_size, image))
        ramdisk = (rd_va - VIRT_BASE + PHYS_BASE, rd_size)

    adt_blob = pi_adt.build(PHYS_BASE, MEM_SIZE, cmdline, ramdisk)

    hdr_size = SEG_TABLE + 32 * len(pieces)
    out = bytearray(hdr_size)
    seg_table = []
    for vmaddr, vmsize, data in pieces:
        off = len(out)
        out += data
        out += b'\0' * (-len(out) & 0xf)
        seg_table.append((vmaddr, vmsize, off, len(data)))
    adt_off = len(out)
    out += adt_blob
    out += b'\0' * (-len(out) & 0xf)

    struct.pack_into('<8sII', out, 0, MAGIC, 1, len(pieces))
    struct.pack_into('<7Q', out, 0x10, VIRT_BASE, m['entry'], adt_off, len(adt_blob), kernel_end,
                     PHYS_BASE, MEM_SIZE)
    cl = cmdline.encode()[:BOOT_LINE_LENGTH - 1]
    out[CMDLINE:CMDLINE + len(cl)] = cl
    for i, t in enumerate(seg_table):
        struct.pack_into('<4Q', out, SEG_TABLE + 32 * i, *t)
    info = dict(entry=hex(m['entry']), kernel_end=hex(kernel_end), size=len(out),
                ramdisk=ramdisk and (hex(ramdisk[0]), hex(ramdisk[1])),
                segs=[(s['name'], hex(s['vmaddr']), hex(s['vmsize'])) for s in segs])
    return bytes(out), info


if __name__ == '__main__':
    ap = argparse.ArgumentParser()
    ap.add_argument('kernel')
    ap.add_argument('out')
    ap.add_argument('--ramdisk', help='image placed in RAM, boot with rd=md0')
    ap.add_argument('--cmdline', default='debug=0xc serial=3 cpus=1 keepsyms=1 kt_fixed_zones=120 -noprogress')
    a = ap.parse_args()
    blob, info = build(a.kernel, a.cmdline, a.ramdisk)
    open(a.out, 'wb').write(blob)
    for k, v in info.items():
        if k != 'segs':
            print(f'{k}: {v}')
    for s in info['segs']:
        print('  ', *s)
