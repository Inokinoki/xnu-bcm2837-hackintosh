/* Raspberry Pi firmware / QEMU raspi3b load address for AArch64 kernel images. */
ENTRY(_start)

SECTIONS
{
	. = 0x80000;
	.text : {
		KEEP(*(.text.start))
		*(.text .text.*)
	}
	.rodata : { *(.rodata .rodata.*) }
	.data : { *(.data .data.*) }
	.bss (NOLOAD) : {
		__bss_start = .;
		*(.bss .bss.*) *(COMMON)
		__bss_end = .;
	}
	. = ALIGN(16);
	. += 0x10000;
	__stack_top = .;
	/DISCARD/ : { *(.comment) *(.note*) }
}
