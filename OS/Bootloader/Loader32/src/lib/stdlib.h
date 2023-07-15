#pragma once

inline static void dbg_break() {
	__asm ("xchg bx, bx");
}