@echo off
setlocal EnableExtensions EnableDelayedExpansion

set CASM=call scripts\casm
set Pasme=scripts\pasme
set Disk="../../Test Machines/vdisk.vhd"
set part=0x108000

if "%1"=="boot_head" (
	if "%2"=="lba" (
		%Pasme% transpile src/boot_head.asm -I ../../Libs/casm -D LBA_AVAILABLE -to build/boot_head_lba.asm
		%Pasme% assemble  build/boot_head_lba.asm -to build/bin/boot_head_lba.img
		%Pasme% burn      build/bin/boot_head_lba.img -to %Disk% -srcOff 0x3E -dstOff %part%+0x3E -length 450
	) else (
		%Pasme% transpile src/boot_head.asm -I ../../Libs/casm -D LBA_AVAILABLE -to build/boot_head_lba.asm
		%Pasme% assemble  build/boot_head_lba.asm -to build/bin/boot_head_lba.img
		%Pasme% burn      build/bin/boot_head_lba.img -to %Disk% -srcOff 0x3E -dstOff %part%+0x3E -length 450
	)
)

if "%1"=="boot_core" (
	!CASM! -If ../../Libs/casm -i src/boot_core.asm -tti build/boot_core.asm -ati build/bin/boot_core.img -off 0x0 -off !part!+0x200 -len 2560 -wt !VHD!
)

if "%1"=="ldr_head" (
	make xtldr_head
)

if "%1"=="ldr_core" (
	make xtldr_core
)
goto :eof

:build_failed
	echo Build failed.