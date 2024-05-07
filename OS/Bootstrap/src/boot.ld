/**
 * Boot (Stage 1) Linker Script
 *
 * Author:   André Morales 
 * Creation: 04/05/2024
 * Modified: 06/05/2024
 **/

/* Flat raw binary */
OUTPUT_FORMAT(binary)

SECTIONS {
	/* All code and data starts relative to 0x7C00 */
	.text 0x7C00 : {
		*(.text)
	}

	.data : {
		*(.data)
	}
	
	/* Save how many bytes were written in the bootsector */
	__code_size = . - ADDR(.text);
	
	/* Fill the rest of the bootsector with no-ops (0x90)
	followed by the bootable magic number */
	.fill : {
		FILL(0x90);	
		. = 510 - (__code_size);
		SHORT(0xAA55);
	}
	
	/* Unitialized variable space is relative to 0x7E00 */
	.bss 0x7E00 : {
		*(.bss)
	}
}

