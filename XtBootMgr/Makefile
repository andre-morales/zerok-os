# -- Config --
TestDisk=..\\Testing\\vdisk.vhd

# -- Tools --
PASME=..\\Tools\pasme
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
	@echo You must specify a target.
	@echo Build targets: all, boot, core
	@echo Tool targets: clean

all: boot core

# -- Boot --
boot: src/boot.asm src/boot.ld | build/bin
	$(PASME) transpile src/boot.asm -to build/boot.nasm $(PT_FLAGS)
	$(YASM) build/boot.nasm -f elf -o build/boot.o
	$(LD) build/boot.o -T src/boot.ld -o build/bin/boot.img
	$(DEVTK) burn build/bin/boot.img -to "$(TestDisk)" -length 440
	
# -- Core --
core: build/core.o build/video.o build/partitions.o src/core.ld | build/bin
	$(LD) build/core.o build/video.o build/partitions.o $(COMM)/mem.o $(COMM)/strings.o $(COMM)/serial.o $(COMM)/console.o $(COMM)/drive.o -T src/core.ld -o build/bin/core.img
	$(DEVTK) burn build/bin/core.img -to "$(TestDisk)" -dstOff 0x200

build/core.o: src/core.asm | build/bin
	$(PASME) transpile src/core.asm -to build/core.nasm $(PT_FLAGS)
	$(YASM) build/core.nasm -f elf -o build/core.o

build/partitions.o: src/partitions.asm | build/bin
	$(PASME) transpile src/partitions.asm -to build/partitions.nasm $(PT_FLAGS)
	$(YASM) build/partitions.nasm -f elf -o build/partitions.o

build/video.o: src/video.asm | build/bin
	$(PASME) transpile src/video.asm -to build/video.nasm $(PT_FLAGS)
	$(YASM) build/video.nasm -f elf -o build/video.o

build/bin:
	-mkdir build\bin 2> nul

clean:
	-del build\*.* /q
	-del build\bin\*.* /q
