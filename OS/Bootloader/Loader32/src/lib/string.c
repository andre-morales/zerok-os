#include "string.h"
#include "stdlib.h"
#include <stdint.h>

int strncmp(const char* str1, const char* str2, size_t len) {
	for (int i = 0; i < len; i++) {
		char ca = *str1++;
		char cb = *str2++;

		int diff = ca - cb;
		if (diff != 0) {
			return (diff > 0) ? 1 : -1;
		}

		// If both string A and B are finished, they're equal.
		if (ca == 0) return 0;
	}
	return 0;
}

size_t strlen(const char* str){
	size_t len = 0;
	while(*str != 0){
		str++;
		len++;
	}
	return len;
}

void memcpy(void* dst, const void* src, size_t len){
	char* cdst = (char*)dst;
	char* csrc = (char*)src;

	while(len){
		*(cdst++) = *(csrc++);
		len--;
	}
}

void memmove(void* dst, const void* src, size_t len){
	uint8_t* cdst = (uint8_t*)dst;
	uint8_t* csrc = (uint8_t*)src;

	while(len--){
		*(cdst++) = *(csrc++);
	}
}

void memset(void* dst, unsigned char c, size_t len){
	char* cdst = (char*)dst;

	while(len--){
		*(cdst++) = c;
	}
}