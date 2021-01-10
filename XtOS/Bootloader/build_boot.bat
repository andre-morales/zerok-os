@echo off
casm -i vbr_boot_chs.csm -tti asm/vbr_boot_chs.asm -ati bin/vbr_boot_chs.img -off 0x3E -off 0x20003E -len 450 -wto "..\..\Disks\XtOS Machine-flat.vmdk"