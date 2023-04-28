.PHONY: all xtldr_core xtldr_head mountdisk unmountdisk

CFLAGS=-march=i386 -nostdlib -Qn -O2
CCFLAGS=-ffreestanding -std=gnu99 -lgcc 
RC=call scripts\rc -sh C:\cygwin64\bin\bash.exe -c
CASM=call scripts\casm
all: xtldr_core

# XtLoader Head
xtldr_head: build\bin\LDRHEAD.BIN
	diskpart /s scripts\mountdisk.dps > nul
	copy "build\bin\LDRHEAD.BIN" "Z:\XTOS\LDRHEAD.BIN"
	diskpart /s scripts\unmountdisk.dps > nul

build\bin\LDRHEAD.BIN: src/xtloader_head.asm
	${CASM} -If ../../Libs/casm -i src/xtloader_head.asm -tti build/xtloader_head.asm -ati build/bin/LDRHEAD.BIN

# XtLoader Core
xtldr_core: build\bin\XTLOADER.ELF
	diskpart /s scripts\mountdisk.dps > nul
	copy "build\bin\XTLOADER.ELF" "Z:\XTOS\XTLOADER.ELF"
	diskpart /s scripts\unmountdisk.dps > nul

build\bin\XTLOADER.ELF: build\ldr_core\stub.o build\ldr_core\core.o src\ldr_core\link.ld
	${RC} @..\..\Tools\GCC\bin\i686-elf-gcc.exe -T @src\ldr_core\link.ld -o @build\bin\XTLOADER.ELF @build\ldr_core\stub.o @build\ldr_core\core.o ${CFLAGS} ${CCFLAGS}

build\ldr_core\stub.o: src\ldr_core\stub.s
	${RC} @..\..\Tools\GCC\bin\i686-elf-as.exe @src\ldr_core\stub.s -o @build\ldr_core\stub.o ${CFLAGS}
	
build\ldr_core\core.o: src\ldr_core\core.c src\ldr_core\core.h
	${RC} @..\..\Tools\GCC\bin\i686-elf-gcc.exe -c @src\ldr_core\core.c -o @build\ldr_core\core.o ${CFLAGS} ${CCFLAGS}

#Utilities
mountdisk:
	diskpart /s scripts\mountdisk.dps > nul

unmountdisk:
	diskpart /s scripts\unmountdisk.dps > nul	