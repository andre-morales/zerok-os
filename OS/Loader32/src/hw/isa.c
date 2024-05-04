#include "isa.h"
#include "hw/gdt.h"
#include "hw/model16.h"
#include "hw/gdt.h"
#include "lib/string.h"
#include "lib/stdio.h"
#include "lib/stdlib.h"

void isa_setupPNPEntryProc();
bool isa_validatePNP(char*);
short pnp_getNumberOfDeviceNodes(far_ptr16, far_ptr16);

PNP_Installation* install = NULL;
far_ptr16 pnpEntryProc;
uint16_t pnpDataSegment;

bool isa_init() {
	log(LOG_MSG, "ISA: Initializing\n");

	// Look for $PnP structure in the 64KiB area below 1MiB
	uintptr_t ptr;
	for (ptr = 0xF0000; ptr < 0xFFFFF; ptr += 16) {
		char* str = (char*)ptr;

		if (strncmp(str, "$PnP", 4) != 0) continue;

		if (isa_validatePNP(str)) {
			install = (PNP_Installation*)ptr;
			return true;
		}
	}

	return false;
}

void isa_setupPNP() {
	log(LOG_INFO, "ISA: Pnp Version: %i\n", install->version);

	isa_setupPNPEntryProc();
}

void isa_enumerateDevices() {
	uint8_t numNodes = 0xEA;
	uint16_t nodeSize = 0xDEAD;

	far_ptr16 numNodesPtr = farptr_data(&numNodes);
	far_ptr16 nodeSizePtr = farptr_data(&nodeSize);
	int ret = pnp_getNumberOfDeviceNodes(numNodesPtr, nodeSizePtr);
	if (ret != 0) {
		log(LOG_ERROR, "ISA: PNP call failed with 0x%x!\n", ret);
		return;
	}

	if (numNodes == 0xEA || nodeSize == 0xDEAD) {
		log(LOG_ERROR, "ISA: Enumeration failed!\n");
		return;
	}

	printf("Nodes: 0x%x, Node size: 0x%x\n", (int)numNodes, (int)nodeSize);
	printf("  : 0x%x, 0x%x\n", (int)&numNodes, (int)&nodeSize);
}

void isa_setupPNPEntryProc() {
	uint32_t codeBase = install->protCodeSegmentBase;
	uint32_t dataBase = install->protDataSegmentBase;

	// Allocate 2 selectors in the GDT for CS and DS required
	uint16_t cs = gdt_push();
	uint16_t ds = gdt_push();

	log(LOG_INFO, "ISA: Setting up PnP entry point: 0x%x\n", (int)install->protEntryPoint);
	log(LOG_MSG,  "     CS: 0x%x : 0x%x\n", cs, codeBase);
	log(LOG_MSG,  "     DS: 0x%x : 0x%x\n", ds, dataBase);

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
	gdt_reload();
	
	pnpDataSegment = ds;

	pnpEntryProc.segment = cs;
	pnpEntryProc.offset = install->protEntryPoint;

	log(LOG_OK, "ISA: Entry point is ready\n");
}

bool isa_validatePNP(char* ptr) {
	log(LOG_INFO, "ISA: Validating $PnP at 0x%x\n", (int)ptr);

	uint8_t length = ((PNP_Installation*)ptr)->length;

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

short pnp_getNumberOfDeviceNodes(far_ptr16 numNodes, far_ptr16 nodeSize) {
	uint16_t args[] = { 0, numNodes.offset, numNodes.segment, nodeSize.offset, nodeSize.segment, pnpDataSegment };

	short ret = call_far16(pnpEntryProc, args, 6);
	return ret;
}

/*

struct PNP_DeviceNode {
	uint16_t size;
	uint8_t handle;
	uint32_t productID;
	uint8_t deviceType[3];
	uint16_t deviceAttribute;
};

*/