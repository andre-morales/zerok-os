ENTRY(_start)

SECTIONS {
	. = 0x3000;
	NEAR_TEXT : {
		*(NEAR_TEXT*)
	}

	.text : {
		*(.text)
	}
}

