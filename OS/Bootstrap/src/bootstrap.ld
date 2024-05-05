/**
 * Boostrap (Stage 3) Linker Script
 *
 * Author:   André Morales 
 * Creation: 04/05/2024
 * Modified: 05/05/2024
 **/

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