/**
This file is included in every other source file directly by GCC.
It should NOT be included manually.

The contents in this file should be invisible to Intellisense.
*/

#pragma once
#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>

#define NEAR_TEXT __attribute__((section("NEAR_TEXT")))
#define NO_INLINE __attribute__((noinline))
#define ALWAYS_INLINE __attribute__((always_inline))