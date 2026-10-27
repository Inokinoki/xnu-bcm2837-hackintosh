#!/usr/bin/env python3
"""Minimal Apple Device Tree (ADT) for the Raspberry Pi 3 loader.

The firmware gives the loader a flattened DTB; xnu only reads an ADT. This
builds the handful of nodes the BCM2837 kernel config asks for. Serialization
matches the ADT layout used by ios-sweet's tools/adt.py:

  node = {u32 nprops, u32 nchildren, props..., children...}
  prop = {char name[32], u32 size (bit31 = placeholder), value padded to 4}
"""
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


def build(dram_base, dram_size, cmdline=''):
    """Return the ADT blob for a Pi 3 with RAM at [dram_base, dram_base + dram_size)."""
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

    mmap = chosen.child('memory-map')
    mmap.prop('name', 'memory-map')

    # pe_arm_get_soc_base_phys(): the SoC base is ranges[1] of arm-io (the parent
    # address). Zero there disables the platform setup, including the timebase.
    arm_io = root.child('arm-io')
    arm_io.prop('name', 'arm-io')
    arm_io.prop('device_type', 'arm-io')
    arm_io.prop('ranges', struct.pack('<3Q', 0x0, BCM283X_PERIPH_BASE, BCM283X_PERIPH_SIZE))

    # pe_identify_machine(): a running CPU supplies the timebase frequency.
    cpus = root.child('cpus')
    cpus.prop('name', 'cpus')
    cpu0 = cpus.child('cpu0')
    cpu0.prop('name', 'cpu0')
    cpu0.prop('state', 'running')
    cpu0.prop('reg', struct.pack('<I', 0))
    cpu0.prop('timebase-frequency', struct.pack('<I', TIMEBASE_HZ))

    return serialize(root)
