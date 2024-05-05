/**
 * Boot (Stage 1) Linker Script
 *
 * Author:   André Morales 
 * Creation: 04/05/2024
 * Modified: 05/05/2024
 **/

/* Flat raw binary */
OUTPUT_FORMAT(binary)

SECTIONS {
	/* All code starting relative to 0x7C00 */
	. = 0x7C00;
	.text : {
		*(.text)
	}
	
	/* Unitialized variables and data relative to 0x7E00 */
	. = 0x7E00;
	.bss : {
		*(.bss)
	}
}

