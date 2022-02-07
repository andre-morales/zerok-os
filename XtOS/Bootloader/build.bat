@echo off
setlocal EnableExtensions EnableDelayedExpansion

set RC=call scripts\rc -sh C:\cygwin64\bin\bash.exe
set CASM=call scripts\casm
set VHD="..\..\Test Machines\vdisk.vhd"
set part=0x108000

if "%1"=="boot_head" (
	if "%2"=="lba" (
		!CASM! -If ../../Libs/casm -+d LBA_AVAILABLE -i src/boot_head.asm -tti build/boot_head_lba.asm -ati build/bin/boot_head_lba.img -off 0x3E -off !part!+0x3E -len 450 -wt !VHD!
	) else (
		!CASM! -If ../../Libs/casm --d LBA_AVAILABLE -i src/boot_head.asm -tti build/boot_head_chs.asm -ati build/bin/boot_head_chs.img -off 0x3E -off !part!+0x3E -len 450 -wt !VHD!
	)
)
if "%1"=="boot_core" (
	!CASM! -If ../../Libs/casm -i src/boot_core.asm -tti build/boot_core.asm -ati build/bin/boot_core.img -off 0x0 -off !part!+0x200 -len 2560 -wt !VHD!
)
if "%1"=="ldr_head" (
	!CASM! -If ../../Libs/casm -i src/xtloader_head.asm -tti build/xtloader_head.asm -ati build/bin/LDRHEAD.BIN
	echo Mounting...
	diskpart /s scripts\mountdisk.dps > nul
	if not !ERRORLEVEL!==0 (
		echo Mount failed.
		goto :eof
	)
	copy "build\bin\LDRHEAD.BIN" "Z:\XTOS\LDRHEAD.BIN"
	echo Done.
	if not "%2"=="-keep" (
		diskpart /s scripts\unmountdisk.dps > nul
	)
)
if "%1"=="ldr_core" (
	make xtldr_core
)
goto :eof

:build_failed
	echo Build failed.