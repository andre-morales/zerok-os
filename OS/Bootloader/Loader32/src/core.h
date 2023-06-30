#pragma once
#include <stdint.h>
#include <stdbool.h>
#include "assertion.h"
#include "types.h"

#pragma pack(push, 1)
typedef struct {
	uint16 signature;
	uint8 vidColumns;
	uint8 vidMode;

	uint8 pciMajorVer;
	uint8 pciMinorVer;
	uint16 pciProps;
	uint8 pciLastBus;
	void* pciEntryPoint;
} InitStruct;
#pragma pack(pop)

extern const InitStruct loader_args;

bool loadInitArgs();
void setupIO();
void breakpoint();