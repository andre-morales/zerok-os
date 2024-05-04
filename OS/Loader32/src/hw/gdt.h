#pragma once
#include "types.h"
#include "defs.h" 

typedef uint64_t GDT_Entry;

#pragma pack(push, 1)
typedef struct {
	char signature[4];
	uint8_t version;
	uint8_t length;
	uint16_t control;
	uint8_t checksum;
	uintptr_t eventNotificationFlagAddr;

	uint16_t realEntryPoint;
	uint16_t realCodeSegment;

	uint16_t protEntryPoint;
	uint32_t protCodeSegmentBase;

	char oem[4];
	uint16_t realDataSegment;
	uint32_t protDataSegmentBase;
} PNP_Installation;
#pragma pack(pop)

uint16_t gdt_push();
void gdt_record(uint16_t selector, GDT_Entry entry);
void gdt_reload();

inline GDT_Entry gdt_makeEntry(uint32_t base, uint32_t limit, uint8_t access, uint8_t flags) {
	GDT_Entry entry = 0;
	uint8_t* dst = (uint8_t*)&entry;

	// Limit
	dst[0] = limit & 0xFF;
	dst[1] = (limit >> 8) & 0xFF;
	dst[6] = (limit >> 16) & 0x0F;

	// Base
	dst[2] = base & 0xFF;
	dst[3] = (base >> 8) & 0xFF;
	dst[4] = (base >> 16) & 0xFF;
	dst[7] = (base >> 24) & 0xFF;

	// Access
	dst[5] = access;

	// Flags
	dst[6] |= flags << 4;
	return entry;
}

inline uint8_t gdt_accessByte(bool present, uint8_t privlege, bool isCodeOrData, bool executable, bool direction_conforming, bool rw, bool accessed) {
	return (present << 7) | ((privlege & 3) << 5) | (isCodeOrData << 4) | (executable << 3) | (direction_conforming << 2) | (rw << 1) | accessed;
}

inline uint8_t gdt_flags(bool isPageGranularity, bool is32bit, bool isLongMode) {
	return (isPageGranularity << 3) | (isLongMode << 2) | (isLongMode << 1);
}