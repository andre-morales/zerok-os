# XtLoader
This is the bootloader XtOS uses. 
XtLoader is written specifically with FAT16 partitions in mind, and
is divided in multiple stages.

## Stage 1
Boot Head.

Available in both CHS and LBA variants. It fits in the reserved bytes
of the FAT16 VBR. It is 450 bytes in length and is responsible for
finding Stage 2 in the partition tree and loading it.
Files:
- src/boothead.csm
- build/boot_head_chs.asm
- build/boot_head_lba.asm
- bin/boot_head_chs.img
- bin/boot_head_lba.img
 
## Stage 2
Boot Core.

Written in the reserved sectors right after the VBR. It's solely responsible for
loading Stage 3 from the disk.
Files:
- src/core_head.csm
- build/core_head.asm
- bin/core_head.img
 
## Stage 3
XtLoader Head
An actual binary file in the disk.

Files:
- src/ldrhead.csm
- build/ldrhead.asm
- bin/LDRHEAD.BIN

## Stage 4
XtLoader Core

Files:
- bin/XTLOADER.ELF