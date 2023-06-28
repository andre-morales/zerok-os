#include "acpi.h"
#include "lmem.h"
#include "stdio.h"
#include "string.h"
#include <stdint.h>

struct RSDP_T {
	char signature[8];
	uint8_t checksum;
	char oem[6];
	uint8_t revision;
	uint32_t rsdtAddr;
} __attribute__ ((packed));

typedef struct RSDP_T RSDP;

bool acpi_find() {
	const char* const ACPI_SIGNATURE = "RSD PTR ";

	// Try to find the RSDP table in the BIOS area (from 0xE0000 to 0xFFFFF)
	char* lookPtr = (char*)0xE0000;
	log(LOG_INFO, "ACPI: Searching from 0x%x...\n", lookPtr);

	// To get access to this region, we'll map 32 pages.
	for (int i = 0; i < 32; i++) {
		memMap(0xE0 + i, 0xE0 + i);
	}
	memReloadPageDir();

	// The special string should be aligned to 16 bytes.
	// To search 128KiB with a 16 byte alignment we need
	// 8192 lookups.
	bool found = false;
	for (int i = 0; i < 8192; i++) {
		if (*lookPtr == 'R') {
			if (strncmp(lookPtr, ACPI_SIGNATURE, 8) == 0) {
				if (acpi_validateRSDP(lookPtr)) {
					found = true;
					break;
				}
			}
		}

		lookPtr += 16;
	}

	log(LOG_WARN, "ACPI: Tables not found.\n");
	return found;
}

bool acpi_validateRSDP(void* ptr_) {
	uint8_t* ptr = ptr_;

	log(LOG_MSG, "Validating 0x%x\n", (unsigned int)ptr_);

	uint8_t sum = 0;
	for (int i = 0; i < sizeof(RSDP); i++) {
		sum += ptr[i];
	}

	if (sum != 0) return false;

	RSDP* rsdpDesc = ptr_;
	int rev = rsdpDesc->revision;

	log(LOG_OK, "ACPI: Revision %i\n", rev);
	return true;
}