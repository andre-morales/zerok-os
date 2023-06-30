#include "pci.h"
#include "core.h"
#include "lib/stdio.h"

PCI_InitArgs initArgs;

void pci_init(const PCI_InitArgs* args) {
	uint8_t major = args->majorVer;
	uint8_t minor = args->minorVer;

	if (major == 0 && minor == 0) {
		log(LOG_ERROR, "PCI: Not supported.\n");
		return;
	}

	initArgs = *args;
	log(LOG_OK, "PCI: Version %i.%i\n", (int)major, (int)minor);
}
