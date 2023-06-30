#pragma once
#include "types.h"

typedef struct {
	uint8 majorVer;
	uint8 minorVer;
	uint16 props;
	uint8 lastBus;
	void* entryPoint;
} PCI_InitArgs;

void pci_init(const PCI_InitArgs*);
