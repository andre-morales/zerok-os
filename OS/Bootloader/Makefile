# -- Config --
TestDisk=../../Test Machines/vdisk.vhd
PartitionStart=0x8000

# -- Tools --
PASME=call scripts/pasme
C_ASSEMBLER=../../Tools/GCC/bin/i386-elf-as.exe
C_COMPILER=../../Tools/GCC/bin/i386-elf-gcc.exe

# -- Flags --
# Flags for both compiler and assembler
CFLAGS=

#Flags for just the compiler
CCFLAGS=-ffreestanding -nostdlib -lgcc




.PHONY: all ldr_core ldr_head boot_core boot_head boot_head_chs mountdisk unmountdisk clean

# By default, build XtLdr Core
all: boot_head boot_core ldr_head ldr_core

# -- Boot Head --
boot_head: build/bin/boot_head_lba.img
	${PASME} burn build/bin/boot_head_lba.img -to "${TestDisk}" -srcOff 0x3E -dstOff ${PartitionStart}+0x3E -length 450

build/bin/boot_head_lba.img: src/boot_head.pa
	${PASME} transpile src/boot_head.pa -I ../../Libs/casm -D LBA_AVAILABLE -to build/boot_head_lba.asm
	${PASME} assemble  build/boot_head_lba.asm -to build/bin/boot_head_lba.img

# -- Boot Head [CHS] --
boot_head_chs: build/bin/boot_head_chs.img
	${PASME} burn build/bin/boot_head_lba.img -to "${TestDisk}" -srcOff 0x3E -dstOff ${PartitionStart}+0x3E -length 450

build/bin/boot_head_chs.img: src/boot_head.asm
	${PASME} transpile src/boot_head.asm -I ../../Libs/casm -to build/boot_head_chs.asm
	${PASME} assemble  build/boot_head_chs.asm -to build/bin/boot_head_chs.img




# -- Boot Core --
boot_core: build/bin/boot_core.img
	${PASME} burn build/bin/boot_core.img -to "${TestDisk}" -dstOff ${PartitionStart}+0x200 -length 2560

build/bin/boot_core.img: src/boot_core.pa
	${PASME} transpile src/boot_core.pa -I ../../Libs/casm -to build/boot_core.asm
	${PASME} assemble  build/boot_core.asm -to build/bin/boot_core.img




# -- Loader Head --
ldr_head: build/bin/LDRHEAD.BIN
	$(call mount-test-disk)
	copy "build\bin\LDRHEAD.BIN" "Z:\XTOS\LDRHEAD.BIN"
	$(call unmount-test-disk)

build/bin/LDRHEAD.BIN: src/xtloader_head.pa
	${PASME} transpile src/xtloader_head.pa -I ../../Libs/casm -to build/xtloader_head.asm
	${PASME} assemble  build/xtloader_head.asm -to build/bin/LDRHEAD.BIN




# -- Loader Core --
ldr_core: build/bin/XTLOADER.ELF
	$(call mount-test-disk)
	copy "build\bin\XTLOADER.ELF" "Z:\XTOS\XTLOADER.ELF"
	$(call unmount-test-disk)

# Final binary
build/bin/XTLOADER.ELF: build/ldr_core/stub.o build/ldr_core/core.o src/ldr_core/link.ld
	${C_COMPILER} -T src/ldr_core/link.ld -o build/bin/XTLOADER.ELF build/ldr_core/stub.o build/ldr_core/core.o ${CFLAGS} ${CCFLAGS}

# Assembly stub
build/ldr_core/stub.o: src/ldr_core/stub.s
	${C_ASSEMBLER} src/ldr_core/stub.s -o build/ldr_core/stub.o ${CFLAGS}

# C Body
build/ldr_core/core.o: src/ldr_core/core.c src/ldr_core/core.h
	${C_COMPILER} -c src/ldr_core/core.c -o build/ldr_core/core.o ${CFLAGS} ${CCFLAGS}


clean:
	del build\*.* /q
	del build\bin\*.* /q
	del build\ldr_core\*.* /q


# -- Utilities --
mountdisk:
	$(call mount-test-disk)

unmountdisk:
	$(call unmount-test-disk)

define mount-test-disk
	${PASME} mountdisk "${TestDisk}"
endef

define unmount-test-disk
	${PASME} unmountdisk "${TestDisk}"
endef