/**
 * Boostrap (Stage 3) Linker Script
 *
 * Author:   André Morales 
 * Creation: 04/05/2024
 * Modified: 06/05/2024
 *
 * :: Physical Memory Map ::
 * -- [  0  -  500] IVT and BIOS Data Area
 * -- [ 500 -  520] GDT Structures
 * -- [ 700 -   # ] Stage 3 (us)
 * -- [1200 -   # ] FAT16 Cluster Buffer
 * -- [2000 -   # ] Stage 4 file will be loaded here
 * -- [3000 -  ...] Stage 4 code starts here
 * -- [ ... - 7FF0] Stack
 */

OUTPUT_FORMAT(binary)

SECTIONS {

	/* GDT structures at 0x500 specifically of 0x200 size */
	.text 0x500 : {
		*(.gdt)
		FILL(0x00);
		. = 0x200;
	}
	
	/* Beginning of actual code at 0x700 */
	.text 0x700 : {
		*(.text)
	}
	
	.data : {
		*(.data)
	}

	.bss : {
		*(.bss)
	}
	
	/* Reserve space in the virtual memory for the FAT16 reader cluster buffer.
	   Align it on a 256 byte boundary. */
	.cluster_buffer ALIGN(0x100) : {
		__fat16_cluster_buffer_addr = .;
		. += 4 * 512;
	}
	
	/* Reserve space for the Loader32 file. Align the file and its executable contents
	   on a page boundary */
	.loader32_file ALIGN(4K) : {
		__loader32_file_addr = .;
		. += 4K;
		__loader32_start_addr = .;
	}
}