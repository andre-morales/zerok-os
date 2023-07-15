#include "pci.h"
#include "io.h"
#include "lib/stdio.h"

PCI_InitArgs initArgs;

bool pci_init(const PCI_InitArgs* args) {
	// Check if version is valid
	uint8_t major = args->majorVer;
	uint8_t minor = args->minorVer;

	if (major == 0 && minor == 0) {
		log(LOG_ERROR, "PCI: Not supported\n");
		return false;
	}

	initArgs = *args;
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
		return;
	}
	
	pci_enumerate();
}

bool pci_enumFunction(uint8_t bus, uint8_t device, uint8_t function) {
	uint16_t vendorID = pci_getVendorID(bus, device, function);
	if (vendorID == 0xFFFF) return false;
	
	uint16_t deviceID = pci_getDeviceID(bus, device, function);
	
	fprintf(serial_out, "PCI: %i:%i:%i: \n", (int)bus, (int)device, (int)function);
	fprintf(serial_out, "  Vendor: %x\n", vendorID);
	fprintf(serial_out, "  Device: %x\n", deviceID);

	uint8_t fClass = pci_getBaseClass(bus, device, function);
	uint8_t fSubClass = pci_getSubClass(bus, device, function);
	
	fprintf(serial_out, "  Class: %x\n", fClass);
	fprintf(serial_out, "  Subclass: %x\n", fSubClass);

	printf("PCI %i:%i:%i: %x#%x %x/%x\n", (int)bus, (int)device, (int)function, vendorID, deviceID, fClass, fSubClass);

	if (fClass == 0x1) {
		printf("PCI Storage: %i:%i:%i: \n", (int)bus, (int)device, (int)function);
		printf("  Vendor: %x\n", vendorID);
		printf("  Device: %x\n", deviceID);
		printf("  Subclass: %x\n", fSubClass);
	}

	// If function is a PCI-to-PCI bridge
	if (fClass == 6 && fSubClass == 4) {
		// Secondary bus number
		uint8_t secondBus = pci_readConfigB(bus, device, function, 0x19);

		pci_enumerateBus(secondBus);
	}

	return true;
}

void pci_enumDevice(uint8_t bus, uint8_t device) {
	uint16_t vendor = pci_getVendorID(bus, device, 0);

	// If no device
	if (vendor == 0xFFFF) return;

	// Enumerate root function
	pci_enumFunction(bus, device, 0);

	// If multi-function, try enumerate all of them
	uint8_t devHeaderType = pci_getHeaderType(bus, device, 0);
	if ((devHeaderType & 0x80) == 1) {
		for (int f = 1; f < 8; f++) {
			pci_enumFunction(bus, device, f);
		}
	}
}

void pci_enumerateBus(uint8_t bus) {
	for (int i = 0; i < 32; i++) {
		pci_enumDevice(bus, i);
	}
}

void pci_enumerate() {
	// Check if root bus is multi-function
	uint8_t rootBusType = pci_getHeaderType(0, 0, 0);

	// If root bus is single function
	if ((rootBusType & 0x80) == 0) {
		log(LOG_MSG, "PCI: Single-function root bus.\n");
		pci_enumerateBus(0);
	} else {
		log(LOG_ERROR, "PCI: Multi-function root bus unsupported.\n");
		return;
	}
}

uint8_t pci_getBaseClass(uint8_t bus, uint8_t dev, uint8_t func) {
	return pci_readConfigB(bus, dev, func, 0xB);
}

uint8_t pci_getSubClass(uint8_t bus, uint8_t dev, uint8_t func) {
	return pci_readConfigB(bus, dev, func, 0xA);
}

uint8_t pci_getHeaderType(uint8_t bus, uint8_t dev, uint8_t func) {
	return pci_readConfigB(bus, dev, func, 0x0E);
}

uint16_t pci_getDeviceID(uint8_t bus, uint8_t dev, uint8_t func) {
	return pci_readConfigW(bus, dev, func, 0x02);
}

uint16_t pci_getVendorID(uint8_t bus, uint8_t dev, uint8_t func) {
	return pci_readConfigW(bus, dev, func, 0x00);
}

uint32_t pci_readConfigL(uint8_t bus, uint8_t device, uint8_t function, uint8_t offset) {
	// Prepare the bitfield
	uint32_t bus_bits = bus << 16;
	uint32_t dev_bits = device << 11;
	uint32_t fun_bits = function << 8;
	uint32_t off_bits = offset & 0xFC;
	uint32_t addr = 0x80000000 | bus_bits | dev_bits | fun_bits | off_bits;

	// Output config address into 32 bit IO port 0xCF8
	io_outl(0xCF8, addr);

	// Read 32 bit IO port 0xCFC
	return io_inl(0xCFC);
}

uint16_t pci_readConfigW(uint8_t bus, uint8_t device, uint8_t function, uint8_t offset) {
	uint32_t reg = pci_readConfigL(bus, device, function, offset);

	// Shift register depending on the offset
	uint32_t v = reg >> ((offset & 2) * 8);

	// Mask only the lower 16 bits.
	return v & 0xFFFF;
}

uint16_t pci_readConfigB(uint8_t bus, uint8_t device, uint8_t function, uint8_t offset) {
	uint32_t reg = pci_readConfigL(bus, device, function, offset);

	// Shift register depending on the offset
	uint32_t v = reg >> ((offset & 3) * 8);

	// Mask only the lower 8 bits.
	return v & 0xFF;
}