#include "vga_video.h"

struct Video video;

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