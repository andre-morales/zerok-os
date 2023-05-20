#include "core.h"

struct Video video;

void main(void* args){
	loadArgs(args);
	video_init();
	video.cur_y = 24;

	print("\n\n-- ZkLoader 32 --");
	print("\nReached protected mode.");
	print("\nBinary version 2.");
}

void loadArgs(void* args){
	uint8_t* cargs = (uint8_t*) args;
	video.columns = cargs[0];
	video.mode = cargs[1];
	video.cur_x = 0;
	video.cur_y = 0;
}

void video_init(){
	int page;
	if(video.mode == 7){
		page = 0xB0;
	} else {
		page = 0xB8;
	}

	// Identity map VRAM
	map(0xA0, page);
	video.vram = (void*)(0xA0 * 0x1000);
}

void video_scroll(int lines){
	if(lines == 0) return;
	if(lines > 0){
		// Copy
		void* dst = video.vram;
		const void* src = video.vram + video.columns * lines * 2;
		uint32_t len = video.columns * (25 - lines) * 2;
		memmove(dst, src, len);

		// Blank last lines
		uint8_t* clr_dst = video.vram + video.columns * (25 - lines) * 2;
		uint32_t clr_len = video.columns * lines;
		while(clr_len--){
			*(clr_dst++) = 0;
			*(clr_dst++) = 7;
		}
	}
}

void map(int virtual, int physical){
	void* const PAGE_TABLE = (void*)0x2000;

	uint32_t flags = 0b000000010111;
	uint32_t entry = flags + physical * 4096;

	uint32_t* ptr = (uint32_t*)(PAGE_TABLE + virtual * 4);

	*ptr = entry;
	reload_page_directory();	
}

void reload_page_directory(){
	asm volatile ("movl %%cr3, %%eax;\n\t"
		"movl %%eax, %%cr3; \n\t" : : : "eax");
}

/* stdio.h */
void print(const char* msg){
	char c;
	while(c = *msg){
		putch(c);
		msg++;
	}
}

void putch(char c){
	if(c == '\n'){
		video.cur_x = 0;
		video.cur_y++;
	} else {
		uint8_t* vram = (uint8_t*)video.vram;

		int offset = video.cur_y * video.columns + video.cur_x;
		vram[offset * 2] = c;

		if(++video.cur_x >= video.columns){
			video.cur_x = 0;
			video.cur_y++;
		}
	}

	if(video.cur_y >= 25){
		video_scroll(1);
		video.cur_y = 24;
	}}


/* string.h */
uint32_t strlen(const char* str){
	uint32_t len = 0;
	while(*str != 0){
		str++;
		len++;
	}
	return len;
}

void memcpy(void* dst, const void* src, uint32_t len){
	char* cdst = (char*)dst;
	char* csrc = (char*)src;

	while(len){
		*(cdst++) = *(csrc++);
		len--;
	}
}

void memmove(void* dst, const void* src, uint32_t len){
	char* cdst = (char*)dst;
	char* csrc = (char*)src;

	while(len--){
		*(cdst++) = *(csrc++);
	}
}

void memset(void* dst, uint8_t c, uint32_t len){
	char* cdst = (char*)dst;

	while(len--){
		*(cdst++) = c;
	}
}