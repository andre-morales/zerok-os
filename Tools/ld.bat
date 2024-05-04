@echo off
pushd %cd%
"%~dp0\GCC\bin\i386-elf-ld.exe" %*
popd