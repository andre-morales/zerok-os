PASME=..\\..\\Tools\\pasme
YASM=yasm

all: build/strings.o build/serial.o build/drive.o

build/serial.o: src/serial.asm serial.h
	$(PASME) transpile src/serial.asm -to build/serial.nasm -I .
	$(YASM) build/serial.nasm -f elf -o build/serial.o

build/strings.o: src/strings.asm strings.h
	$(PASME) transpile src/strings.asm -to build/strings.nasm -I .
	$(YASM) build/strings.nasm -f elf -o build/strings.o

build/drive.o: src/drive.asm drive.h
	$(PASME) transpile src/drive.asm -to build/drive.nasm -I .
	$(YASM) build/drive.nasm -f elf -o build/drive.o

clean:
	del build\*.* /q
	