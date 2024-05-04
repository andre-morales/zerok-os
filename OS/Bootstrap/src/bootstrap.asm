/* Boostrapper (Stage 3)
 * 
 * Author:   André Morales 
 * Version:  0.67
 * Creation: 02/01/2021
 * Modified: 25/01/2022 */

[BITS 16]
[CPU 386]

; Physical Map
; -- [  0  -  500] IVT and BIOS Data Area
; -- [ 500 -  520] Our CPU Structures
; -- [	 .....	 ] 
; -- [ 700 -   # ] Stage 3 (us)
; -- [1200 -   # ] FAT16 Cluster Buffer
; -- [2000 -   # ] Stage 4 file will be loaded here
; -- [3000 -  ...] Stage 4 code starts here
; -- [ ... - 7FF0] Stack

#define CONSOLE_MIRROR_TO_SERIAL 1
#include "version.h"
#include <common/console.h>
#include <common/serial.h>

%define FAT16_CLUSTER_BUFFER_ADDR 0x1200
%define STAGE4_FILE_ADDR 0x2000
%define STAGE4_EXEC_ADDR 0x3000

var short ELF.fileLocation
var int ELF.entryPoint
var int ELF.progHeaderTable
var word ELF.progHeaderSize
var word ELF.progHeaderCount

; Variables to be passed to XtLoader
%define LOADER_STRUCT_SIZE 13
var void LoaderStruct
	; 2 Bytes
	var char[2] .signature
	
	; 2 Bytes
	var byte vidmode.columns
	var byte vidmode.id
	
	; 9 Bytes
	var byte pci.majorVer
	var byte pci.minorVer
	var short pci.props
	var byte pci.lastBus
	var int pci.entry
var void LoaderStruct.end
 
;;;; SECTION stack vstart=0x500 progbits
[SECTION .text]
dw 'Zk'

; GDT Descriptor
GDT_Desc: {
	dw GDT.End - GDT - 1; Length
	dd GDT			    ; Pointer
}

; Global descriptor table imported by LGDT instruction
GDT: {
	; Entry 0 must be null
	times 8 db 0

	; Entry 1 (CS)
	dw 0xFFFF    ; Limit (0:15)
	dw 0         ; Base (0:15)
	db 0         ; Base (16:23)
	db 10011010b ; Flags
	db 11001111b ; Flags
	db 0		 ; Base (24:31)
	
	; Entry 2 (DS)
	dw 0xFFFF 	 ; Limit (0:15)
	dw 0      	 ; Base (0:15)
	db 0      	 ; Base (16:23)
	db 10010010b ; Flags
	db 11001111b ; Flags
	db 0		 ; Base (24:31)
.End: }

times 512-($-$$) db 0x00 ; Fill everything until 0x700

jmp start

dw Drive ; Stores in the binary a pointer to the beginning of the Drive variables and the FATFS variables. 
dw FATFS ; These pointers are used by Stage 2 to transfer the state to Stage 3 when loading it.

start: {
	mov sp, 0x7FF0

	Print(."\n-- &bZk&3Loader &2Bootstrap &cv$#VERSION#\n")
	
	; Initialize serial
	call Serial.init	
	
	mov word [Drive.bufferPtr], STAGE4_FILE_ADDR
	mov word [FATFS.clusterBuffer], FAT16_CLUSTER_BUFFER_ADDR

	Log(."I Loading ZKLOADER.ELF\n")
	mov si, ."ZKOS/ZKLOADERELF"
	mov di, STAGE4_FILE_ADDR
	
	call ReadFile
	Log(."K Executable loaded.\n")
	
	mov word [ELF.fileLocation], STAGE4_FILE_ADDR
	call LoadELF
	
	call PrepareLoaderInfo
	
	Log(."I Press any key to execute XtLdr32.\n")
	call WaitKey
	jmp Enable32
}

ReadFile: {
	mov si, ."ZKOS       /ZKLOADERELF"
	push si
	call FATFS.LocateFile
	
	mov word [Drive.bufferPtr], STAGE4_FILE_ADDR
	push ax
	call FATFS.ReadClusterChain	
ret }

PrepareLoaderInfo: {
	Log(.". Acquiring info...\n")
	
	; Signature
	mov word [LoaderStruct.signature], 'Zk'

	call GetVideoMode
	call CheckPCI	
	Log(."K All info saved.\n")
ret }

GetVideoMode: {
	Log(."I Video Mode: ")
	
	mov ah, 0Fh | int 10h
	mov byte [vidmode.id], al
	mov byte [vidmode.columns], ah
	
	xor ah, ah
	PrintDecNum ax
	
	Print(." / ")
	
	mov al, [vidmode.columns]	
	PrintDecNum ax
	Print(."\n")
ret }

CheckPCI: {
	Log(.". Checking PCI support.\n")

	; PCI Support
	xor edi, edi
	mov ax, 0xB101
	int 1Ah
	
	jc .noSupport
	test ah, ah | jnz .noSupport
	cmp edx, 20494350h | jne .noSupport
	
	; Copy info and return
	mov [pci.entry], edi
	mov [pci.props], al
	mov [pci.majorVer], bh
	mov [pci.minorVer], bl
	mov [pci.lastBus], cl
	ret
	
	.noSupport:
	; Zero-out version numbers
	xor al, al
	mov [pci.majorVer], al
	mov [pci.minorVer], al
	
	.end:
ret }

Enable32: {
	Log(.". Entering 32-bit...\n")
	
	BREAK
	
	cli             ; Interrupts clear.
	lgdt [GDT_Desc] ; Load GDT
	
	; Set Protected Mode bit
	mov eax, cr0
	or al, 1
	mov cr0, eax
	
	; Far jump to set CS and truly enable 32 bit
	jmp 08h:Entry32
}

[BITS 32]
Entry32: {
	; Set ESI to variables to be passed
	mov esi, LoaderStruct
	mov ecx, LOADER_STRUCT_SIZE
	
	jmp [ELF.entryPoint]
}

[BITS 16]
; Loads the ELF file present at 0x2000.
LoadELF: {
	push bp
	mov bp, sp

	mov bx, [ELF.fileLocation]
	call LoadELFHeader
	call LoadProgramSegments
	
	mov sp, bp
	pop bp
ret }

LoadELFHeader: {
	; Make sure the file is an ELF file in the first place.
	cmp dword [bx + 0], 0x464C_457F
	jne NotAnElf
	
	mov eax, [bx + 24]
	mov [ELF.entryPoint], eax
	
	mov ax, [bx + 28]
	mov [ELF.progHeaderTable], ax
	
	mov ax, [bx + 42]
	mov [ELF.progHeaderSize], ax
	
	mov ax, [bx + 44]
	mov [ELF.progHeaderCount], ax
	
	Log(."I Image properties:\n")
	Print(."  Entry Point: 0x")
	PrintHexNum word [ELF.entryPoint]
	Print(."\n  ")
	PrintDecNum [ELF.progHeaderCount]
	Print(." entries of ")
	PrintDecNum [ELF.progHeaderSize]
	Print(." bytes at 0x")
	PrintHexNum word [ELF.progHeaderTable]
ret }

LoadProgramSegments: {	
	mov cx, [ELF.progHeaderCount]
	mov si, [ELF.progHeaderTable]
	lea si, [si + bx]
	.loadSegment:
		call LoadSegment
		add si, [ELF.progHeaderSize]
	loop .loadSegment
ret }

var void p_header
	var int p_offset
	var int p_vaddr
	var int p_filesz
	var int p_memsz

LoadSegment: {
	push si | push cx
	
	; Copy (and print) segment info
	mov di, p_header
	
	; p_offset
	add si, 4
	movsw
	movsw
	
	; p_vaddr
	movsw
	movsw
	
	; p_filesz (size of this segment in the file)
	add si, 4
	movsw
	movsw
	
	; p_memsz
	movsw
	movsw
	
	Print(."\n  p_offset ")
	PrintDecNum [p_offset]
	
	Print(."\n  p_vaddr ")
	PrintDecNum [p_vaddr]
	
	Print(."\n  p_filesz ")
	PrintDecNum [p_filesz]
	
	Print(."\n  p_memsz ")
	PrintDecNum [p_memsz]
	
	Print(."\n")
	
	; Load segment into ram
	mov bx, [ELF.fileLocation]
	mov si, [p_offset]
	lea si, [si + bx]
	
	mov di, STAGE4_EXEC_ADDR
	
	mov cx, [p_filesz]
	;rep movsb
	
	pop cx | pop si
ret }

NotAnElf: {
	Print(."\nNot an ELF file!");
	jmp Halt
}

Halt: {
	Print(."\nHalted.\n")
	cli | hlt
}	
	
FileNotFoundOnDir: {
	Print(."\nFile '")
	;mov si, [FATFS.filePathPtr]
	call print
	
	Print(."' not found on directory.")
	jmp Halt
}

; Code imports
#include <common/console.asm>
#include <common/drive.asm>
#include <common/fat1x.asm>
#include <common/serial.asm>

@rodata:

; Variables declared will appear here
[SECTION .bss]
@bss: