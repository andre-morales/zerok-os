#include <stdint.h>
#include "vga_video.h"

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