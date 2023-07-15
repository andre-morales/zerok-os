#pragma once
#include "defs.h"

typedef struct {
	uint16_t segment;
	uint16_t offset;
} far_ptr16;

inline far_ptr16 farptr_data(void* ptr_) {
	uintptr_t ptr = (uintptr_t)ptr_;

	far_ptr16 far = { .segment = 0x10, .offset = (uint16_t)ptr };
	return far;
}

int NO_INLINE NEAR_TEXT call_far16(far_ptr16 function, uint16_t* args, size_t n);