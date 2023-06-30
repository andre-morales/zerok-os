# -- Config --
TestDisk=../../Test Machines/vdisk.vhd
PartitionStart=0x10000

# -- Tools --
PASME=tools\pasme
DEVTK=tools\devtk

# -- Flags --
# Pasme Transpiler flags
PT_FLAGS=-I ../../Libs

# Pasme Assembler flags
PA_FLAGS=-w-pp-macro-redef-multi

.PHONY: all boot_lba boot_chs head bstrap mountdisk unmountdisk clean

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

	copy "build\bin\bstrap\BSTRAP.BIN" "diskDropbox\ZKOS\BSTRAP.BIN"

# -- Loader Core --

loader:
	make -C Loader32 all

clean:
	make -C Loader32 clean
	del build\*.* /q
	del build\bin\*.* /q
	del build\loader\*.* /q
	del build\loader\stdlib\*.* /q
	del build\bstrap\*.* /q

# -- Utilities --
syncdisk:
	${DEVTK} syncdisk "${TestDisk}" -with diskDropbox\ZKOS -at Z:\ZKOS\
	
mountdisk:
	${DEVTK} mountdisk "${TestDisk}"

unmountdisk:
	${DEVTK} unmountdisk "${TestDisk}"
