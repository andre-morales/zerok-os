OUTPUT_FORMAT(binary)

SECTIONS {
	. = 0x00;
	.text : {
		*(.text)
	}

	.bss : {
		*(.bss)
	}
}

