/*
 * Raspberry Pi 3 (BCM2837) loader: copy the xnu kernel that tools/mkpi_payload.py
 * packed at PAYLOAD_PA into RAM, build boot_args and a minimal ADT behind it, and
 * jump to the kernel's entry point with the MMU and caches off, x0 = boot_args.
 */
#include <stdint.h>
#include "payload.h"

#define MMIO_BASE	0x3f000000UL
#define AUX_ENABLES	(MMIO_BASE + 0x215004)
#define AUX_MU_IO	(MMIO_BASE + 0x215040)
#define AUX_MU_IER	(MMIO_BASE + 0x215044)
#define AUX_MU_IIR	(MMIO_BASE + 0x215048)
#define AUX_MU_LCR	(MMIO_BASE + 0x21504c)
#define AUX_MU_MCR	(MMIO_BASE + 0x215050)
#define AUX_MU_LSR	(MMIO_BASE + 0x215054)
#define AUX_MU_CNTL	(MMIO_BASE + 0x215060)
#define AUX_MU_BAUD	(MMIO_BASE + 0x215068)
#define GPFSEL1		(MMIO_BASE + 0x200004)
#define GPPUD		(MMIO_BASE + 0x200094)
#define GPPUDCLK0	(MMIO_BASE + 0x200098)

#define MBOX_BASE	(MMIO_BASE + 0xb880)
#define MBOX_READ	(MBOX_BASE + 0x00)
#define MBOX_STATUS	(MBOX_BASE + 0x18)
#define MBOX_WRITE	(MBOX_BASE + 0x20)
#define MBOX_FULL	0x80000000u
#define MBOX_EMPTY	0x40000000u

#define ST_CLO		(MMIO_BASE + 0x3004)	/* BCM2835 system timer, 1 MHz */

#define RNG_BASE	(MMIO_BASE + 0x104000)
#define RNG_CTRL	(RNG_BASE + 0x00)
#define RNG_STATUS	(RNG_BASE + 0x04)
#define RNG_DATA	(RNG_BASE + 0x08)

#define mmio_w(a, v)	(*(volatile uint32_t *)(a) = (uint32_t)(v))
#define mmio_r(a)	(*(volatile uint32_t *)(a))

/* Kernel placement: virt_base is 32 MB below the Mach-O header (16K L2 block). */
#define KERNEL_VIRT_BASE	0xfffffff006000000ULL
#define KERNEL_PHYS_BASE	0x10000000ULL
#define KERNEL_MEM_SIZE		0x2c000000ULL	/* 0x10000000..0x3c000000, below the payload */

static void uart_init(void)
{
	mmio_w(AUX_ENABLES, 1);
	mmio_w(AUX_MU_CNTL, 0);
	mmio_w(AUX_MU_LCR, 3);
	mmio_w(AUX_MU_MCR, 0);
	mmio_w(AUX_MU_IER, 0);
	mmio_w(AUX_MU_IIR, 0xc6);
	mmio_w(AUX_MU_BAUD, 270);
	uint32_t r = mmio_r(GPFSEL1);
	r &= ~((7u << 12) | (7u << 15));
	r |= (2u << 12) | (2u << 15);		/* GPIO14/15 = ALT5 */
	mmio_w(GPFSEL1, r);
	mmio_w(GPPUD, 0);
	for (volatile int i = 0; i < 150; i++) ;
	mmio_w(GPPUDCLK0, (1u << 14) | (1u << 15));
	for (volatile int i = 0; i < 150; i++) ;
	mmio_w(GPPUDCLK0, 0);
	mmio_w(AUX_MU_CNTL, 3);
}

static void uart_putc(char c)
{
	while (!(mmio_r(AUX_MU_LSR) & 0x20)) ;
	mmio_w(AUX_MU_IO, (uint8_t)c);
}

static void uart_puts(const char *s)
{
	while (*s) {
		if (*s == '\n')
			uart_putc('\r');
		uart_putc(*s++);
	}
}

static void uart_hex(uint64_t v)
{
	uart_puts("0x");
	for (int i = 60; i >= 0; i -= 4) {
		int d = (v >> i) & 0xf;
		uart_putc(d < 10 ? '0' + d : 'a' + d - 10);
	}
}

static void uart_line(const char *label, uint64_t v)
{
	uart_puts("[loader] ");
	uart_puts(label);
	uart_puts(" ");
	uart_hex(v);
	uart_puts("\n");
}

/* Memory is Device-nGnRnE until the kernel turns its MMU on: word accesses only. */
static void copy64(uintptr_t dst, uintptr_t src, uint64_t n)
{
	volatile uint64_t *d = (volatile uint64_t *)dst;
	volatile const uint64_t *s = (volatile const uint64_t *)src;
	for (uint64_t i = 0; i < (n + 7) / 8; i++)
		d[i] = s[i];
}

