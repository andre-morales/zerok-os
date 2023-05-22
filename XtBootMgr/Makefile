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

all: boot core

# -- Boot --
boot: src/boot.pa
	-mkdir build\bin
	${PASME} transpile src/boot.pa -to build/boot.asm ${PT_FLAGS}
	${PASME} assemble  build/boot.asm -to build/bin/boot.img
	${PASME} burn      build/bin/boot.img -to "${TestDisk}" -length 440

# -- Core --
core: src/core.pa
	${PASME} transpile src/core.pa -to build/core.asm ${PT_FLAGS}
	${PASME} assemble  build/core.asm -to build/bin/core.img
	${PASME} burn      build/bin/core.img -to "${TestDisk}" -dstOff 0x200

clean:
	del build\*.* /q
	del build\bin\*.* /q
