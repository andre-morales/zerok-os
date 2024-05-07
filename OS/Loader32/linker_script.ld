ENTRY(_start)

SECTIONS {
	/* Beginning of all code and addresses at 0x3000 */
	. = 0x3000;
	NEAR_TEXT : {
		*(NEAR_TEXT*)
	}

	.text : {
		*(.text)
	}
	
	/* Align data/bss section at page boundary to separate RX sections from RW sections */
	.data : ALIGN(4096) {
		*(.data)
	}
}

