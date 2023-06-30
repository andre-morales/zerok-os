#include "lmem.h"
#include <stdint.h>

/**
 * Maps a physical memory area to a given address space.
 *
 * Ex: memMap(0x1, 0xA0)
 * 0x1006 -> 0xA0006
 **/
void memMap(int virt, int physical) {
	uint32_t* PAGE_TABLE = (uint32_t*)0x2000;
	const uint32_t flags = 0b000000010111;

	uint32_t entry = flags + physical * 4096;
	uint32_t* ptr = (uint32_t*)(PAGE_TABLE + virt * 4);

	*ptr = entry;
}

void memReloadPageDir() {
	__asm __volatile (
		"movl %%cr3, %%eax;\n\t"
		"movl %%eax, %%cr3; \n\t"
			:       // Inputs
			:       // Outputs
			: "eax" // Clobbers
	);
}