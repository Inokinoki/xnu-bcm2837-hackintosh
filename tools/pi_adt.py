#!/usr/bin/env python3
"""Minimal Apple Device Tree (ADT) for the Raspberry Pi 3 loader.

The firmware gives the loader a flattened DTB; xnu only reads an ADT. This
builds the handful of nodes the BCM2837 kernel config asks for. Serialization
matches the ADT layout used by ios-sweet's tools/adt.py:

  node = {u32 nprops, u32 nchildren, props..., children...}
  prop = {char name[32], u32 size (bit31 = placeholder), value padded to 4}
"""
import hashlib
import os
import struct


BCM283X_PERIPH_BASE = 0x3F000000
BCM283X_PERIPH_SIZE = 0x01000000
TIMEBASE_HZ = 19200000


class Node:
    def __init__(self, name):
        self.name = name
        self.props = []        # (name, flags, bytes)
        self.children = []

    def prop(self, name, value):
        if isinstance(value, str):
            value = value.encode() + b'\0'
        elif isinstance(value, int):
            value = struct.pack('<Q', value)
        self.props.append((name, 0, value))
        return self

    def child(self, name):
        n = Node(name)
        self.children.append(n)
        return n


def serialize(node):
    out = bytearray(struct.pack('<II', len(node.props), len(node.children)))
    for name, flags, val in node.props:
        out += name.encode().ljust(32, b'\0')[:32]
        out += struct.pack('<I', len(val) | (flags << 31))
        out += val + b'\0' * (-len(val) & 3)
    for c in node.children:
        out += serialize(c)
    return bytes(out)


