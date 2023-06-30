#include "vga_video.h"
#include "lmem.h"
#include "lib/string.h"

const char DEFAULT_ATTRIB = 0x07;
struct Video video;

void video_init() {
	int page;
	if (video.mode == 7) {
		page = 0xB0;
	}
	else {
		page = 0xB8;
	}

	// Identity map VRAM
	memMap(0xA0, page);
	memReloadPageDir();
	video.vram = (void*)(0xA0 * 0x1000);

	video.attrib = DEFAULT_ATTRIB;
}

char video_colorToAttrib(char c) {
	if (c >= 'a') {
		return c + 10 - 'a';
	}
	
	if (c >= '0') {
		return c - '0';
	}

	return DEFAULT_ATTRIB;
}

void video_print(const char* msg) {
	char c;
	while (c = *msg) {
		if (c == '&') {
			c = *++msg;
			if (c == 0) break;

			video.attrib = video_colorToAttrib(c);
		} else {
			video_putch(c);
		}
		msg++;
	}
}

void video_putch(char c) {
	if(c == '\n'){
		video.cur_x = 0;
		video.cur_y++;
		video.attrib = DEFAULT_ATTRIB;
	} else {
		uint8_t* vram = (uint8_t*)video.vram;

		int offset = video.cur_y * video.columns + video.cur_x;
		vram[offset * 2] = c;
		vram[offset * 2 + 1] = video.attrib;

		if(++video.cur_x >= video.columns){
			video.cur_x = 0;
			video.cur_y++;
		}
	}

	if(video.cur_y >= 25){
		video_scroll(1);
		video.cur_y = 24;
	}
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