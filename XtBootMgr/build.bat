@echo off
setlocal EnableExtensions EnableDelayedExpansion

set Pasme=scripts\pasme
set Disk="..\Test Machines\vdisk.vhd"

if "%2"=="noburn" (
	set Disk=""
)

if "%1"=="boot" (
	REM Compile boot.csm and save the compiled binary.
	REM Write 440 bytes of the compiled binary into the beginning of the specified test disk.
	
	%Pasme% transpile src/boot.pa -I ../Libs -to build/asm/boot.asm
	%Pasme% assemble  build/asm/boot.asm -to build/bin/boot.img
	%Pasme% burn      build/bin/boot.img -to %Disk% -length 440
) else if "%1"=="core" (
	REM Compile core.csm and save the compiled binary.
	REM Write all the bytes of the compiled binary into the specified test disk 512 bytes after the beginning.

	%Pasme% transpile src/core.pa -I ../Libs -to build/asm/core.asm
	%Pasme% assemble  build/asm/core.asm -to build/bin/core.img
	%Pasme% burn      build/bin/core.img -to %Disk% -dstOff 0x200
) else (
	echo Invalid target.
)