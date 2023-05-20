# -- Config --
TestDisk=../../Test Machines/vdisk.vhd
PartitionStart=0x10000

# -- Tools --
PASME=call scripts/pasme
C_ASSEMBLER=../../Tools/GCC/bin/i386-elf-as.exe
C_COMPILER=../../Tools/GCC/bin/i386-elf-gcc.exe

# -- Flags --
# Pasme Transpiler flags
PT_FLAGS=-I ../../Libs
# Flags for both GCC compiler and assembler
CFLAGS=
# Flags for just the GCC compiler
CCFLAGS=-ffreestanding -nostdlib -lgcc




.PHONY: all boot_lba boot_chs head bstrap loader mountdisk unmountdisk clean

all: boot_lba head bstrap loader

# -- Boot [LBA] --
boot_lba: src/boot.pa
	${PASME} transpile src/boot.pa -D LBA_AVAILABLE -to build/boot.asm ${PT_FLAGS}
	${PASME} assemble  build/boot.asm -to build/bin/boot.img
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
build/bin/ZKLOADER.ELF: build/loader/stub.o build/loader/core.o src/loader/link.ld
	${C_COMPILER} -T src/loader/link.ld -o build/bin/ZKLOADER.ELF build/loader/stub.o build/loader/core.o ${CFLAGS} ${CCFLAGS}

# Assembly stub
build/loader/stub.o: src/loader/stub.s
	-mkdir build\loader
	${C_ASSEMBLER} src/loader/stub.s -o build/loader/stub.o ${CFLAGS}

# C Body
build/loader/core.o: src/loader/core.c src/loader/core.h
	${C_COMPILER} -c src/loader/core.c -o build/loader/core.o ${CFLAGS} ${CCFLAGS}


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