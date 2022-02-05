@..\..\Tools\GCC\bin\i686-elf-gcc.exe -c @src\ldr_core\core.c -o @build\ldr_core\core.o ${CFLAGS}
echo Built core.
@..\..\Tools\GCC\bin\i686-elf-as.exe @src\ldr_core\stub.s -o @build\ldr_core\stub.o
echo Built stub.
@..\..\Tools\GCC\bin\i686-elf-gcc.exe -T @src\ldr_core\link.ld -o @build\bin\XTLOADER.ELF @build\ldr_core\stub.o @build\ldr_core\core.o ${CFLAGS}
echo Linked.