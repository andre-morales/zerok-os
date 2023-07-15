#pragma once
#include "types.h"

typedef struct {
	uint8_t majorVer;
	uint8_t minorVer;
	uint16_t props;
	uint8_t lastBus;
	void* entryPoint;
} PCI_InitArgs;

bool pci_init(const PCI_InitArgs*);
void pci_enumerate();
bool pci_enumFunction(uint8_t bus, uint8_t device, uint8_t function);

uint8_t pci_getBaseClass(uint8_t bus, uint8_t dev, uint8_t func);
uint8_t pci_getSubClass(uint8_t bus, uint8_t dev, uint8_t func);
uint16_t pci_getVendorID(uint8_t bus, uint8_t device, uint8_t function);
uint16_t pci_getDeviceID(uint8_t bus, uint8_t device, uint8_t function);
uint8_t pci_getHeaderType(uint8_t bus, uint8_t device, uint8_t function);

uint16_t pci_readConfigW(uint8_t bus, uint8_t device, uint8_t function, uint8_t offset);
uint16_t pci_readConfigB(uint8_t bus, uint8_t device, uint8_t function, uint8_t offset);