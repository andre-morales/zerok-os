#pragma once
#include "types.h"

static inline void io_outb(uint16_t port, uint8_t value) {
	__asm ("out %0, %1"
		:
		: "d"(port), "a"(value)
		: "memory"
	);
}

static inline void io_outl(uint16_t port, uint32_t value) {
	__asm ("out %0, %1"
		:
		: "d"(port), "a"(value)
		: "memory"
		);
}

static inline uint32_t io_inl(uint16_t port) {
	uint32_t val;
	__asm ("in %0, %1"
		: "=a"(val)
		: "d"(port)
		: "memory"
		);
	return val;
}

static inline uint8_t io_inb(uint16_t port) {
	uint8_t val;
	__asm ("in %0, %1"
		: "=a"(val)
		: "d"(port)
		: "memory"
		);
	return val;
}