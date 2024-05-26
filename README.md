# 🧊 ZeroK OS 🧊
<div align="center">

![C](https://img.shields.io/badge/c-%2300599C.svg?style=for-the-badge&logo=c&logoColor=white)
![Java](https://img.shields.io/badge/java-%23ED8B00.svg?style=for-the-badge&logo=openjdk&logoColor=white)

</div>

This is an experimental hobby operating system intended for study of low level languages such as **Assembly**, **C** and **C++**, OS architecture, CPU inner workings and many other things.

This project is also meant to be developed from **ground-up**. That is, it does not depend on any libraries or software beyond what is absolutely required (such as a compiler). This means writing custom tooling, custom language parsers, bootloader and bootmanager.

## :bulb: Current Progress
As of right now, **ZeroK** only performs Bootloader chores. Much emphasis has been put on **not** creating incompatible partition formats or file formats, which is why plenty of time has been spent designing a boot process that respects as many standards as possible. Furthermore, **ZeroK** aims to be as flexible as possible, and can be installed on any sectored device. Doing this required meticulous designing of the boot process.

The boot process for the OS looks like this:
- **Stage 1:** Stored in the FAT partition boot record (512 bytes in size). It uses BIOS interrupts to look for and load the next stage sectors. Written in 16-bit assembly code.
- **Stage 2:** Stored in the reserved FAT sectors, loads and interprets the FAT filesystem looking for the next stage binary file stored regularly on the disk. Written in 16-bit assembly.
- **Stage 3:** Stored in the disk. Locates an ELF executable file also stored in the FAT filesystem, sets up paging structures, switches the processor to 32 bit mode, then executes the file. Written in both 16-bit and 32-bit assembly.
- **Stage 4:** Stored in the disk and written completely in C with just a small assembly stub. Responsible for all the bootloader chores, such as identifying hardware, creating memory structures, loading drivers, etc.

The next steps are improving hardware detection in order to load driver files in memory. Also, a memory allocator should definitely be present in these operations to aid flexibility.

## :arrow_forward: Testing and Debugging
Testing of **ZeroK** can be done on any Virtual Machine or x86 emulator program. A few tools have been tested and proven quite useful:
- **VMware, VirtualBox**: Serve as a general-purpose testing ground. They don't include simple built-in debugging, but do allow for serial port debugging. 
- **86Box, PCem**: Can emulate really old hardware combinations. Only allow serial debugging.
- **Bochs**: Complete x86 emulator and step-by-step machine code debugger.
- **YAT + Com0Com**: Allow sending and receiving messages through virtual serial ports. Very useful when the video system isn't working properly.

## :toolbox: Custom Tooling
Writing an Operating System from scratch is _hard_. It requires very specific knowledge of very specific hardware whose documentation isn't always easy to find. It also requires very specific **tooling**, which is why **ZeroK** encompasses the creation of the following custom tools and software:

### :hammer: XtBootMgr
A very simplistic boot manager written purely in Pasme assembly. It can be installed on basically anything that can run x86 code and runs on CPUs even as old as the 8086. Its main purpose is booting **ZeroK** from whatever block device and whatever partition it gets installed on, be it a primary partition on a hard drive or a logical partition on a floppy disk. 

XtBootMgr's source code can be found in the root of the repo under ```/XtBootMgr```.

### :hammer: Pasme
This is an expanded **Assembly Language** with a few but much needed quality-of-life improvements. Pasme is used by the whole project. The transpiler source code sub-project can be found under ```/Tools/Pasme```.

A few Pasme features:
- **Automatic strings** allow you to write messages and other string contents directly in the code without worrying about their names or positioning.
- **Automatic variables** create storage locations in memory with type-based sizing.
- **Stack magement** helps you store local variables as well as read function arguments by just declaring them. The transpiler calculates the base pointer offset for you.
- The **Preprocessor** creates a level above the **NASM** preprocessor, and allows multi-level macros and includes for complex builds.

### :hammer: DevTK (Development Toolkit)
This is a CLI tool also written in **Java**. Most of its functionality relates to reading and burning virtual disks in order to test _ZeroK_. 
**DevTK**'s source code can be found in this repo under ```/Tools/DevToolkit```

DevTK's features:
- Automatic synchronization of local folders and virtual disk folders.
- Mounting and unmounting of virtual disks (**.vhd** files)
- Reading MBR partition tables from virtual disks and listing them.
- Writing _bootloaders_ to any numbered sector or specific partition.
- Writing code to _VBRs_ and their reserved sectors for installing OSes.

### :hammer: GCC
**ZeroK** requires a custom-built **GCC** targeting the *i386-elf* platform for its C code. Build instructions can be found under ```/Tools/GCC```
