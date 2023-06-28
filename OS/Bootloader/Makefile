# -- Config --
TestDisk=../../Test Machines/vdisk.vhd
PartitionStart=0x10000

# -- Tools --
PASME=java -jar "..\..\Tools\Pasme\target\Pasme-1.0.jar"
DEVTK=java -jar "..\..\Tools\DevToolkit\dist\DevToolkit.jar"
C_COMPILER=../../Tools/GCC/bin/i386-elf-gcc.exe

# -- Flags --
# Pasme Transpiler flags
PT_FLAGS=-I ../../Libs

# Pasme Assembler flags
PA_FLAGS=-w-pp-macro-redef-multi

# Flags for just the GCC compiler
CCFLAGS=-ffreestanding -nostdlib -lgcc -Iloader/stdlib -std=gnu99

.PHONY: all boot_lba boot_chs head bstrap loader loader_stdlib mountdisk unmountdisk clean

all: boot_lba head bstrap loader

# -- Boot [LBA] --
boot_lba: bstrap/boot.pa
	-mkdir build\bstrap
	-mkdir build\bin\bstrap
	${PASME} transpile bstrap/boot.pa -D LBA_AVAILABLE -to build/bstrap/boot.asm ${PT_FLAGS}
	${PASME} assemble build/bstrap/boot.asm -to build/bin/bstrap/boot.img
	${DEVTK} burn build/bin/bstrap/boot.img -to "${TestDisk}" -srcOff 0x3E -dstOff ${PartitionStart}+0x3E -length 450

# -- Boot [CHS] --
boot_chs: bstrap/boot.pa
	-mkdir build\bstrap
	-mkdir build\bin\bstrap
	${PASME} transpile bstrap/boot.pa -to build/bstrap/boot.asm ${PT_FLAGS}
	${PASME} assemble  build/bstrap/boot.asm -to build/bin/bstrap/boot.img
	${DEVTK} burn build/bin/bstrap/boot.img -to "${TestDisk}" -srcOff 0x3E -dstOff ${PartitionStart}+0x3E -length 450

# -- Head --
head: bstrap/head.pa
	${PASME} transpile bstrap/head.pa -to build/bstrap/head.asm ${PT_FLAGS}
	${PASME} assemble  build/bstrap/head.asm -to build/bin/bstrap/head.img
	${DEVTK} burn build/bin/bstrap/head.img -to "${TestDisk}" -dstOff ${PartitionStart}+0x200 -length 3072

# -- Bootstrapper --
bstrap: bstrap/bootstrap.pa
	${PASME} transpile bstrap/bootstrap.pa -to build/bstrap/bootstrap.asm ${PT_FLAGS}
	${PASME} assemble  build/bstrap/bootstrap.asm -to build/bin/bstrap/BSTRAP.BIN

	$(call mount-test-disk)
	copy "build\bin\bstrap\BSTRAP.BIN" "Z:\ZKOS\BSTRAP.BIN"
	$(call unmount-test-disk)


# -- Loader Core --
loader: build/bin/ZKLOADER.ELF
	$(call mount-test-disk)
	copy "build\bin\ZKLOADER.ELF" "Z:\ZKOS\ZKLOADER.ELF"
	$(call unmount-test-disk)

# Final binary
build/bin/ZKLOADER.ELF: loader_stdlib loader/link.ld build/loader/stub.o build/loader/core.o build/loader/vga_video.o build/loader/lmem.o build/loader/acpi.o
	${C_COMPILER} -T loader/link.ld -o build/bin/ZKLOADER.ELF build/loader/stub.o build/loader/core.o build/loader/vga_video.o build/loader/lmem.o build/loader/acpi.o build/loader/stdlib/string.o build/loader/stdlib/stdio.o ${CCFLAGS}

# Assembly stub
build/loader/stub.o: loader/stub.pa
	-mkdir build\loader
	${PASME} transpile loader/stub.pa -to build/loader/stub.asm
	yasm build/loader/stub.asm -o build/loader/stub.o -f elf

# C Body
build/loader/core.o: loader/core.c loader/core.h
	${C_COMPILER} -c loader/core.c -o build/loader/core.o ${CCFLAGS}

build/loader/vga_video.o: loader/vga_video.c loader/vga_video.h
	${C_COMPILER} -c loader/vga_video.c -o build/loader/vga_video.o ${CCFLAGS}

build/loader/lmem.o: loader/lmem.c loader/lmem.h
	${C_COMPILER} -c loader/lmem.c -o build/loader/lmem.o ${CCFLAGS}

build/loader/acpi.o: loader/acpi.c loader/acpi.h
	${C_COMPILER} -c loader/acpi.c -o build/loader/acpi.o ${CCFLAGS}

#Loader Stdlib
loader_stdlib: build/loader/stdlib/string.o build/loader/stdlib/stdio.o


build/loader/stdlib/string.o: loader/stdlib/string.c loader/stdlib/string.h
	-mkdir build\loader\stdlib
	${C_COMPILER} -c loader/stdlib/string.c -o build/loader/stdlib/string.o ${CCFLAGS}

build/loader/stdlib/stdio.o: loader/stdlib/stdio.c loader/stdlib/stdio.h
	${C_COMPILER} -c loader/stdlib/stdio.c -o build/loader/stdlib/stdio.o ${CCFLAGS}


clean:
	del build\*.* /q
	del build\bin\*.* /q
	del build\loader\*.* /q


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