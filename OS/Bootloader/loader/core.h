#include <stdint.h>
#include <stdbool.h>

struct InitStruct_T {
	uint16_t signature;

	uint8_t vidColumns;
	uint8_t vidMode;

	uint8_t pciMajorVer;
	uint8_t pciMinorVer;
	uint16_t pciProps;
	uint8_t pciLastBus;
	uint32_t pciEntryPoint;
} __attribute__ ((packed));

typedef struct InitStruct_T InitStruct;

extern const InitStruct loader_args;

bool loadInitArgs();
void setupIO();
void breakpoint();
