@echo off
call casm -i xtloader.csm -tti asm/xtloader.asm -ati bin/xtloader.bin
copy "bin\xtloader.bin" "L:\XtOS\XtLoader.bin"