static void zero64(uintptr_t dst, uint64_t n)
{
	volatile uint64_t *d = (volatile uint64_t *)dst;
	for (uint64_t i = 0; i < (n + 7) / 8; i++)
		d[i] = 0;
}

/*
 * Fill the 64-byte /chosen/random-seed the kernel's PRNG needs. The BCM2835 RNG
 * is used when it produces data; otherwise a counter-based mix, which is NOT
 * secure and only for bring-up.
 */
static uint64_t cntpct(void)
{
	uint64_t v;
	__asm__ volatile("mrs %0, cntpct_el0" : "=r"(v));
	return v;
}

static void fill_seed(uint8_t *dst, uint32_t n)
{
	mmio_w(RNG_STATUS, 0x40000);
	mmio_w(RNG_CTRL, 1);
	int hw = 1;
	for (uint32_t i = 0; i < n; i += 4) {
		uint32_t w = 0;
		uint32_t tries = 0;
		while (!(mmio_r(RNG_STATUS) >> 24) && tries++ < 0x100000) ;
		if (!(mmio_r(RNG_STATUS) >> 24)) {
			hw = 0;
			break;
		}
		w = mmio_r(RNG_DATA);
		for (int k = 0; k < 4 && i + k < n; k++)
			dst[i + k] = (w >> (8 * k)) | 1;	/* never zero: the kernel rejects all-null seeds */
	}
	if (!hw) {
		uint64_t x = cntpct() ^ 0x9e3779b97f4a7c15ULL;
		for (uint32_t i = 0; i < n; i++) {
			x ^= x << 13; x ^= x >> 7; x ^= x << 17;
			dst[i] = (uint8_t)(x | 1);
		}
		uart_puts("[loader] random-seed: counter fallback (not secure)\n");
	} else {
		uart_puts("[loader] random-seed: BCM2835 RNG\n");
	}
}

/* Find the copied ADT's "random-seed" property and fill its value. */

/*
 * The generic counter runs at 19.2 MHz on a Pi 3 but at 62.5 MHz in QEMU, whatever CNTFRQ says.
 * Measure it against the 1 MHz system timer so the ADT carries the real rate: with a wrong
 * timebase every kernel and userland timeout is off by that factor.
 */
static uint32_t measure_timebase(void)
{
	uint64_t c0, c1;
	uint32_t t0, t1;
	__asm__ volatile("isb; mrs %0, cntpct_el0" : "=r"(c0));
	t0 = mmio_r(ST_CLO);
	do {
		t1 = mmio_r(ST_CLO);
	} while (t1 - t0 < 5000);		/* 5 ms */
	__asm__ volatile("isb; mrs %0, cntpct_el0" : "=r"(c1));
	uint64_t hz = (c1 - c0) * 1000000ull / (t1 - t0);
	if (hz > 17000000 && hz < 21000000)
		return 19200000;
	if (hz > 56000000 && hz < 69000000)
		return 62500000;
	return (uint32_t)((hz + 500) / 1000 * 1000);
}

static void patch_u32_prop(uintptr_t adt, uint64_t size, const char *name, uint32_t value)
{
	const uint8_t *b = (const uint8_t *)adt;
	int n = 0;
	while (name[n]) n++;
	for (uint64_t i = 0; i + 32 + 4 + 4 <= size; i += 4) {
		int hit = 1;
		for (int k = 0; k < n; k++)
			if (b[i + k] != (uint8_t)name[k]) { hit = 0; break; }
		if (hit && b[i + n] == 0 && (*(const uint32_t *)(adt + i + 32) & 0x7fffffff) == 4) {
			*(volatile uint32_t *)(adt + i + 36) = value;
			return;
		}
	}
	uart_puts("[loader] no timebase-frequency property in the ADT\n");
}

static void seed_adt(uintptr_t adt, uint64_t size)
{
	static const char name[] = "random-seed";
	const uint8_t *b = (const uint8_t *)adt;
	for (uint64_t i = 0; i + 32 + 4 + 64 <= size; i += 4) {
		int hit = 1;
		for (int k = 0; name[k]; k++)
			if (b[i + k] != (uint8_t)name[k]) { hit = 0; break; }
		if (hit && b[i + 11] == 0) {
			uint32_t len = *(const uint32_t *)(adt + i + 32);
			if ((len & 0x7fffffff) == 64) {
				fill_seed((uint8_t *)(adt + i + 36), 64);
				return;
			}
		}
	}
	uart_puts("[loader] no random-seed property in the ADT\n");
}

