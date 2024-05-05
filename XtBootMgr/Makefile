# -- Config --
TestDisk=../Test Machines/vdisk.vhd

# -- Tools --
PASME=call scripts/pasme
DEVTK=..\\Tools\\devtk
YASM=yasm
LD=..\\Tools\\ld

# -- Flags --
# Pasme Transpiler flags
PT_FLAGS=-I ../Libs

# Pasme Assembler flags
PA_FLAGS=-w-pp-macro-redef-multi

# Common lib built object folder
COMM=../Libs/comm/build/

.PHONY: all boot core clean

default:
	-@echo You must specify a target.
	-@echo Build targets: all, boot, core
	-@echo Tool targets: clean

all: boot core

# -- Boot --
boot: src/boot.asm src/boot.ld
	-@mkdir build\bin 
	$(PASME) transpile src/boot.asm -to build/boot.nasm $(PT_FLAGS)
	$(YASM) build/boot.nasm -f elf -o build/boot.o
	$(LD) build/boot.o -T src/boot.ld -o build/bin/boot.img
	$(DEVTK) burn build/bin/boot.img -to "$(TestDisk)" -length 440

# -- Core --
core: src/core.asm src/core.ld
	$(PASME) transpile src/core.asm -to build/core.nasm $(PT_FLAGS)
	$(YASM) build/core.nasm -f elf -o build/core.o
	$(LD) build/core.o $(COMM)/strings.o $(COMM)/serial.o $(COMM)/console.o $(COMM)/drive.o -T src/core.ld -o build/bin/core.img
	$(DEVTK) burn build/bin/core.img -to "$(TestDisk)" -dstOff 0x200

clean:
	-del build\*.* /q
	-del build\bin\*.* /q
