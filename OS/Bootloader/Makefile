# -- Config --
TestDisk=../../Test Machines/vdisk.vhd
PartitionStart=0x10000

# -- Tools --
PASME=tools\pasme
DEVTK=tools\devtk
YASM=yasm
LD=tools\ld
# -- Flags --
# Pasme Transpiler flags
PT_FLAGS=-I ../../Libs

# Pasme Assembler flags
PA_FLAGS=-w-pp-macro-redef-multi

.PHONY: all boot_lba boot_chs head bstrap mountdisk unmountdisk clean

default:
	-@echo You must specify a target.
	-@echo Build targets: all, boot_lba, boot_chs, head, bstrap, loader
	-@echo Tool targets: clean, mountdisk, unmountdisk

all: boot_lba head bstrap loader

# -- Boot [LBA] --
boot_lba: Bootstrap/boot.asm
	-mkdir build\bstrap
	-mkdir build\bin\bstrap
	${PASME} transpile Bootstrap/boot.asm -D LBA_AVAILABLE -to build/bstrap/boot.nasm ${PT_FLAGS}
	${YASM} build/bstrap/boot.nasm -f bin -o build/bin/bstrap/boot.img 
	${DEVTK} burn build/bin/bstrap/boot.img -to "${TestDisk}" -srcOff 0x3E -dstOff ${PartitionStart}+0x3E -length 450

# -- Boot [CHS] --
boot_chs: Bootstrap/boot.asm 
	-@mkdir build\bstrap
	-@mkdir build\bin\bstrap
	${PASME} transpile Bootstrap/boot.asm -to build/bstrap/boot.nasm ${PT_FLAGS}
	${PASME} assemble  build/bstrap/boot.nasm -to build/bin/bstrap/boot.img
	${DEVTK} burn build/bin/bstrap/boot.img -to "${TestDisk}" -srcOff 0x3E -dstOff ${PartitionStart}+0x3E -length 450

# -- Head --
head: Bootstrap/head.asm
	${PASME} transpile Bootstrap/head.asm -to build/bstrap/head.nasm ${PT_FLAGS}
	${PASME} assemble  build/bstrap/head.nasm -to build/bin/bstrap/head.img
	${DEVTK} burn build/bin/bstrap/head.img -to "${TestDisk}" -dstOff ${PartitionStart}+0x200 -length 3072
	
# -- Bootstrapper --
bstrap: Bootstrap/bootstrap.asm
	${PASME} transpile Bootstrap/bootstrap.asm -to build/bstrap/bootstrap.nasm ${PT_FLAGS}
	${PASME} assemble  build/bstrap/bootstrap.nasm -to build/bin/bstrap/BSTRAP.BIN
	copy "build\bin\bstrap\BSTRAP.BIN" "dropbox\ZKOS\BSTRAP.BIN"

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
