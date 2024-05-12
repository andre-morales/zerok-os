/**
 * Author:   André Morales 
 * Version:  1.1.4
 * Creation: 05/05/2024
 * Modified: 08/05/2024
 *
 * :: Memory Map ::
 * -- [0x0500 - 0x0A00] Stack
 * -- [0x0A00 - 0x1A00] Loaded stage 2
 * -- [0x2000] Drive buffer
 */
OUTPUT_FORMAT(binary)

SECTIONS {
	__code_segment = 0xA0;
	__data_segment = 0xA0;
	__stack_segment = 0x00;

	.text 0x0000 : {
		*(.text)
	}

	.rodata : {
		*(.rodata)
	}

	.data : {
		*(.data)
	}

	.bss : {
		*(.bss)
	}
	
	__alloc_base = ALIGN(0x10);
}

