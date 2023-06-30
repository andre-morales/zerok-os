#include "core.h"
#include "lmem.h"
#include "hw/vga_video.h"
#include "hw/acpi.h"
#include "hw/pci.h"
#include "hw/isa.h"
#include "lib/stdio.h"
#include "lib/string.h"

/**
 * [ 0   -  500] BIOS Stuff
 * [500  -  #  ] Stack
 * [1000 -  #  ] Page Directory
 * [2000 -  #  ] Page Table
 * [3000 - ... ] ZkLoader
 */

void main() {	
	bool init = loadInitArgs();
	setupIO();
	
	printf("\n\n-- &bZk&3Loader &eCore32 &cv8.0\n");

	if (!init) {
		log(LOG_ERROR, "Invalid loader arguments.\n");
		return;
	}

	isa_init();
	acpi_find();
	PCI_InitArgs pciArgs;
	pciArgs.entryPoint = loader_args.pciEntryPoint;
	pciArgs.lastBus = loader_args.pciLastBus;
	pciArgs.majorVer = loader_args.pciMajorVer;
	pciArgs.minorVer = loader_args.pciMinorVer;
	pciArgs.props = loader_args.pciProps;
	pci_init(&pciArgs);
	
	log(LOG_OK,	"Done.\n");
}

/** Loads stuff passed by previous stages */
bool loadInitArgs() {
	char* signature = (char*)&loader_args;

	if (signature[0] != 'Z' || signature[1] != 'k') {
		video.columns = 80;
		video.mode = 3;
		return false;
	}

	video.columns = loader_args.vidColumns;
	video.mode = loader_args.vidMode;
	return true;
}

void setupIO() {
	// Setup vga video
	video_init();
	video.cur_x = 0;
	video.cur_y = 24;

	// Set stdout to video_print
	stdout_procs[0] = &video_print;
}

void breakpoint() {
	__asm __volatile ("xchg %bx, %bx");
}

