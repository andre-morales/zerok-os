/**
 * Head (Stage 2) Linker Script
 *
 * Author:   André Morales 
 * Creation: 30/04/2024
 * Modified: 05/05/2024
 **/
 
/* Specifies flat binary with no structure */
OUTPUT_FORMAT(binary)

/* All sections begin from 0x6000 onwards */
SECTIONS {
	. = 0x6000;
	
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

