#pragma once
#include <stdint.h>

typedef struct {
	uint8_t mode;
	uint8_t columns;
	void* vram;
	uint8_t cur_x;
	uint8_t cur_y;
	uint8_t attrib;
} Video;

extern Video video;

void video_init();
void video_scroll(int lines);
void video_putch(char c);
void video_print(const char* str);