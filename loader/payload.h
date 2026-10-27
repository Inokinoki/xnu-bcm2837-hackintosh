/*
 * Payload layout shared by tools/mkpi_payload.py and loader/main.c.
 * All offsets are from the payload start; the loader reads it at PAYLOAD_PA.
 *
 *  0x000  char  magic[8] = "PIXNUPL1"
 *  0x008  u32   version = 1, nsegs
 *  0x010  u64   virt_base      kernel VA that maps to phys_base
 *  0x018  u64   entry_va       LC_UNIXTHREAD pc
 *  0x020  u64   adt_off, adt_size
 *  0x030  u64   kernel_end     end of the highest segment (page aligned VA)
 *  0x038  u64   phys_base      RAM given to the kernel
 *  0x040  u64   mem_size
 *  0x048  char  cmdline[608]
 *  0x2a8  seg[nsegs] { u64 vmaddr, vmsize, file_off, file_size }
 */
#pragma once
#include <stdint.h>

#define PAYLOAD_PA	0x3c000000UL
#define PAYLOAD_MAGIC	"PIXNUPL1"
#define BOOT_LINE_LENGTH	608
#define PAGE_16K	0x4000UL
#define PAGE_4K		0x1000UL

struct payload_seg {
	uint64_t vmaddr, vmsize, file_off, file_size;
};

struct payload {
	char magic[8];
	uint32_t version, nsegs;
	uint64_t virt_base, entry_va, adt_off, adt_size, kernel_end;
	uint64_t phys_base, mem_size;
	char cmdline[BOOT_LINE_LENGTH];
	struct payload_seg segs[];
};

/* pexpert/pexpert/arm64/boot.h, Revision/Version 2 */
struct boot_video {
	uint64_t v_baseAddr, v_display, v_rowBytes, v_width, v_height, v_depth;
};

struct boot_args {
	uint16_t Revision, Version;
	uint64_t virtBase, physBase, memSize, topOfKernelData;
	struct boot_video Video;
	uint32_t machineType;
	uint64_t deviceTreeP;
	uint32_t deviceTreeLength;
	char CommandLine[BOOT_LINE_LENGTH];
	uint64_t bootFlags, memSizeActual;
};
