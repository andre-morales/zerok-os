# -- Config --
TestDisk=../Test Machines/vdisk.vhd

# -- Tools --
PASME=call scripts/pasme

# -- Flags --
# Pasme Transpiler flags
PT_FLAGS=-I ../Libs

# Pasme Assembler flags
PA_FLAGS=-w-pp-macro-redef-multi

.PHONY: all boot core clean

default:
	-@echo You must specify a target.
	-@echo Build targets: all, boot, core
	-@echo Tool targets: clean

all: boot core

# -- Boot --
boot: src/boot.asm
	-@mkdir build\bin
	${PASME} transpile src/boot.asm -to build/boot.nasm ${PT_FLAGS}
	${PASME} assemble  build/boot.nasm -to build/bin/boot.img
	${PASME} burn      build/bin/boot.img -to "${TestDisk}" -length 440

# -- Core --
core: src/core.asm
	${PASME} transpile src/core.asm -to build/core.nasm ${PT_FLAGS}
	${PASME} assemble  build/core.nasm -to build/bin/core.img
	${PASME} burn      build/bin/core.img -to "${TestDisk}" -dstOff 0x200

clean:
	del build\*.* /q
	del build\bin\*.* /q
