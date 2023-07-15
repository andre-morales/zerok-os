#pragma once
#include <stddef.h>
#include <stdarg.h>
#include "types.h"

typedef void(*stdout_fn)(const char*);

typedef struct {
	stdout_fn printfn;
	bool colors;
} FILE;

extern FILE* stdout;
extern FILE* video_out;
extern FILE* serial_out;

int printf(const char* fmt, ...);
int fprintf(FILE* stream, const char* fmt, ...);
int snprintf(char* dst, size_t max, const char* format, ...);
int vprintf(const char* fmt, va_list args);
int vfprintf(FILE* stream, const char* fmt, va_list args);
int vsnprintf(char* dst, size_t max, const char* fmt, va_list args);

typedef enum LOG_CLASS_T {
	LOG_MSG = 0, LOG_INFO = 1, LOG_OK = 2, LOG_WARN = 3, LOG_ERROR = 4
} LOG_CLASS;
void log(LOG_CLASS lclass, const char* fmt, ...);