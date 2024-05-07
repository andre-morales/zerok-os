OUTPUT_FORMAT(binary)

SECTIONS {
	.text 0x0000 : {
		*(.text)
	}

	.rodata : {
		*(.rodata)
	}

	.data : {
		*(.data)
	}

	.bss : {
		*(.bss)
	}
	
	__alloc_base = ALIGN(0x10);
}

