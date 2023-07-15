#include "gdt.h"

typedef struct {
	uint16_t length;
	uint32_t address;
} GDT_Descriptor;

GDT_Descriptor* const gdt_descriptor = (GDT_Descriptor*)0x502;
const uintptr_t gdt_address = 0x508;

uint16_t gdt_push() {
	uint16_t selector = gdt_descriptor->length + 1;

	// Zero-out entry
	*(uint64_t*)(gdt_address + selector) = 0;

	gdt_descriptor->length += 8;
	return selector;
}

void gdt_record(uint16_t selector, GDT_Entry entry) {
	*(GDT_Entry*)(gdt_address + selector) = entry;
}

void gdt_reload() {
	__asm ("lgdt [0x502]");
}