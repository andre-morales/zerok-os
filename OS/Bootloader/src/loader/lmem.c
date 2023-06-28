#include "lmem.h"
#include <stdint.h>

/**
 * Maps a physical memory area to a given address space.
 *
 * Ex: memMap(0x1, 0xA0)
 * 0x1006 -> 0xA0006
 **/
void memMap(int virtual, int physical){
	void* const PAGE_TABLE = 0x2000;
	const uint32_t flags = 0b000000010111;

	uint32_t entry = flags + physical * 4096;
	uint32_t* ptr = (uint32_t*)(PAGE_TABLE + virtual * 4);

	*ptr = entry;
}

void memReloadPageDir(){
	asm volatile ("movl %%cr3, %%eax;\n\t"
		"movl %%eax, %%cr3; \n\t" : : : "eax");
}
