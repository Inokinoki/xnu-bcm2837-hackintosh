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

#define mmio_w(a, v)	(*(volatile uint32_t *)(a) = (uint32_t)(v))
#define mmio_r(a)	(*(volatile uint32_t *)(a))

/* Kernel placement: virt_base is 32 MB below the Mach-O header (16K L2 block). */
#define KERNEL_VIRT_BASE	0xffffffe006000000ULL
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

static int magic_ok(const char *m)
{
	static const char want[] = PAYLOAD_MAGIC;
	for (int i = 0; i < 8; i++)
		if (m[i] != want[i])
			return 0;
	return 1;
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
	ba->Video.v_display = 0;		/* no framebuffer on this path yet */
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
