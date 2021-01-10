@echo off
casm -i core.csm -tti asm/core.asm -ati bin/core.img -off 0x0 -off 0x200 -wto "..\..\Disks\XtOS Machine-flat.vmdk"
