@echo off
casm -i vbr_core.csm -tti asm/vbr_core.asm -ati bin/vbr_core.img -off 0x0 -off 0x200200 -len 2560 -wto "..\..\Disks\XtOS Machine-flat.vmdk"