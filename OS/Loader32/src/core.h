#pragma once
#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>
#include <assert.h>
#include "types.h"

#pragma pack(push, 1)
typedef struct {
	char signature[2];
	uint8_t vidColumns;
	uint8_t vidMode;

	uint8_t pciMajorVer;
	uint8_t pciMinorVer;
	uint16_t pciProps;
	uint8_t pciLastBus;
	void* pciEntryPoint;
} InitStruct;
#pragma pack(pop)

extern const InitStruct loader_args;

bool loadInitArgs();
void setupIO();