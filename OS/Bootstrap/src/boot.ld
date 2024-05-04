OUTPUT_FORMAT(binary)

SECTIONS {
	. = 0x7C00;
	.text : {
		*(.text)
	}
	
	. = 0x7E00;
	.bss : {
		*(.bss)
	}
}

