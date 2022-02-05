ENTRY(_start)

SECTIONS{
	. = 0x03000;
	.text : ALIGN(4K){
		*(.text)
	}
}

