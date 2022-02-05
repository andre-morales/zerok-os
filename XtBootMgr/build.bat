@echo off
setlocal EnableExtensions EnableDelayedExpansion
set CASM=scripts\casm
set Disk="..\Test Machines\vdisk.vhd"
if "%1"=="boot" (
	REM Compile boot.csm and save the compiled binary.
	REM Write 440 bytes of the compiled binary into the beginning of the specified test disk.
	!CASM! -If ../Libs/casm -i src/boot.asm -tti build/asm/boot.asm -ati build/bin/boot.img -off 0x0 -off 0x0 -len 440 -wt !Disk!
)
if "%1"=="core" (
	REM Compile core.csm and save the compiled binary.
	REM Write all the bytes of the compiled binary into the specified test disk 512 bytes after the beginning.
	!CASM! -If ../Libs/casm -i src/core.asm -tti build/asm/core.asm -ati build/bin/core.img -off 0x0 -off 0x200 -wt !Disk!
)