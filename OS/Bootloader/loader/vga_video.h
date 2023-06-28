#pragma once
#include <stdint.h>

struct Video {
	uint8_t mode;
	uint8_t columns;
	void* vram;
	uint8_t cur_x;
	uint8_t cur_y;
	uint8_t attrib;
};

extern struct Video video;

void video_init();
void video_scroll(int lines);
void video_putch(char c);
void video_print(const char* str);