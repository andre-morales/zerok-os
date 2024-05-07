#include "core.h"
#include "hw/vga_video.h"
#include "hw/acpi.h"
#include "hw/pci.h"
#include "hw/isa.h"
#include "hw/serial.h"
#include "lib/stdio.h"
#include "lib/string.h"
#include "lib/stdlib.h"
#include "hw/gdt.h"

/**
 * [ 0   -  500] BIOS Stuff
 * [500  -  518] GDT
 * [...  - 3000] Stack
 * [3000 - ... ] ZkLoader
 */

void pciDeviceCallback(const PCI_Device* dev);

void main() {
	bool init = loadInitArgs();
	setupIO();
	printf("\n-- &bZk&3Loader &eCore32 &cv0.8.3\n");
	if (!init) {
		log(LOG_ERROR, "Invalid loader arguments.\n");
		return;
	}

	//if (isa_init()) {
	//	isa_setupPNP();
	//	isa_enumerateDevices();
	//}

	//acpi_init();

	PCI_InitArgs pciArgs;
	pciArgs.entryPoint = loader_args.pciEntryPoint;
	pciArgs.lastBus = loader_args.pciLastBus;
	pciArgs.majorVer = loader_args.pciMajorVer;
	pciArgs.minorVer = loader_args.pciMinorVer;
	pciArgs.props = loader_args.pciProps;
	if (pci_init(&pciArgs)) {
		log(LOG_INFO, "PCI: Enumeration results:\n");
		pci_enumerate(&pciDeviceCallback);
	}
	
	log(LOG_OK,	"Done.\n");
}

void NO_INLINE sleep() {
	
	uint32_t cycles = 500000000;

	__asm volatile(
		".lbl:		\n\t"
		"nop		\n\t"
		"loop .lbl	\n\t"
		: 
		: "c" (cycles)
		:
	);
}

void pciDeviceCallback(const PCI_Device* dev) {
	sleep();

	uint32_t addr = dev->address;
	uint8_t bus;
	uint8_t slot;
	uint8_t func;

	pci_addrToPath(addr, &bus, &slot, &func);

	int vendor = dev->vendorID;
	int deviceID = dev->deviceID;
	int dClass = dev->dClass;
	int dSubClass = dev->dSubClass;

	log(LOG_MSG, "     [%i:%i:%i] ID: (%x/%x) Type: {%x.%x}\n", (int)bus, (int)slot, (int)func, vendor, deviceID, dClass, dSubClass);

	fprintf(serial_out, "  Vendor: %x\n", vendor);
	fprintf(serial_out, "  Device: %x\n", deviceID);
	fprintf(serial_out, "  Class: %x\n", dClass);
	fprintf(serial_out, "  Subclass: %x\n", dSubClass);

	if (dClass == 0x1) {
		int progInt = pci_devProgInterface(addr);
		uint32_t bar0 = pci_devBAR(addr, 0);
		uint32_t bar1 = pci_devBAR(addr, 1);
		uint32_t bar2 = pci_devBAR(addr, 2);
		uint32_t bar3 = pci_devBAR(addr, 3);
		uint32_t bar4 = pci_devBAR(addr, 4);
		uint32_t bar5 = pci_devBAR(addr, 5);

		printf("PCI Storage [%i:%i:%i] \n", (int)bus, (int)slot, (int)func);
		printf("  Vendor: 0x%x\n", vendor);
		printf("  Device: 0x%x\n", deviceID);
		printf("  Subclass: 0x%x\n", dSubClass);
		printf("  Prog. Interface: 0x%x\n", progInt);
		printf("  BARS 0: 0x%x    1: 0x%x\n", bar0, bar1);
		printf("  BARS 2: 0x%x    3: 0x%x\n", bar2, bar3);
		printf("  BARS 4: 0x%x    5: 0x%x\n", bar4, bar5);
	}
}

/** Loads stuff passed by previous stages */
bool loadInitArgs() {
	char* sign = (char*) &loader_args.signature;

	if (sign[0] != 'Z' || sign[1] != 'k') {
		video.columns = 80;
		video.mode = 3;
		return false;
	}

	video.columns = loader_args.vidColumns;
	video.mode = loader_args.vidMode;
	return true;
}

void multiprint(const char* str) {
	video_print(str);
	serial_print(str);
}

void setupIO() {
	serial_init();

	// Setup vga video
	video_init();
	video.cur_x = 0;
	video.cur_y = 24;

	// Set stdout to video_print
	stdout->printfn = &multiprint;
	video_out->printfn = &video_print;
	serial_out->printfn = &serial_print;
}
