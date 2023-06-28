#include "core.h"
#include "vga_video.h"
#include "lmem.h"
#include "acpi.h"
#include "stdio.h"
#include "string.h"

/**
 * [ 0   -  500] BIOS Stuff
 * [500  -  #  ] Stack
 * [1000 -  #  ] Page Directory
 * [2000 -  #  ] Page Table
 * [3000 - ... ] ZkLoader
 */

void pci_init() {
	uint8_t major = loader_args.pciMajorVer;
	uint8_t minor = loader_args.pciMinorVer;

	if (major == 0 && minor == 0) {
		log(LOG_ERROR, "PCI: Not supported.\n");
		return;
	}

	log(LOG_OK, "PCI: Version %i.%i\n", (int)major, (int)minor);
}

void main() {	
	bool init = loadInitArgs();
	setupIO();
	
	printf("\n\n-- &bZk&3Loader &eCore32\n");

	if (!init) {
		log(LOG_ERROR, "Invalid loader arguments.\n");
		return;
	}

	acpi_find();
	pci_init();
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
	asm volatile ("xchg %bx, %bx");
}

