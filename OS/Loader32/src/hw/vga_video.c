#include "vga_video.h"
#include "lib/string.h"
#include "lib/stdlib.h"

const char DEFAULT_ATTRIB = 0x07;
Video video;

void video_init() {
	if (video.mode == 7) {
		video.vram = (void*)0xB0000;
	} else {
		video.vram = (void*)0xB8000;
	}

	video.attrib = DEFAULT_ATTRIB;
}

char video_colorToAttrib(char c) {
	if (c >= 'a' && c <= 'f') {
		return c + 10 - 'a';
	}
	
	if (c >= '0' && c <= '9') {
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
			*(clr_dst++) = DEFAULT_ATTRIB;
		}
	}
}