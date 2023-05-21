#include "vga_video.h"

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
	}
}

void print(const char* msg){
	char c;
	while(c = *msg){
		putch(c);
		msg++;
	}
}