static int magic_ok(const char *m)
{
	static const char want[] = PAYLOAD_MAGIC;
	for (int i = 0; i < 8; i++)
		if (m[i] != want[i])
			return 0;
	return 1;
}


/* ---- VideoCore framebuffer (mailbox property channel), enabled by "fb=WxH" in the boot-args ---- */
static volatile uint32_t mbox[64] __attribute__((aligned(16)));

static int mbox_call(void)
{
	uint32_t r = ((uint32_t)(uintptr_t)mbox & ~0xfu) | 8;	/* channel 8: ARM to VC property tags */
	for (unsigned t = 0; mmio_r(MBOX_STATUS) & MBOX_FULL; t++)
		if (t > 10000000) return 0;
	mmio_w(MBOX_WRITE, r);
	for (unsigned t = 0; t < 10000000; t++) {
		if (mmio_r(MBOX_STATUS) & MBOX_EMPTY)
			continue;
		if (mmio_r(MBOX_READ) == r)
			return mbox[1] == 0x80000000u;
	}
	return 0;
}

static unsigned parse_dec(const char **pp)
{
	unsigned v = 0;
	while (**pp >= '0' && **pp <= '9')
		v = v * 10 + (unsigned)(*(*pp)++ - '0');
	return v;
}

/* Find "fb=WxH" in the command line. */
static int find_fb_size(const char *cl, unsigned *w, unsigned *h)
{
	for (const char *start = cl; *cl; cl++) {
		if (cl[0] == 'f' && cl[1] == 'b' && cl[2] == '=' && (cl == start || cl[-1] == ' ')) {
			const char *q = cl + 3;
			*w = parse_dec(&q);
			if (*q != 'x')
				return 0;
			q++;
			*h = parse_dec(&q);
			return *w && *h;
		}
	}
	return 0;
}

struct fbinfo {
	uint64_t base, pitch;
	unsigned w, h;
};

/* Boot-arg fbtest=1: draw a calibration pattern from the loader and stop (display path check). */
static int has_arg(const char *cl, const char *arg)
{
	for (const char *start = cl; *cl; cl++) {
		int n = 0;
		while (arg[n] && cl[n] == arg[n]) n++;
		if (!arg[n] && (cl == start || cl[-1] == ' '))
			return 1;
	}
	return 0;
}

static void fb_pattern(const struct fbinfo *fb)
{
	for (unsigned y = 0; y < fb->h; y++) {
		volatile uint32_t *row = (volatile uint32_t *)(uintptr_t)(fb->base + (uint64_t)y * fb->pitch);
		for (unsigned x = 0; x < fb->w; x++) {
			uint32_t c = 0xff202020;
			if ((x % 125) == 0 || (y % 125) == 0)
				c = 0xff506090;
			if (x == fb->w / 2 || y == fb->h / 2)
				c = 0xffff00ff;
			if (x < 4 || y < 4 || x >= fb->w - 4 || y >= fb->h - 4)
				c = 0xffffffff;
			else if (x < 104 && y < 104)
				c = 0xffff0000;
			else if (x >= fb->w - 104 && y < 104)
				c = 0xff00ff00;
			else if (x < 104 && y >= fb->h - 104)
				c = 0xff0000ff;
			else if (x >= fb->w - 104 && y >= fb->h - 104)
				c = 0xffffff00;
			row[x] = c;
		}
	}
}

static int fb_init(unsigned w, unsigned h, struct fbinfo *fb)
{
	unsigned i = 0;
	mbox[i++] = 0; mbox[i++] = 0;				/* size (patched), request */
	mbox[i++] = 0x00048003; mbox[i++] = 8; mbox[i++] = 8; mbox[i++] = w; mbox[i++] = h;	/* physical w/h */
	mbox[i++] = 0x00048004; mbox[i++] = 8; mbox[i++] = 8; mbox[i++] = w; mbox[i++] = h;	/* virtual w/h */
	mbox[i++] = 0x00048005; mbox[i++] = 4; mbox[i++] = 4; mbox[i++] = 32;		/* depth */
	mbox[i++] = 0x00048006; mbox[i++] = 4; mbox[i++] = 4; mbox[i++] = 0;		/* pixel order: BGR (B first in memory) */
	unsigned alloc = i;
	mbox[i++] = 0x00040001; mbox[i++] = 8; mbox[i++] = 8; mbox[i++] = 16; mbox[i++] = 0;	/* allocate: align, -> base, size */
	unsigned pitch = i;
	mbox[i++] = 0x00040008; mbox[i++] = 4; mbox[i++] = 4; mbox[i++] = 0;		/* pitch */
	mbox[i++] = 0;						/* end tag */
	mbox[0] = i * 4;
	if (!mbox_call())
		return 0;
	fb->base = mbox[alloc + 3] & 0x3fffffffu;		/* bus address -> ARM physical */
	fb->pitch = mbox[pitch + 3];
	fb->w = w;
	fb->h = h;
	return fb->base != 0 && fb->pitch >= w * 4;
}

