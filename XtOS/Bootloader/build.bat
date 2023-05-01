@echo off
setlocal EnableExtensions EnableDelayedExpansion

set CASM=call scripts\casm
set Pasme=scripts\pasme
set Disk="../../Test Machines/vdisk.vhd"
set partition=0x108000

if "%1"=="boot_head" (
	if "%2"=="lba" (
		%Pasme% transpile src/boot_head.asm -I ../../Libs/casm -D LBA_AVAILABLE -to build/boot_head_lba.asm
		%Pasme% assemble  build/boot_head_lba.asm -to build/bin/boot_head_lba.img
		%Pasme% burn      build/bin/boot_head_lba.img -to %Disk% -srcOff 0x3E -dstOff %partition%+0x3E -length 450
	) else (
		%Pasme% transpile src/boot_head.asm -I ../../Libs/casm -D LBA_AVAILABLE -to build/boot_head_lba.asm
		%Pasme% assemble  build/boot_head_lba.asm -to build/bin/boot_head_lba.img
		%Pasme% burn      build/bin/boot_head_lba.img -to %Disk% -srcOff 0x3E -dstOff %partition%+0x3E -length 450
	)
)

if "%1"=="boot_core" (
	%Pasme% transpile src/boot_core.asm -I ../../Libs/casm -to build/boot_core.asm
	%Pasme% assemble  build/boot_core.asm -to build/bin/boot_core.img
	%Pasme% burn      build/bin/boot_core.img -to %Disk% -dstOff %partition%+0x200 -length 2560
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