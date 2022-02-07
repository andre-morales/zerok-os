.PHONY: all xtldr_core mountdisk unmountdisk

CFLAGS=-ffreestanding -std=gnu99 -nostdlib -lgcc -Qn -O2
RC=call scripts\rc -sh C:\cygwin64\bin\bash.exe -c

all: xtldr_core

xtldr_core: build\bin\XTLOADER.ELF
	diskpart /s scripts\mountdisk.dps > nul
	copy "build\bin\XTLOADER.ELF" "Z:\XTOS\XTLOADER.ELF"
	diskpart /s scripts\unmountdisk.dps > nul

build\bin\XTLOADER.ELF: build\ldr_core\stub.o build\ldr_core\core.o src\ldr_core\link.ld
	${RC} @..\..\Tools\GCC\bin\i686-elf-gcc.exe -T @src\ldr_core\link.ld -o @build\bin\XTLOADER.ELF @build\ldr_core\stub.o @build\ldr_core\core.o ${CFLAGS}

build\ldr_core\stub.o: src\ldr_core\stub.s
	${RC} @..\..\Tools\GCC\bin\i686-elf-as.exe @src\ldr_core\stub.s -o @build\ldr_core\stub.o
	
build\ldr_core\core.o: src\ldr_core\core.c src\ldr_core\core.h
	${RC} @..\..\Tools\GCC\bin\i686-elf-gcc.exe -c @src\ldr_core\core.c -o @build\ldr_core\core.o ${CFLAGS}
	
mountdisk:
	diskpart /s scripts\mountdisk.dps > nul

unmountdisk:
	diskpart /s scripts\unmountdisk.dps > nul	