# -- Config --
LOADER_OBJS=entry_stub.o core.o lib/string.o lib/stdio.o hw/model16.o hw/vga_video.o hw/acpi.o hw/pci.o hw/serial.o hw/gdt.o hw/isa.o

# -- Tools --
PASME=tools\pasme
CC=tools\gcc
CL=tools\ld

# Flags for just the GCC compiler
CCFLAGS=-ffreestanding -nostdlib -lgcc -std=c99 -fvisibility=hidden -O3 -masm=intel -Isrc -Isrc/stdlib -include global.h
CLFLAGS=-nostdlib -O3
.PHONY: all loader loader_stdlib clean debug

all: loader

# -- Loader Core --
LDR_OBJS=$(addprefix build/obj/,$(LOADER_OBJS))

loader: build/ZKLOADER.ELF
	copy "build\ZKLOADER.ELF" "..\diskDropbox\ZKOS\ZKLOADER.ELF"

# Final binary
build/ZKLOADER.ELF: linker_script.ld $(LDR_OBJS) | build
	$(CL) -T linker_script.ld -o build/ZKLOADER.ELF $(LDR_OBJS) $(CLFLAGS) 

# Build folder
build:
	-mkdir build
	
# Assembly stub
build/obj/entry_stub.o: entry_stub.pa	
	${PASME} transpile entry_stub.pa -to build/stub.asm
	yasm build/stub.asm -o build/obj/entry_stub.o -f elf

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
	-echo Nothing to debug here...