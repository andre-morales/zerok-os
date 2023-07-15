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

void main() {
	bool init = loadInitArgs();
	setupIO();
	printf("\n-- &bZk&3Loader &eCore32 &cv8.2\n");
	if (!init) {
		log(LOG_ERROR, "Invalid loader arguments.\n");
		return;
	}

	if (isa_init()) {
		isa_enumerateDevices();
	}

	/*acpi_init();

	PCI_InitArgs pciArgs;
	pciArgs.entryPoint = loader_args.pciEntryPoint;
	pciArgs.lastBus = loader_args.pciLastBus;
	pciArgs.majorVer = loader_args.pciMajorVer;
	pciArgs.minorVer = loader_args.pciMinorVer;
	pciArgs.props = loader_args.pciProps;
	pci_init(&pciArgs);
	
	log(LOG_OK,	"Done.\n");*/
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
