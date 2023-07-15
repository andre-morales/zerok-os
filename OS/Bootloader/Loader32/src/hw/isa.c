#include "isa.h"
#include "hw/gdt.h"
#include "hw/model16.h"
#include "hw/gdt.h"
#include "lib/string.h"
#include "lib/stdio.h"
#include "lib/stdlib.h"

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

bool pnp_validate(char*);
void pnp_setupEntry();
uint16_t NO_INLINE pnp_getNumberOfDeviceNodes(far_ptr16, far_ptr16, uint16_t);

PNP_Installation* install = NULL;
uint32_t pnpCodeSegment;
uint16_t pnpDataSegment;
far_ptr16 pnpEntryProc;

bool pnp_init() {
	log(LOG_MSG, "ISA: Initializing\n");

	char* ptr = (char*)0xF0000;
	while (ptr < (char*)0xFFFFF) {
		if (strncmp(ptr, "$PnP", 4) == 0) {
			if (pnp_validate(ptr)) {
				install = (PNP_Installation*)ptr;
				pnp_setupEntry();
				return true;
			}
		}

		ptr += 16;
	}

	return false;
}

void isa_enumerateDevices() {
	uint8_t numNodes = 0xEA;
	uint16_t nodeSize = 0xDEAD;

	far_ptr16 numNodesPtr = farptr_data(&numNodes);
	far_ptr16 nodeSizePtr = farptr_data(&nodeSize);
	uint16_t result = pnp_getNumberOfDeviceNodes(numNodesPtr, nodeSizePtr, pnpDataSegment);

	printf("Nodes: 0x%x, Node size: 0x%x\n", (int)numNodes, (int)nodeSize);
	printf("  : 0x%x, 0x%x\n", (int)&numNodes, (int)&nodeSize);
}

void pnp_setupEntry() {
	uint32_t codeBase = install->protCodeSegmentBase;
	uint32_t dataBase = install->protDataSegmentBase;

	uint32_t addr = install->protCodeSegmentBase + install->protEntryPoint;
	log(LOG_MSG, "ISA: Setting up entry point %xh:%xh\n", (int)install->protCodeSegmentBase, (int)install->protEntryPoint);
	
	// Allocate 2 selectors in the GDT for CS and DS required
	uint16_t cs = gdt_push();
	uint16_t ds = gdt_push();

	// Setup the code segment to be 16-bit with byte granularity
	uint8_t csAccess = gdt_accessByte(true, 0, 1, true, 0, true, 0);
	uint8_t csFlags = gdt_flags(0, 0, 0);
	GDT_Entry csEntry = gdt_makeEntry(codeBase, 0xFFFFF, csAccess, csFlags);

	// Setup the data segment to be 16-bit with byte granularity
	uint8_t dsAccess = gdt_accessByte(true, 0, 1, false, 0, true, 0);
	uint8_t dsFlags = gdt_flags(0, 0, 0);
	GDT_Entry dsEntry = gdt_makeEntry(dataBase, 0xFFFFF, dsAccess, dsFlags);

	// Record them in the GDT.
	gdt_record(cs, csEntry);
	gdt_record(ds, dsEntry);

	log(LOG_MSG, "ISA: CS[%x]: %x, DS[%x]: %x\n", (int)cs, codeBase, (int)ds, dataBase);

	gdt_reload();
	log(LOG_OK, "ISA: Entry point is ready\n");

	pnpCodeSegment = cs;
	pnpDataSegment = ds;

	pnpEntryProc.segment = cs;
	pnpEntryProc.offset = install->protEntryPoint;
}

bool pnp_validate(char* ptr) {
	log(LOG_INFO, "ISA: Validating $PnP at 0x%x\n", (int)ptr);

	uint8_t length = ((ISA_Installation*)ptr)->length;

	uint8_t sum = 0;

	for (int i = 0; i < length; i++) {
		sum += *ptr++;
	}

	if (sum == 0) {
		log(LOG_OK, "ISA: Structure is valid\n");
		return true;
	}
	return false;
}

uint16_t pnp_getNumberOfDeviceNodes(far_ptr16 numNodes, far_ptr16 nodeSize, uint16_t biosDataSegment) {
	dbg_break();

	uint16_t args[] = { 0, numNodes.offset, numNodes.segment, nodeSize.offset, nodeSize.segment, biosDataSegment };

	call_far16(pnpEntryProc, args, 6);
	return 0;
}
