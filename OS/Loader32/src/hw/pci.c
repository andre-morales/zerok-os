#include "pci.h"
#include "io.h"
#include "lib/stdio.h"
#include "lib/stdlib.h"
#include "defs.h"

EnumCallback callbackFunction = NULL;

void pci_enumBus(uint8_t bus);
void pci_enumSlot(uint8_t bus, uint8_t slot);
bool pci_enumFunction(uint8_t bus, uint8_t slot, uint8_t function);

bool pci_init(const PCI_InitArgs* args) {
	// Check if version is valid
	uint8_t major = args->majorVer;
	uint8_t minor = args->minorVer;

	if (major == 0 && minor == 0) {
		log(LOG_ERROR, "PCI: Not supported\n");

		dbg_break();
		return false;
	}

	//initArgs = *args;
	log(LOG_OK, "PCI: Version %i.%i\n", (int)major, (int)minor);
	
	// Check access mechanisms
	bool mech1 = args->props & 0b00000001; // Mechanism 1
	bool mech2 = args->props & 0b00000010; // Mechanism 2

	if (mech1) {
		log(LOG_MSG, "PCI: Config mechanism 1 supported\n");
	} else {
		log(LOG_MSG, "PCI: Config mechanism 1 unsupported\n");
	}
	if (mech2) {
		log(LOG_MSG, "PCI: Config mechanism 2 supported\n");
	} else {
		log(LOG_MSG, "PCI: Config mechanism 2 unsupported\n");
	}

	if (!mech1) {
		log(LOG_ERROR, "PCI: Config mechanism 1 not supported.\n");
		return false;
	}

	return true;
}

void pci_enumerate(EnumCallback fn) {
	callbackFunction = fn;

	// Check if root bus is multi-function
	PCI_DevAddr addr = pci_devAddr(0, 0, 0);
	uint8_t rootBusType = pci_devHeaderType(addr);

	// If root bus is single function
	if ((rootBusType & 0x80) == 0) {
		log(LOG_MSG, "PCI: Single-function root bus.\n");
		pci_enumBus(0);
	}
	else {
		log(LOG_ERROR, "PCI: Multi-function root bus unsupported.\n");
		return;
	}
}

void pci_enumBus(uint8_t bus) {
	for (int i = 0; i < 32; i++) {
		pci_enumSlot(bus, i);
	}
}

void pci_enumSlot(uint8_t bus, uint8_t slot) {
	PCI_DevAddr addr = pci_devAddr(bus, slot, 0);

	uint16_t vendor = pci_devVendorID(addr);

	// If no device
	if (vendor == 0xFFFF) return;

	// Enumerate root function
	pci_enumFunction(bus, slot, 0);

	// If multi-function, try enumerating all remaining functions
	uint8_t devHeaderType = pci_devHeaderType(addr);

	if ((devHeaderType & 0x80) != 0) {
		for (int f = 1; f < 8; f++) {
			pci_enumFunction(bus, slot, f);
		}
	}
}
bool pci_enumFunction(uint8_t bus, uint8_t slot, uint8_t function) {
	PCI_DevAddr addr = pci_devAddr(bus, slot, function);

	uint16_t vendorID = pci_devVendorID(addr);
	if (vendorID == 0xFFFF) return false;

	uint16_t deviceID = pci_devDeviceID(addr);

	PCI_Device device;
	device.address = addr;
	device.vendorID = vendorID;
	device.deviceID = deviceID;
	device.dClass = pci_devBaseClass(addr);
	device.dSubClass = pci_devSubClass(addr);

	// If device is a bridge
	if (device.dClass == 6) {
		// If function is a PCI-to-PCI bridge
		if (device.dSubClass == 4) {
			// Secondary bus number
			uint8_t secondBus = pci_readConfigB(addr, 0x19);

			pci_enumBus(secondBus);
		}
	} else {
		callbackFunction(&device);
	}

	return true;
}

uint8_t inline pci_devBaseClass(PCI_DevAddr addr) {
	return pci_readConfigB(addr, 0xB);
}

uint8_t pci_devSubClass(PCI_DevAddr addr) {
	return pci_readConfigB(addr, 0xA);
}

uint8_t pci_devHeaderType(PCI_DevAddr addr) {
	return pci_readConfigB(addr, 0x0E);
}

uint16_t pci_devDeviceID(PCI_DevAddr addr) {
	return pci_readConfigW(addr, 0x02);
}

uint16_t pci_devVendorID(PCI_DevAddr addr) {
	return pci_readConfigW(addr, 0x00);
}

uint8_t pci_devProgInterface(PCI_DevAddr addr) {
	return pci_readConfigB(addr, 0x09);
}

uint32_t pci_devBAR(PCI_DevAddr dev, uint8_t barN) {
	return pci_readConfigL(dev, 0x10 + barN * 4);
}

PCI_DevAddr pci_devAddr(uint8_t bus, uint8_t slot, uint8_t func) {
	return (bus << 16) | (slot << 11) | (func << 8);
}

void pci_addrToPath(PCI_DevAddr addr, uint8_t* bus, uint8_t* slot, uint8_t* func) {
	*func = (addr >> 8) & 7;
	*slot = (addr >> 11) & 31;
	*bus = (addr >> 16) & 255;
}

uint32_t pci_readConfigL(PCI_DevAddr devAddr, uint8_t offset) {
	// Prepare the bitfield
	uint32_t addr = 0x80000000 | devAddr | (offset & 0xFC);

	// Output config address into 32 bit IO port 0xCF8
	io_outl(0xCF8, addr);

	// Read 32 bit IO port 0xCFC
	return io_inl(0xCFC);
}

uint16_t pci_readConfigW(PCI_DevAddr addr, uint8_t offset) {
	uint32_t reg = pci_readConfigL(addr, offset);

	// Shift register depending on the offset
	uint32_t v = reg >> ((offset & 2) * 8);

	// Mask only the lower 16 bits.
	return v & 0xFFFF;
}

uint8_t pci_readConfigB(PCI_DevAddr addr, uint8_t offset) {
	uint32_t reg = pci_readConfigL(addr, offset);

	// Shift register depending on the offset
	uint32_t v = reg >> ((offset & 3) * 8);

	// Mask only the lower 8 bits.
	return v & 0xFF;
}