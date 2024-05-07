@echo off
pushd %cd%
"%~dp0\GCC\bin\i386-elf-gcc.exe" %*
popd
exit /b %errorlevel%