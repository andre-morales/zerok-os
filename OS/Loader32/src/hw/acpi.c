#include "acpi.h"
#include "lib/stdio.h"
#include "lib/string.h"
#include <stdint.h>

#pragma pack(push, 1)

typedef struct {
	char signature[4];
	uint32_t size;
	uint8_t revision;
	uint8_t checksum;
	char oemID[6];
	char oemTableID[8];
	uint32_t oemRevision;
	uint32_t creatorID;
	uint32_t creatorRevision;
} ACPI_TableHeader;

typedef struct {
	ACPI_TableHeader header;
	uint32_t tablePointers[];
} RSDT;

typedef struct {
	char signature[8];
	uint8_t checksum;
	char oem[6];
	uint8_t revision;
	RSDT* rsdtAddr;
} RSDP;
#pragma pack(pop)

bool acpi_validateTable(void* header);

RSDP* acpi_findRSDP() {
	const char* const ACPI_SIGNATURE = "RSD PTR ";

	// Try to find the RSDP table in the BIOS area (from 0xE0000 to 0xFFFFF)
	char* lookPtr = (char*)0xE0000;
	log(LOG_INFO, "ACPI: Searching from 0x%x...\n", lookPtr);

	// The special string should be aligned to 16 bytes.
	// To search 128KiB with a 16 byte alignment we need
	// 8192 lookups.
	for (int i = 0; i < 8192; i++, lookPtr += 16) {
		if (*lookPtr != 'R') continue;
		if (strncmp(lookPtr, ACPI_SIGNATURE, 8) != 0) continue;

		if (acpi_validateRSDP(lookPtr)) {
			return (RSDP*)lookPtr;
		}
	}

	log(LOG_WARN, "ACPI: Root pointer not found.\n");
	return NULL;
}

bool acpi_init() {
	RSDP* rsdp = acpi_findRSDP();
	if (!rsdp) return false;

	log(LOG_OK, "ACPI: RSDP Found: 0x%x.\n", rsdp);
	
	uint32_t addr = (uint32_t)rsdp->rsdtAddr;
	log(LOG_INFO, "ACPI: RSDT is at 0x%x\n", addr);

	RSDT* rsdt = rsdp->rsdtAddr;	
	int pointers = (rsdt->header.size - sizeof(ACPI_TableHeader)) / 4;

	log(LOG_INFO, "ACPI: %d tables.\n", pointers);
	for (int i = 0; i < pointers; i++) {
		char buffer[5];
		buffer[4] = 0;
		
		ACPI_TableHeader* table = (ACPI_TableHeader*)(rsdt->tablePointers[i]);
		memcpy(buffer, table->signature, 4);
		
		printf("ACPI: %s\n", table->signature);
	}
}

bool acpi_validateTable(void* header_) {
	uint32_t size = ((ACPI_TableHeader*)header_)->size;
	uint8_t* header = (uint8_t*)header_;

	uint8_t sum = 0;

	for (int i = 0; i < size; i++) {
		sum += *header++;
	}

	return sum == 0;
}

bool acpi_validateRSDP(void* ptr_) {
	uint8_t* ptr = (uint8_t*)ptr_;

	log(LOG_MSG, "Validating 0x%x\n", (unsigned int)ptr_);

	uint8_t sum = 0;
	for (int i = 0; i < sizeof(RSDP); i++) {
		sum += ptr[i];
	}

	if (sum != 0) return false;

	RSDP* rsdpDesc = (RSDP*)ptr_;
	int rev = rsdpDesc->revision;

	log(LOG_OK, "ACPI: Revision %i\n", rev);
	return true;
}