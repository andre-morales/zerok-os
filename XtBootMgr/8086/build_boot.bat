@echo off
casm -i boot.csm -tti asm/boot.asm -ati bin/boot.img -off 0x0 -off 0x0 -len 440 -wto "..\..\Disks\XtOS Machine-flat.vmdk"