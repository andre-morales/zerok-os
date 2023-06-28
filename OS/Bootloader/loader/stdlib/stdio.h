#pragma once
#include <stddef.h>
#include <stdarg.h>

typedef void(*stdout_fn)(const char*);
extern stdout_fn stdout_procs[4];

int printf(const char* fmt, ...);
int fprintf(short int file, const char* fmt, ...);
int snprintf(char* dst, size_t max, const char* format, ...);
int vprintf(const char* fmt, va_list args);
int vfprintf(short int file, const char* fmt, va_list args);
int vsnprintf(char* dst, size_t max, const char* fmt, va_list args);

typedef enum LOG_CLASS_T {
	LOG_MSG, LOG_INFO, LOG_OK, LOG_WARN, LOG_ERROR
} LOG_CLASS;
void log(LOG_CLASS lclass, const char* fmt, ...);