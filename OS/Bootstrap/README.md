# ZkLoader
This is the bootloader ZeroK OS uses. 
ZkLoader is written specifically with FAT16 partitions in mind, and
is divided in multiple stages.

## Stage 1: VBR Boot
Available in both CHS and LBA variants. It is burned in the reserved bytes
of the FAT16 VBR. It is 450 bytes in length and is responsible for
finding Stage 2 in the partition tree and loading it.

Sequence:
* Load MBR of the current disk;
* Find itself by loading the disk partition's VBRs (including the Extended Partition);
* Load the next few sectors necessary for Stage 2 and checks signature;
* Pass control to Stage 2.

Files:
- src/boot.pa
- build/boot.asm
- bin/boot_chs.img
- bin/boot_lba.img

Build Command: make boot_lba OR make boot_chs
 
## Stage 2: Partition Head
Burned in the reserved sectors right after the VBR.
It's responsible for finding Stage 3 stored at "ZKOS/BOOTSTRAP.BIN" in the actual filesystem, then loading it.

Sequence:
* Greet the user with a boot message indicating everything went good so far;
* Obtain information about the disk layout and supported reading modes (LBA / CHS);
* Read and parse the VBR of the current boot partiton;
* Interpret the FAT16 system to locate Stage 3;
* Load it and give it control.

Files:
- src/head.pa
- build/head.asm
- bin/head.img

Build Command: make head

## Stage 3: ZkLoader Bootstrapper
Stored in the filesystem. It is responsible for loading a 32-bit ELF bootloader program
written in C.

Sequence:
* Utilize the partition reading procedures already stabilished by Stage 2 to locate ZKLOADER.ELF;
* Read it into memory and parse its contents;
* Place all the necessary ELF sections into the right memory locations;
* Set up the x86 GDT;
* Set up paging structures;
* Enable 32-bit mode;
* Give control to Stage 4.

Files:
- src/bootstrap.pa
- build/bootstrap.asm
- bin/BSTRAP.BIN

Build Command: make bstrap

## Stage 4: ZkLoader
Written in regular C and compiled with a 32-bit GCC cross-compiler.

Files:
- bin/ZKLOADER.ELF

Build Command: make loader