typedef void (*kernel_entry_t)(uint64_t boot_args_pa);

void loader_main(uint64_t dtb)
{
	(void)dtb;
	uart_init();
	uart_puts("\n[loader] PIXNU loader, BCM2837\n");

	const struct payload *p = (const struct payload *)PAYLOAD_PA;
	if (!magic_ok(p->magic)) {
		uart_puts("[loader] no payload at PAYLOAD_PA\n");
		return;
	}
	if (p->version != 1) {
		uart_puts("[loader] payload version mismatch\n");
		return;
	}
	uint64_t pa_of_va = p->phys_base - p->virt_base;	/* pa = va + this */
	uart_line("virt_base", p->virt_base);
	uart_line("phys_base", p->phys_base);
	uart_line("entry_va", p->entry_va);
	uart_line("nsegs", p->nsegs);

	if (p->phys_base != KERNEL_PHYS_BASE || p->virt_base != KERNEL_VIRT_BASE) {
		uart_puts("[loader] payload placement does not match this loader\n");
		return;
	}

	for (uint32_t i = 0; i < p->nsegs; i++) {
		const struct payload_seg *s = &p->segs[i];
		uintptr_t dst = s->vmaddr + pa_of_va;
		copy64(dst, (uintptr_t)p + s->file_off, s->file_size);
		if (s->vmsize > s->file_size)
			zero64(dst + ((s->file_size + 7) & ~7UL), s->vmsize - ((s->file_size + 7) & ~7UL));
	}
	uart_line("segments copied, kernel_end", p->kernel_end + pa_of_va);

	/* ADT, then boot_args, right behind the kernel; everything below topOfKernelData is ours. */
	uintptr_t adt_pa = p->kernel_end + pa_of_va;
	copy64(adt_pa, (uintptr_t)p + p->adt_off, p->adt_size);
	seed_adt(adt_pa, p->adt_size);
	uint32_t tb = measure_timebase();
	uart_line("timebase", tb);
	patch_u32_prop(adt_pa, p->adt_size, "timebase-frequency", tb);
	uintptr_t ba_pa = (adt_pa + p->adt_size + PAGE_16K - 1) & ~(PAGE_16K - 1);
	uintptr_t top = ba_pa + PAGE_16K;

	zero64(ba_pa, PAGE_16K);
	volatile struct boot_args *ba = (volatile struct boot_args *)ba_pa;
	ba->Revision = 2;
	ba->Version = 2;
	ba->virtBase = p->virt_base;
	ba->physBase = p->phys_base;
	ba->memSize = p->mem_size;
	ba->topOfKernelData = top;
	ba->Video.v_display = 0;
	{
		unsigned fw, fh;
		struct fbinfo fb;
		if (find_fb_size(p->cmdline, &fw, &fh) && fb_init(fw, fh, &fb)) {
			/* QEMU places the payload where the VideoCore RAM starts: start from a black screen */
			zero64(fb.base, fb.pitch * fb.h);
			if (has_arg(p->cmdline, "fbtest=1")) {
				fb_pattern(&fb);
				uart_line("fbtest pattern drawn, pitch", fb.pitch);
				for (;;)
					__asm__ volatile("wfe");
			}
			uart_line("framebuffer", fb.base);
			uart_line("fb pitch", fb.pitch);
			ba->Video.v_baseAddr = fb.base;
			ba->Video.v_display = 1;
			ba->Video.v_rowBytes = fb.pitch;
			ba->Video.v_width = fb.w;
			ba->Video.v_height = fb.h;
			ba->Video.v_depth = 32;
		} else {
			uart_puts("[loader] no framebuffer\n");
		}
	}
	ba->machineType = 0;
	ba->deviceTreeP = adt_pa - pa_of_va;	/* xnu reads it with the MMU on: a VA */
	ba->deviceTreeLength = (uint32_t)p->adt_size;
	for (int i = 0; i < BOOT_LINE_LENGTH; i++)
		ba->CommandLine[i] = p->cmdline[i];
	ba->memSizeActual = p->mem_size;
	uart_line("boot_args", ba_pa);
	uart_line("jump", p->entry_va + pa_of_va);

	__asm__ volatile("dsb sy; ic iallu; dsb sy; isb" ::: "memory");
	((kernel_entry_t)(p->entry_va + pa_of_va))(ba_pa);
	uart_puts("[loader] kernel returned\n");
}
