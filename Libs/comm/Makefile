PASME=..\\..\\Tools\\pasme
YASM=yasm

all: build/strings.o build/serial.o build/drive.o build/console.o build/fat1x.o

build/serial.o: src/serial.asm serial.h
	$(PASME) transpile src/serial.asm -to build/serial.nasm -I .
	$(YASM) build/serial.nasm -f elf -o build/serial.o

build/strings.o: src/strings.asm strings.h
	$(PASME) transpile src/strings.asm -to build/strings.nasm -I .
	$(YASM) build/strings.nasm -f elf -o build/strings.o

build/console.o: src/console.asm console.h
	$(PASME) transpile src/console.asm -to build/console.nasm -I .
	$(YASM) build/console.nasm -f elf -o build/console.o

build/drive.o: src/drive.asm drive.h
	$(PASME) transpile src/drive.asm -to build/drive.nasm -I .
	$(YASM) build/drive.nasm -f elf -o build/drive.o

build/fat1x.o: src/fat1x.asm fat1x.h
	$(PASME) transpile src/fat1x.asm -to build/fat1x.nasm -I .
	$(YASM) build/fat1x.nasm -f elf -o build/fat1x.o

clean:
	del build\*.* /q
	