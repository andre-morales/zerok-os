#include <stdint.h>

struct Video {
	uint8_t mode;
	uint8_t columns;
	void* vram;
	uint8_t cur_x;
	uint8_t cur_y;
};

void loadArgs(void*);

void video_init();
void video_scroll(int);

void map();
void reload_page_directory();

void memcpy(void*, const void*, uint32_t);
void memmove(void*, const void*, uint32_t);
void memset(void*, uint8_t, uint32_t);
uint32_t strlen(const char*);
void print(const char*);
void putch(char);