# -- Config --
TestDisk=..\..\Test Machines\vdisk.vhd

# -- Tools --
PASME=call scripts\pasme
C_ASSEMBLER=..\..\Tools\GCC\bin\i386-elf-as.exe
C_COMPILER=..\..\Tools\GCC\bin\i386-elf-gcc.exe

# -- Flags --
# Flags for both compiler and assembler
CFLAGS=

#Flags for just the compiler
CCFLAGS=-ffreestanding -nostdlib -lgcc

.PHONY: all xtldr_core xtldr_head mountdisk unmountdisk

# By default, build XtLdr Core
all: xtldr_core

# -- XtLoader Head --
xtldr_head: build\bin\LDRHEAD.BIN
	$(call mount-test-disk)
	copy "build\bin\LDRHEAD.BIN" "Z:\XTOS\LDRHEAD.BIN"
	$(call unmount-test-disk)

build\bin\LDRHEAD.BIN: src/xtloader_head.asm
	${PASME} transpile src/xtloader_head.asm -I ../../Libs/casm -to build/xtloader_head.asm
	${PASME} assemble  build/xtloader_head.asm -to build/bin/LDRHEAD.BIN

# -- XtLoader Core --
xtldr_core: build\bin\XTLOADER.ELF
	$(call mount-test-disk)
	copy "build\bin\XTLOADER.ELF" "Z:\XTOS\XTLOADER.ELF"
	$(call unmount-test-disk)

# Final binary
build\bin\XTLOADER.ELF: build\ldr_core\stub.o build\ldr_core\core.o src\ldr_core\link.ld
	${C_COMPILER} -T src\ldr_core\link.ld -o build\bin\XTLOADER.ELF build\ldr_core\stub.o build\ldr_core\core.o ${CFLAGS} ${CCFLAGS}

# Assembly stub
build\ldr_core\stub.o: src\ldr_core\stub.s
	${C_ASSEMBLER} src\ldr_core\stub.s -o build\ldr_core\stub.o ${CFLAGS}

# C Body
build\ldr_core\core.o: src\ldr_core\core.c src\ldr_core\core.h
	${C_COMPILER} -c src\ldr_core\core.c -o build\ldr_core\core.o ${CFLAGS} ${CCFLAGS}

# -- Utilities --
define mount-test-disk
	${PASME} mountdisk "${TestDisk}"
endef

define unmount-test-disk
	${PASME} unmountdisk "${TestDisk}"
endef