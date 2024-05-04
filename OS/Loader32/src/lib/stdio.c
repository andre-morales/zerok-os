#include "stdio.h"
#include "string.h"
#include "stdlib.h"

FILE impl_stdout = { .printfn = 0, .colors = false };
FILE impl_video_out = { .printfn = 0, .colors = false };
FILE impl_serial_out = { .printfn = 0, .colors = false };

FILE* stdout = &impl_stdout;
FILE* video_out = &impl_video_out;
FILE* serial_out = &impl_serial_out;

int int_to_strn(int value, char* dst, int max, int base);

int vfprintf(FILE* stream, const char* fmt, va_list args) {
	stdout_fn function = stream->printfn;
	if (function == NULL) return -1;

	char buffer[1024];

	int ret = vsnprintf(buffer, 1024, fmt, args);	

	function(buffer);
}

int printf(const char* fmt, ...) {
	va_list args;
	va_start(args, fmt);
	
	int ret = vfprintf(stdout, fmt, args);

	va_end(args);
	return ret;
}

int vprintf(const char* fmt, va_list args) {
	return vfprintf(stdout, fmt, args);
}

int fprintf(FILE* stream, const char* fmt, ...) {
	va_list args;
	va_start(args, fmt);
	int ret = vfprintf(stream, fmt, args);
	va_end(args);	
	return ret;
}

int snprintf(char* dst, size_t max, const char* fmt, ...) {
	va_list args;
	va_start(args, fmt);
	int ret = vsnprintf(dst, max, fmt, args);
	va_end(args);
	return ret;
}

int vsnprintf(char* dst, size_t max, const char* fmt, va_list args) {
	// How many characters we still can write. Subtracting one to account for null.
	int rem = max - 1;

	for (;;) {

		char c = *fmt++;
		if (c == 0) break;

		if (c == '%') {
			char nc = *fmt++;

			switch (nc) {
			// Printing strings
			case 's': {
				char* value = va_arg(args, char*);
				int len = strlen(value);

				int size = (rem < len) ? rem : len;

				memcpy(dst, value, size);
				dst += size;
				rem -= size;
				break;
			}

			// Printing integers
			case 'd':
			case 'i':
				{
					int value = va_arg(args, int);
					int intsize = int_to_strn(value, dst, rem+1, 10);

					dst += intsize;
					rem -= intsize;
				}
				break;

			// Printing hex integers
			case 'x':
			case 'X':
				{
					int value = va_arg(args, int);
					int intsize = int_to_strn(value, dst, rem+1, 16);

					dst += intsize;
					rem -= intsize;					
				}
				break;
			}
		} else {
			if (rem > 0) {
				*dst++ = c;	
			}
		
			--rem;
		}
	}

	// Null terminator
	*dst = 0;

	int size = max - rem + 1;
	return size;
}

int int_to_strn(int value, char* dst, int max, int base) {
	char buffer[16];
	char* ptr = buffer;

	// Special case for 0
	if (value == 0) {
		*ptr++ = '0';
	}

	// Convert the number to an unsinged one.
	// If number is negative and we are converting to base 10, append a '-'
	unsigned int val;
	if (value < 0 && base == 10) {
		val = -value;
		*ptr++ = '-';
	} else {
		val = value;		
	}

	// Extract each digit by getting its remainder
	while (val != 0) {
		unsigned int d = val % base;
		if (d <= 9) {
			*ptr++ = '0' + d;			
		} else {
			*ptr++ = 'A' - 10 + d;
		}
		val /= base;
	}

	int length = ptr - buffer;
	
	// Subtract one from the maximum size to account for the null terminator
	--max;

	// How many characters should be copied
	int cpy = (length < max) ? length : max;

	for (int i = 0; i < cpy; i++) {
		*dst++ = *--ptr;
	}

	*dst = 0;
	return length;
}

void log(LOG_CLASS lclass, const char* fmt, ...) {
	va_list args;
	va_start(args, fmt);

	switch (lclass) {
	default:
	case LOG_MSG:
		printf("       ");
		break;
	case LOG_INFO:
		printf("[&9Info&7] ");
		break;
	case LOG_OK:
		printf("[&2 Ok &7] ");
		break;
	case LOG_WARN:
		printf("[&eWARN&7] ");
		break;
	case LOG_ERROR:
		printf("[&4FAIL&7] ");
		break;
	}

	vprintf(fmt, args);
	va_end(args);
}