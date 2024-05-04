#include "serial.h"
#include "io.h"

#define MAX_WRITE_TRIES 0

static const uint16_t PORT = 0x3F8;
static bool serial_initialized = false;

bool serial_init() {
	io_outb(PORT + 1, 0x00);    // Disable all interrupts
	io_outb(PORT + 3, 0x80);    // Enable DLAB (set baud rate divisor)
	io_outb(PORT + 0, 0x03);    // Set divisor to 3 (lo byte) 38400 baud
	io_outb(PORT + 1, 0x00);    //                  (hi byte)
	io_outb(PORT + 3, 0x03);    // 8 bits, no parity, one stop bit
	io_outb(PORT + 2, 0xC7);    // Enable FIFO, clear them, with 14-byte threshold
	io_outb(PORT + 4, 0x0B);    // IRQs enabled, RTS/DSR set
	io_outb(PORT + 4, 0x1E);    // Set in loopback mode, test the serial chip
	io_outb(PORT + 0, 0xAE);    // Test serial chip (send byte 0xAE and check if serial returns same byte)

	// Check if serial is faulty (i.e: not same byte as sent)
	if (io_inb(PORT + 0) != 0xAE) {
		return false;
	}

	// If serial is not faulty set it in normal operation mode
	// (not-loopback with IRQs enabled and OUT#1 and OUT#2 bits enabled)
	io_outb(PORT + 4, 0x0F);
	serial_initialized = true;
	return true;
}

bool serial_canWrite() {
	return io_inb(PORT + 5) & 0x20;
}

#include "lib/stdio.h"
bool serial_write(char c) {
	static int write_tries = MAX_WRITE_TRIES;

	for (int i = 0; i < write_tries; i++) {
		if (serial_canWrite()) {
			io_outb(PORT, c);
			write_tries = MAX_WRITE_TRIES;
			return true;
		}
	}

	// If write still couldn't be done, try even less next time.
	if (write_tries > 2) write_tries /= 2;
	return false;
}

void serial_print(const char* str) {
	if (!serial_initialized) return;

	char c;
	while (c = *str++) {
		// If there is a color code, and it is not escaped with &, discard it.
		if (c == '&') {
			c = *str++;

			if (c == '&') {
				if (!serial_write('&')) break;
				if (!serial_write('&')) break;
			} else if (c == 0) return;

			continue;
		}

		if (!serial_write(c)) break;
	}
}