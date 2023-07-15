#pragma once
#include <stdbool.h>

bool serial_init();

bool serial_canWrite();

bool serial_write(char c);

void serial_print(const char* str);