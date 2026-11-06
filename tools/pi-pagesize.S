/*
 * Page-size probe PID 1 for the 4K BCM2837 kernel: what does a userland
 * built for 16K pages (iOS) see? Prints hw.pagesize, whether a 4K mprotect and a
 * 16K-aligned mmap work, and the commpage page shifts. Position independent,
 * no relocations (tools/mkinit.py wraps it); raw XNU syscalls: x16 = number,
 * svc #0x80, carry set on error.
 */
#define SYS_exit	1
#define SYS_write	4
#define SYS_open	5
#define SYS_munmap	73
#define SYS_mprotect	74
#define SYS_mmap	197
#define SYS_sysctl	202
#define SYS_select	93

	.text
	.globl	_start
	.p2align 2
_start:
	mov	x9, sp
	and	x9, x9, #~15
	mov	sp, x9
	sub	sp, sp, #64

	adr	x0, path
	mov	x1, #2
	mov	x2, #0
	mov	x16, #SYS_open
	svc	#0x80
	b.cs	hang
	mov	x19, x0

	adr	x1, banner
	adr	x2, banner_end
	bl	say

	/* sysctl({CTL_HW, HW_PAGESIZE}, 2, &val, &len, NULL, 0) */
	mov	w0, #6
	mov	w1, #7
	stp	w0, w1, [sp, #0]
	mov	x0, sp
	mov	x1, #2
	add	x2, sp, #16
	str	xzr, [x2]
	mov	x3, #8
	str	x3, [sp, #24]
	add	x3, sp, #24
	mov	x4, #0
	mov	x5, #0
	mov	x16, #SYS_sysctl
	svc	#0x80
	adr	x1, l_pagesize
	adr	x2, l_pagesize_end
	bl	say
	ldr	x0, [sp, #16]
	bl	hex

	/* mmap(0, 64K, RW, MAP_ANON|MAP_PRIVATE, -1, 0) */
	mov	x0, #0
	mov	x1, #0x10000
	mov	x2, #3
	mov	x3, #0x1002
	mov	x4, #-1
	mov	x5, #0
	mov	x16, #SYS_mmap
	svc	#0x80
	mov	x20, x0
	adr	x1, l_mmap
	adr	x2, l_mmap_end
	bl	say
	mov	x0, x20
	bl	hex

	/* touch the first and last byte, then protect one 4K page inside a 16K block */
	mov	w1, #0x5a
	strb	w1, [x20]
	mov	x6, #0xffff
	strb	w1, [x20, x6]
	add	x0, x20, #0x1000
	mov	x1, #0x1000
	mov	x2, #1
	mov	x16, #SYS_mprotect
	svc	#0x80
	cset	x21, cs
	adr	x1, l_mprot
	adr	x2, l_mprot_end
	bl	say
	mov	x0, x21
	bl	hex

	/* commpage (TTBR0, 64-bit): user page shift +0x25, kernel page shift +0x37 */
	mov	x22, #0xc000
	movk	x22, #0xffff, lsl #16
	movk	x22, #0xf, lsl #32
	adr	x1, l_comm
	adr	x2, l_comm_end
	bl	say
	ldrb	w0, [x22, #0x25]
	bl	hex
	adr	x1, l_comm2
	adr	x2, l_comm2_end
	bl	say
	ldrb	w0, [x22, #0x37]
	bl	hex

	adr	x1, done
	adr	x2, done_end
	bl	say
tick:
	mov	x0, #0
	mov	x1, #0
	mov	x2, #0
	mov	x3, #0
	adr	x4, five_sec
	mov	x16, #SYS_select
	svc	#0x80
	b	tick

/* write(x19, x1, x2 - x1) */
say:
	sub	x2, x2, x1
	mov	x0, x19
	mov	x16, #SYS_write
	svc	#0x80
	ret

/* print x0 as 0x%016x\n */
hex:
	sub	sp, sp, #48
	mov	w1, #'0'
	strb	w1, [sp, #0]
	mov	w1, #'x'
	strb	w1, [sp, #1]
	mov	x2, #16
	mov	x3, #2
1:	sub	x2, x2, #1
	lsl	x4, x2, #2
	lsr	x5, x0, x4
	and	x5, x5, #15
	cmp	x5, #10
	b.lo	2f
	add	x5, x5, #('a' - '0' - 10)
2:	add	x5, x5, #'0'
	strb	w5, [sp, x3]
	add	x3, x3, #1
	cbnz	x2, 1b
	mov	w1, #10
	strb	w1, [sp, x3]
	add	x3, x3, #1
	mov	x0, x19
	mov	x1, sp
	mov	x2, x3
	mov	x16, #SYS_write
	svc	#0x80
	add	sp, sp, #48
	ret

hang:
	b	hang

	.p2align 3
five_sec:
	.quad	5
	.quad	0
path:
	.asciz	"/dev/console"
banner:
	.ascii	"\n*** BCM2837 page-size probe (PID 1) ***\n"
banner_end:
l_pagesize:
	.ascii	"hw.pagesize           = "
l_pagesize_end:
l_mmap:
	.ascii	"mmap 64K              = "
l_mmap_end:
l_mprot:
	.ascii	"mprotect 4K errored   = "
l_mprot_end:
l_comm:
	.ascii	"commpage user shift64 = "
l_comm_end:
l_comm2:
	.ascii	"commpage kernel shift = "
l_comm2_end:
done:
	.ascii	"*** probe done ***\n"
done_end:
