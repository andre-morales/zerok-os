#include <stddef.h>

size_t strlen(const char* str);
int strncmp(const char* str1, const char* str2, size_t len);
void memcpy(void* dst, const void* src, size_t len);
void memmove(void* dst, const void* src, size_t len);
void memset(void* dst, unsigned char c, size_t len);