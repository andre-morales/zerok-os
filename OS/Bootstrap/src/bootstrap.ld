OUTPUT_FORMAT(binary)

SECTIONS {
	. = 0x500;
	
	.text : {
		*(.text)
	}
	
	.data : {
		*(.data)
	}

	.bss : {
		*(.bss)
	}
}