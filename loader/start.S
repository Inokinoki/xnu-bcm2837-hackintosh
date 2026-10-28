/*
 * BCM2837 loader entry. QEMU's raspi3b (and the Pi firmware) start the image
 * at 0x80000 with x0 = DTB; the kernel wants EL1 with the MMU and caches off.
 * Park every core but 0, drop EL2 -> EL1 if needed, then run loader_main().
 */
	.section .text.start, "ax"
	.globl _start
_start:
	mrs	x1, mpidr_el1
	and	x1, x1, #3
	cbnz	x1, .Lpark

	/* Pi 3 generic timer: 19.2 MHz (loader_main measures the real rate and patches the ADT) */
	ldr	x1, =19200000
	msr	cntfrq_el0, x1

	mrs	x1, CurrentEL
	lsr	x1, x1, #2
	cmp	x1, #3
	b.ne	.Lel2

	/* EL3 -> EL2: non-secure, AArch64 lower levels, HVC enabled */
	mov	x1, #((1 << 10) | (1 << 8) | (1 << 0))	/* SCR_EL3: RW, HCE, NS */
	msr	scr_el3, x1
	mov	x1, #0x3c9			/* EL2h, DAIF masked */
	msr	spsr_el3, x1
	adr	x1, .Lel2
	msr	elr_el3, x1
	eret

.Lel2:
	mrs	x1, CurrentEL
	lsr	x1, x1, #2
	cmp	x1, #2
	b.ne	.Lel1

	/* EL2 -> EL1: AArch64 EL1, no traps, timer and counter reachable from EL1 */
	mov	x1, #(1 << 31)			/* HCR_EL2.RW */
	msr	hcr_el2, x1
	mov	x1, #0x33ff
	msr	cptr_el2, x1
	mrs	x1, cnthctl_el2
	orr	x1, x1, #3
	msr	cnthctl_el2, x1
	msr	cntvoff_el2, xzr
	ldr	x1, =0x30d00800			/* SCTLR_EL1 RES1 bits, M=C=I=0 */
	msr	sctlr_el1, x1
	mov	x1, #0x3c5			/* EL1h, DAIF masked */
	msr	spsr_el2, x1
	adr	x1, .Lel1
	msr	elr_el2, x1
	eret

.Lel1:
	ldr	x1, =0x30d00800
	msr	sctlr_el1, x1
	isb
	ldr	x1, =__stack_top
	mov	sp, x1

	/* zero .bss */
	ldr	x1, =__bss_start
	ldr	x2, =__bss_end
1:	cmp	x1, x2
	b.hs	2f
	str	xzr, [x1], #8
	b	1b
2:
	bl	loader_main			/* x0 = DTB, unused for now */

.Lpark:
	wfe
	b	.Lpark
