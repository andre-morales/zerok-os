#include <stdint.h>

void breakpoint();
void loadArgs(uint8_t*);

void map();
void reload_page_directory();

void print(const char*);
void putch(char);