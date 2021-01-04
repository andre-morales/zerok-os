@echo off
echo Boot CHS
call casm vbr_boot_chs.csm bin\vbr_boot_chs.img
echo Boot LBA
call casm vbr_boot_lba.csm bin\vbr_boot_lba.img
echo Core
call casm vbr_core.csm bin\vbr_core.img
echo Done.