def build(dram_base, dram_size, cmdline='', ramdisk=None, display=None, ios_dt=None):
    """Return the ADT blob for a Pi 3 with RAM at [dram_base, dram_base + dram_size).

    ramdisk=(phys, size) adds /chosen/memory-map RAMDisk (two uintptr_t) for
    IOFindBSDRoot / the md driver (boot-arg rd=md0).
    ios_dt=path of the iPhone X (D22AP) device tree makes the Pi look like that iPhone: root identity,
    /product, /buttons and the /chosen properties MobileGestalt reads (see tools/mkios-root.sh notes).
    """
    root = Node('device-tree')
    root.prop('name', 'device-tree')
    root.prop('compatible', 'raspberrypi,3-model-b')
    root.prop('model', 'Raspberry Pi 3 Model B')

    chosen = root.child('chosen')
    chosen.prop('name', 'chosen')
    chosen.prop('dram-base', dram_base)
    chosen.prop('dram-size', dram_size)
    chosen.prop('boot-args', cmdline)
    # 64 bytes, filled by the loader from the Pi's RNG before the kernel runs
    chosen.prop('random-seed', b'\x01' * 64)
    # mount -P 1 (launchd's mount boot task) requires /chosen/boot-manifest-hash (48 bytes, SHA-384)
    chosen.prop('boot-manifest-hash', hashlib.sha384(b'bcm2837 boot manifest').digest())

    if ios_dt:
        chosen.prop('crypto-hash-method', 'sha2-384')
        chosen.prop('display-scale', struct.pack('<I', 3))
        # XNU derives IOPlatformUUID (gethostuuid) from these; without it CFPreferences has no
        # ByHost files and DataMigration runs on every boot. Synthetic ECID; chip-id of the A11.
        chosen.prop('unique-chip-id', struct.pack('<Q', 0x4252434d32383337))	# 'BRCM2837'
        chosen.prop('chip-id', struct.pack('<I', 0x8015))
        # security status of a dev-fused board (MobileGestalt, mobileactivationd)
        for k, v in (('certificate-production-status', 0), ('effective-production-status-ap', 0),
                     ('certificate-security-mode', 1), ('effective-security-mode-sep', 1)):
            chosen.prop(k, struct.pack('<I', v))
        # local boot policy (kern_csr.c): SIP relaxed like csrutil disable, unsealed root
        asmb = chosen.child('asmb')
        asmb.prop('name', 'asmb')
        asmb.prop('lp-sip0', struct.pack('<Q', 0x6f))
        asmb.prop('lp-sip1', struct.pack('<I', 1))

    mmap = chosen.child('memory-map')
    mmap.prop('name', 'memory-map')
    if ramdisk:
        mmap.prop('RAMDisk', struct.pack('<2Q', *ramdisk))

    # pmap_compute_max_asids() looks up /defaults; its properties are optional.
    defaults = root.child('defaults')
    defaults.prop('name', 'defaults')
    # No effaceable storage: keybagd reads /private/var/keybags/systembag.kb as a plain plist.
    defaults.prop('no-effaceable-storage', struct.pack('<I', 1))

    # pe_arm_get_soc_base_phys(): the SoC base is ranges[1] of arm-io (the parent
    # address). Zero there disables the platform setup, including the timebase.
    arm_io = root.child('arm-io')
    arm_io.prop('name', 'arm-io')
    arm_io.prop('device_type', 'arm-io')
    arm_io.prop('ranges', struct.pack('<3Q', 0x0, BCM283X_PERIPH_BASE, BCM283X_PERIPH_SIZE))
    # watchdogd looks for /arm-io/wdt no-pmu (customer builds ignore -wdt_no_pmu).
    wdt = arm_io.child('wdt')
    wdt.prop('name', 'wdt')
    wdt.prop('no-pmu', struct.pack('<I', 1))
    if display:
        # IOMobileFramebuffer.framework counts /arm-io children with this device_type and reads the
        # canvas size; the kernel's AppleCLCD matches the compatible string.
        disp = arm_io.child('disp0')
        disp.prop('name', 'disp0')
        disp.prop('device_type', 'display-subsystem')
        disp.prop('compatible', 'bcm2837,display')
        disp.prop('canvas-width', struct.pack('<I', display[0]))
        disp.prop('canvas-height', struct.pack('<I', display[1]))

    # pe_identify_machine(): a running CPU supplies the timebase frequency.
    cpus = root.child('cpus')
    cpus.prop('name', 'cpus')
    cpu0 = cpus.child('cpu0')
    cpu0.prop('name', 'cpu0')
    cpu0.prop('device_type', 'cpu')
    cpu0.prop('compatible', 'arm,cortex-a53')
    cpu0.prop('state', 'running')
    cpu0.prop('reg', struct.pack('<I', 0))
    cpu0.prop('timebase-frequency', struct.pack('<I', TIMEBASE_HZ))
    # Cores 1-3 sit in the loader's spin table; the loader writes each cpu-release-addr.
    for n in (1, 2, 3):
        c = cpus.child(f'cpu{n}')
        c.prop('name', f'cpu{n}')
        c.prop('device_type', 'cpu')
        c.prop('compatible', 'arm,cortex-a53')
        c.prop('state', 'stopped')
        c.prop('reg', struct.pack('<I', n))
        c.prop('timebase-frequency', struct.pack('<I', TIMEBASE_HZ))
        c.prop('cpu-release-addr', struct.pack('<Q', 0))

    if ios_dt:
        import adt
        root.props = [pr for pr in root.props if pr[0] not in ('compatible', 'model')]
        # compatible[0] is hw.model/hw.target (D22AP), model is hw.machine/hw.product (iPhone10,3);
        # the Pi's own name stays so BCM2837PlatformExpert still matches.
        root.props.append(('compatible', 0, b'D22AP\0iPhone10,3\0raspberrypi,3-model-b\0AppleARM\0'))
        root.prop('model', 'iPhone10,3')
        root.prop('target-type', 'D22')
        root.prop('target-sub-type', 'D22AP')
        root.prop('manufacturer', 'Apple Inc.')
        buttons = root.child('buttons')
        buttons.prop('name', 'buttons')
        buttons.prop('button-names', b'volup\0voldown\0hold\0')
        buttons.prop('home-button-type', struct.pack('<I', 2))
        buttons.prop('opposed-power-vol-buttons', struct.pack('<I', 1))
        real, _ = adt.parse(open(ios_dt, 'rb').read())
        for c in real.children:
            if dict((k, v) for k, f, v in c.props).get('name') == b'product\0':
                product = root.child('product')
                product.prop('name', 'product')
                for k, f, v in c.props:
                    if not f and k not in ('name', 'AAPL,phandle'):
                        product.props.append((k, 0, v))
                break
        else:
            raise SystemExit(f'{ios_dt}: no /product node')
    return serialize(root)
