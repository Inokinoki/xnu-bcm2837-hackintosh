/*
 * BCM2837 loader entry. QEMU's raspi3b (and the Pi firmware) start the image
 * at 0x80000 with x0 = DTB; the kernel wants EL1 with the MMU and caches off.
 * Every core drops to EL1 here (QEMU starts all four at this entry, at EL3; on the real
 * Pi the firmware parks cores 1-3 in a spin table and loader_main() sends them here).
 * Core 0 runs loader_main(); cores 1-3 wait in .Lsecondary at EL1 with the MMU off for
 * xnu to write the physical address of its reset handler into secondary_release[core]
 * (xnu's BCM2837CPU::startCPU), then jump to it.
 */
	.section .text.start, "ax"
	.globl _start
_start:
	mrs	x1, CurrentEL
	lsr	x1, x1, #2
	cmp	x1, #3
	b.ne	.Lel2

	/* EL3 only (QEMU): the generic timer frequency register and the A53 SMP bit are EL3 state.
	 * The Pi firmware does both before it hands over at EL2. */
	ldr	x1, =19200000
	msr	cntfrq_el0, x1
	mrs	x1, S3_1_C15_C2_1		/* CPUECTLR_EL1 */
	orr	x1, x1, #(1 << 6)		/* SMPEN: the core takes part in coherency */
	msr	S3_1_C15_C2_1, x1

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
	mrs	x1, mpidr_el1
	and	x1, x1, #3
	cbnz	x1, .Lsecondary
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

/*
 * Cores 1-3: no stack, MMU and caches off, EL1. Wait for xnu to publish the physical address of
 * its reset handler in secondary_release[core] (device-ordered reads see the RAM value; xnu
 * writes it through an uncached mapping), then jump there like a firmware release would.
 */
.Lsecondary:
	ldr	x2, =secondary_release
	add	x2, x2, x1, lsl #3
1:	ldr	x3, [x2]
	cbnz	x3, 2f
	wfe
	b	1b
2:	dsb	sy
	isb
	mov	x0, xzr
	br	x3

.Lpark:
	wfe
	b	.Lpark
