# -- Config --
LOADER_OBJS=stub.o core.o lib/string.o lib/stdio.o hw/model16.o hw/vga_video.o hw/acpi.o hw/pci.o hw/serial.o hw/gdt.o hw/isa.o

# -- Tools --
PASME=..\\..\\Tools\\pasme
YASM=yasm
LD=..\\..\\Tools\\ld
CC=..\\..\\Tools\\gcc

# Flags for just the GCC compiler
CCFLAGS=-ffreestanding -nostdlib -lgcc -std=c99 -fvisibility=hidden -O3 -masm=intel -Isrc -Isrc/stdlib -include global.h
LDFLAGS=-nostdlib -O3 --strip-all

.PHONY: all loader loader_stdlib clean debug

all: loader

# -- Loader Core --
LDR_OBJS=$(addprefix build/obj/,$(LOADER_OBJS))

loader: build/ZKLOADER.ELF
	copy "build\ZKLOADER.ELF" "..\..\Dropbox\ZKOS\ZKLOADER.ELF"

# Final binary
build/ZKLOADER.ELF: linker_script.ld $(LDR_OBJS) | build
	$(LD) -T linker_script.ld -o build/ZKLOADER.ELF $(LDR_OBJS) $(LDFLAGS) 

# Build folder
build:
	-@mkdir build 2>nul || cd .
	
# Assembly stub
build/obj/stub.o: stub.asm
	$(PASME) transpile stub.asm -to build/stub.nasm
	$(YASM) build/stub.nasm -f elf -o build/obj/stub.o

# General rule
build/obj/%.o: src/%.c src/%.h
	-@mkdir $(subst /,\,$(@D)) 2>nul || cd .
	$(CC) -c $< -o $@ $(CCFLAGS)

clean:
	del build\*.* /q
	del build\obj\*.* /q
	del build\obj\lib\*.* /q
	del build\obj\hw\*.* /q

debug:
	echo Nothing to debug here...