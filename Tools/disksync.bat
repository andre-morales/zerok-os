@echo off
set "params=%*"
cd /d "%~dp0"

if exist "%temp%\getadmin.vbs" del "%temp%\getadmin.vbs"

fsutil dirty query %systemdrive% 1>nul 2>nul

if %errorlevel% neq 0 (
	echo Set UAC = CreateObject^("Shell.Application"^) : UAC.ShellExecute "cmd", "/k cd ""%~sdp0"" && %~s0 %params%", "", "runas", 1 >> "%temp%\getadmin.vbs"
	wscript "%temp%\getadmin.vbs"
	exit /B
) else (
	devtk syncdisk "../Testing/vdisk.vhd" -with ..\Dropbox\ZKOS -at Z:\ZKOS\
)