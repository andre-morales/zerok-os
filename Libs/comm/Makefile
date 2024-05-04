PASME=..\\..\\Tools\\pasme
YASM=yasm

all: build/strings.o build/serial.o

build/serial.o: src/serial.asm src/serial.h
	$(PASME) transpile src/serial.asm -to build/serial.nasm
	$(YASM) build/serial.nasm -f elf -o build/serial.o

build/strings.o: src/strings.asm src/strings.h
	$(PASME) transpile src/strings.asm -to build/strings.nasm
	$(YASM) build/strings.nasm -f elf -o build/strings.o