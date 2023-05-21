#include "core.h"
#include "vga_video.h"
#include "string.h"
#include "stdio.h"

extern char loader_args[2];

void main(){
	// Load stuff passed by previous stages
	loadInitStructure(loader_args);
		
	// Setup vga video
	video_init();
	video.cur_x = 0;
	video.cur_y = 24;

	print("\n\n-- ZkLoader 32 --");
	print("\nReached protected mode.");
	print("\nBinary version 2.");
}

void loadInitStructure(uint8_t* args){
	video.columns = args[0];
	video.mode = args[1];
}

void map(int virtual, int physical){
	void* const PAGE_TABLE = (void*)0x2000;

	uint32_t flags = 0b000000010111;
	uint32_t entry = flags + physical * 4096;

	uint32_t* ptr = (uint32_t*)(PAGE_TABLE + virtual * 4);

	*ptr = entry;
	reload_page_directory();	
}

void breakpoint() {
	asm volatile ("xchg %bx, %bx");
}

void reload_page_directory(){
	asm volatile ("movl %%cr3, %%eax;\n\t"
		"movl %%eax, %%cr3; \n\t" : : : "eax");
}
