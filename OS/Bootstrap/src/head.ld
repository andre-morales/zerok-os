OUTPUT_FORMAT(binary)

SECTIONS {
	. = 0x6000;
	
	.text : {
		*(.text)
	}
	
	.data : {
		*(.data)
	}
}

