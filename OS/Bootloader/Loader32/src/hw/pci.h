#pragma once
#include "types.h"

typedef uint32_t PCI_DevAddr;

typedef struct {
	uint8_t majorVer;
	uint8_t minorVer;
	uint16_t props;
	uint8_t lastBus;
	void* entryPoint;
} PCI_InitArgs;

typedef struct {
	PCI_DevAddr address;
	uint16_t vendorID;
	uint16_t deviceID;
	uint8_t dClass;
	uint8_t dSubClass;
} PCI_Device;

typedef void(*EnumCallback)(const PCI_Device* device);

bool pci_init(const PCI_InitArgs*);
void pci_enumerate(EnumCallback fn);

PCI_DevAddr pci_devAddr(uint8_t bus, uint8_t slot, uint8_t func);
void pci_addrToPath(PCI_DevAddr addr, uint8_t* bus, uint8_t* slot, uint8_t* func);

uint8_t pci_devBaseClass(PCI_DevAddr);
uint8_t pci_devSubClass(PCI_DevAddr);
uint16_t pci_devVendorID(PCI_DevAddr);
uint16_t pci_devDeviceID(PCI_DevAddr);
uint8_t pci_devHeaderType(PCI_DevAddr);
uint8_t pci_devProgInterface(PCI_DevAddr);
uint32_t pci_devBAR(PCI_DevAddr, uint8_t barN);

uint32_t pci_readConfigL(PCI_DevAddr addr, uint8_t offset);
uint16_t pci_readConfigW(PCI_DevAddr addr, uint8_t offset);
uint8_t pci_readConfigB(PCI_DevAddr addr, uint8_t offset);