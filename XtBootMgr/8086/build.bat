@echo off
echo Boot.csm
call casm boot.csm bin\boot.img
echo Core.csm
call casm core.csm bin\core.img
echo Done.