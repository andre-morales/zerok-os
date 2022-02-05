8086 build of XtBootMgr.

The current design of XtBootMgr requires the Boot section to be the 
very first sector of the disk, and also requires the core to be installed
in sector 2 onwards. Future designs might allow for more flexibility in
this regard.

# Boot
Stage 1. The 512-bytes long section of the bootloader.
Mostly responsable for loading stage 2 but also contains 
code for some level of boot debugging.
The code for this section lives in boot.csm, and is compiled to boot.img.


# Core
Stage 2. Varies in size, reads the partitions on the disk
and allows the user to boot any of them through a simplified
text-based GUI.
The code for this section lives in core.csm, and is compiled to core.img.