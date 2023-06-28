# -- Config --
TestDisk=../../Test Machines/vdisk.vhd
PartitionStart=0x10000

# -- Tools --
PASME=call scripts/pasme
C_COMPILER=../../Tools/GCC/bin/i386-elf-gcc.exe

# -- Flags --
# Pasme Transpiler flags
PT_FLAGS=-I ../../Libs

# Pasme Assembler flags
PA_FLAGS=-w-pp-macro-redef-multi

# Flags for just the GCC compiler
CCFLAGS=-ffreestanding -nostdlib -lgcc -Isrc/loader/stdlib -std=gnu99

.PHONY: all boot_lba boot_chs head bstrap loader loader_stdlib mountdisk unmountdisk clean

all: boot_lba head bstrap loader

# -- Boot [LBA] --
boot_lba: src/boot.pa
	${PASME} transpile src/boot.pa -D LBA_AVAILABLE -to build/boot.asm ${PT_FLAGS}
	${PASME} assemble build/boot.asm -to build/bin/boot.img
	${PASME} burn build/bin/boot.img -to "${TestDisk}" -srcOff 0x3E -dstOff ${PartitionStart}+0x3E -length 450

# -- Boot [CHS] --
boot_chs: src/boot.pa
	${PASME} transpile src/boot.pa -to build/boot.asm ${PT_FLAGS}
	${PASME} assemble  build/boot.asm -to build/bin/boot.img
	${PASME} burn build/bin/boot.img -to "${TestDisk}" -srcOff 0x3E -dstOff ${PartitionStart}+0x3E -length 450

# -- Head --
head: src/head.pa
	${PASME} transpile src/head.pa -to build/head.asm ${PT_FLAGS}
	${PASME} assemble  build/head.asm -to build/bin/head.img
	${PASME} burn build/bin/head.img -to "${TestDisk}" -dstOff ${PartitionStart}+0x200 -length 3072

# -- Bootstrapper --
bstrap: src/bootstrap.pa
	${PASME} transpile src/bootstrap.pa -to build/bootstrap.asm ${PT_FLAGS}
	${PASME} assemble  build/bootstrap.asm -to build/bin/BSTRAP.BIN

	$(call mount-test-disk)
	copy "build\bin\BSTRAP.BIN" "Z:\ZKOS\BSTRAP.BIN"
	$(call unmount-test-disk)


# -- Loader Core --
loader: build/bin/ZKLOADER.ELF
	$(call mount-test-disk)
	copy "build\bin\ZKLOADER.ELF" "Z:\ZKOS\ZKLOADER.ELF"
	$(call unmount-test-disk)

# Final binary
build/bin/ZKLOADER.ELF: loader_stdlib src/loader/link.ld build/loader/stub.o build/loader/core.o build/loader/vga_video.o build/loader/lmem.o build/loader/acpi.o
	${C_COMPILER} -T src/loader/link.ld -o build/bin/ZKLOADER.ELF build/loader/stub.o build/loader/core.o build/loader/vga_video.o build/loader/lmem.o build/loader/acpi.o build/loader/stdlib/string.o build/loader/stdlib/stdio.o ${CCFLAGS}

# Assembly stub
build/loader/stub.o: src/loader/stub.pa
	-mkdir build\loader
	${PASME} transpile src/loader/stub.pa -to build/loader/stub.asm
	yasm build/loader/stub.asm -o build/loader/stub.o -f elf

# C Body
build/loader/core.o: src/loader/core.c src/loader/core.h
	${C_COMPILER} -c src/loader/core.c -o build/loader/core.o ${CCFLAGS}

build/loader/vga_video.o: src/loader/vga_video.c src/loader/vga_video.h
	${C_COMPILER} -c src/loader/vga_video.c -o build/loader/vga_video.o ${CCFLAGS}

build/loader/lmem.o: src/loader/lmem.c src/loader/lmem.h
	${C_COMPILER} -c src/loader/lmem.c -o build/loader/lmem.o ${CCFLAGS}

build/loader/acpi.o: src/loader/acpi.c src/loader/acpi.h
	${C_COMPILER} -c src/loader/acpi.c -o build/loader/acpi.o ${CCFLAGS}

#Loader Stdlib
loader_stdlib: build/loader/stdlib/string.o build/loader/stdlib/stdio.o


build/loader/stdlib/string.o: src/loader/stdlib/string.c src/loader/stdlib/string.h
	-mkdir build\loader\stdlib
	${C_COMPILER} -c src/loader/stdlib/string.c -o build/loader/stdlib/string.o ${CCFLAGS}

build/loader/stdlib/stdio.o: src/loader/stdlib/stdio.c src/loader/stdlib/stdio.h
	${C_COMPILER} -c src/loader/stdlib/stdio.c -o build/loader/stdlib/stdio.o ${CCFLAGS}


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