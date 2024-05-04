# -- Config --
TestDisk=../../Test Machines/vdisk.vhd
PartitionStart=0x10000

# -- Tools --
PASME=..\..\Tools\pasme
DEVTK=..\..\Tools\devtk
LD=..\..\Tools\ld
YASM=yasm

# -- Flags --
# Pasme Transpiler flags
PT_FLAGS=-I ../../Libs

# Pasme Assembler flags
PA_FLAGS=-w-pp-macro-redef-multi

.PHONY: all boot_lba boot_chs head bstrap mountdisk unmountdisk clean

default:
	-@echo You must specify a target.
	-@echo Build targets: all, boot_lba, boot_chs, head, bstrap
	-@echo Tool targets: clean, mountdisk, unmountdisk

all: boot_lba head bstrap loader

# -- Boot [LBA] --
boot_lba: src/boot.asm
	-@mkdir build\\int 2> nul
	-@mkdir build\\bin 2> nul
	${PASME} transpile src/boot.asm -D LBA_AVAILABLE -to build/int/boot.nasm ${PT_FLAGS}
	${YASM} build/int/boot.nasm -f elf -o build/int/boot.o
	${LD} build/int/boot.o -T src/boot.ld -o build/bin/boot.bin
	${DEVTK} burn-vbr build/bin/boot.bin -to "${TestDisk}" -partition 0

# -- Boot [CHS] --
boot_chs: src/boot.asm 
	-@mkdir build\\int 2> nul
	-@mkdir build\\bin 2> nul
	${PASME} transpile src/boot.asm -to build/int/boot.nasm ${PT_FLAGS}
	${YASM} build/int/boot.nasm -f elf -o build/int/boot.o
	${LD} build/int/boot.o -T src/boot.ld -o build/bin/boot.img
	${DEVTK} burn-vbr build/bin/boot.bin -to "${TestDisk}" -partition 0

# -- Head --
head: src/head.asm
	${PASME} transpile src/head.asm -to build/int/head.nasm ${PT_FLAGS}
	${YASM} build/int/head.nasm -f elf -o build/int/head.o
	${LD} build/int/head.o -T src/head.ld -o build/bin/head.img
	${DEVTK} burn-reserved-sectors build/bin/head.img -to "${TestDisk}" -partition 0
	
# -- srcper --
bstrap: src/bootstrap.asm
	${PASME} transpile src/bootstrap.asm -to build/bstrap/bootstrap.nasm ${PT_FLAGS}
	${PASME} assemble  build/bstrap/bootstrap.nasm -to build/bin/bstrap/BSTRAP.BIN
	copy "build\bin\bstrap\BSTRAP.BIN" "..\..\Dropbox\ZKOS\BSTRAP.BIN"

# -- Loader Core --
loader:
	make -C Loader32 all

# -- Utilities --
clean:
	make -C Loader32 clean
	del build\*.* /q
	del build\bin\*.* /q
	del build\loader\*.* /q
	del build\loader\stdlib\*.* /q
	del build\bstrap\*.* /q

syncdisk:
	${DEVTK} syncdisk "${TestDisk}" -with diskDropbox\ZKOS -at Z:\ZKOS\
	
mountdisk:
	${DEVTK} mountdisk "${TestDisk}"

unmountdisk:
	${DEVTK} unmountdisk "${TestDisk}"