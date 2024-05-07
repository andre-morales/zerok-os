/**
 * Boostrapper (Stage 3)
 * 
 * Author:   André Morales 
 * Creation: 02/01/2021
 * Modified: 05/05/2024
 *
 * This bootstrapper is stored as a raw binary file in the partition. It is responsible for loading
 * the ELF execute in the same folder and switching to 32 bit mode.
 */
#include "version.h"
#include <comm/console.h>
#include <comm/console_macros.h>
#include <comm/serial.h>
#include <comm/serial_macros.h>
#include <comm/drive.h>
#include <comm/fat1x.h>

%define LOG CONSOLE_FLOG

EXTERN __fat16_cluster_buffer_addr
EXTERN __loader32_file_addr
EXTERN __loader32_start_addr

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
 
[BITS 16]
[CPU 386]
[SECTION .gdt]
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

[SECTION .text]
jmp start

dw Drive.vars_begin ; Stores in the binary a pointer to the beginning of the Drive variables and the FATFS variables. 
dw FATFS.vars_begin ; These pointers are used by Stage 2 to transfer the state to Stage 3 when loading it.

start: {
	mov sp, 0x7FF0

	CONSOLE_PRINT(."\n-- &bZk&3Loader &2Bootstrap &cv$#VERSION#\n")
	
	; Initialize serial
	call Serial.Init	
	
	mov word [Drive.bufferPtr], __loader32_file_addr
	mov word [FATFS.clusterBuffer], __fat16_cluster_buffer_addr

	LOG(."I Loading ZKLOADER.ELF\n")
	mov si, ."ZKOS/ZKLOADERELF"
	mov di, __loader32_file_addr
	
	call ReadFile
	LOG(."K Executable loaded.\n")
	
	mov word [ELF.fileLocation], __loader32_file_addr
	call LoadELF
	
	call PrepareLoaderInfo
	
	LOG(."I Press any key to execute XtLdr32.\n")
	call Console.WaitKey
	jmp Enable32
}

ReadFile: {
	mov si, ."ZKOS       /ZKLOADERELF"
	push si
	call FATFS.LocateFile
	
	mov word [Drive.bufferPtr], __loader32_file_addr
	push ax
	call FATFS.ReadClusterChain	
ret }

PrepareLoaderInfo: {
	LOG(.". Acquiring info...\n")
	
	; Signature
	mov word [LoaderStruct.signature], 'Zk'

	call GetVideoMode
	call CheckPCI	
	LOG(."K All info saved.\n")
ret }

GetVideoMode: {
	LOG(."I Video Mode: ")
	
	mov ah, 0Fh | int 10h
	mov byte [vidmode.id], al
	mov byte [vidmode.columns], ah
	
	xor ah, ah
	CONSOLE_PRINT_DEC_NUM ax
	
	CONSOLE_PRINT(." / ")
	
	mov al, [vidmode.columns]	
	CONSOLE_PRINT_DEC_NUM ax
	CONSOLE_PRINT(."\n")
ret }

CheckPCI: {
	LOG(.". Checking PCI support.\n")

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
	LOG(.". Entering 32-bit...\n")
	
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
	
	LOG(."I Image properties:\n")
	CONSOLE_PRINT(."  Entry Point: 0x")
	CONSOLE_PRINT_HEX_NUM word [ELF.entryPoint]
	CONSOLE_PRINT(."\n  ")
	CONSOLE_PRINT_DEC_NUM [ELF.progHeaderCount]
	CONSOLE_PRINT(." entries of ")
	CONSOLE_PRINT_DEC_NUM [ELF.progHeaderSize]
	CONSOLE_PRINT(." bytes at 0x")
	CONSOLE_PRINT_HEX_NUM word [ELF.progHeaderTable]
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
	
	CONSOLE_PRINT(."\n  p_offset ")
	CONSOLE_PRINT_DEC_NUM [p_offset]
	
	CONSOLE_PRINT(."\n  p_vaddr ")
	CONSOLE_PRINT_DEC_NUM [p_vaddr]
	
	CONSOLE_PRINT(."\n  p_filesz ")
	CONSOLE_PRINT_DEC_NUM [p_filesz]
	
	CONSOLE_PRINT(."\n  p_memsz ")
	CONSOLE_PRINT_DEC_NUM [p_memsz]
	
	CONSOLE_PRINT(."\n")
	
	; Load segment into ram
	mov bx, [ELF.fileLocation]
	mov si, [p_offset]
	lea si, [si + bx]
	
	mov di, __loader32_start_addr
	
	mov cx, [p_filesz]
	;rep movsb
	
	pop cx | pop si
ret }

NotAnElf: {
	CONSOLE_PRINT(."\nNot an ELF file!");
	jmp Halt
}

Halt: {
	CONSOLE_PRINT(."\nHalted.\n")
	cli | hlt
}	
	
FileNotFoundOnDir: {
	CONSOLE_PRINT(."\nFile '")
	;mov si, [FATFS.filePathPtr]
	call Console.Print
	
	CONSOLE_PRINT(."' not found on directory.")
	jmp Halt
}

@rodata:

; Variables declared will appear here
[SECTION .bss]
@bss: