[BITS 16]
[CPU 386]
[ORG 0x500]

/* Author:   André Morales 
   Version:  0.6.2
   Creation: 02/01/2021
   Modified: 25/01/2022 */

; Physical Map
; -- [ 500] Stack
; -- [ 700] Stage 3 (us)
; -- [1200] FAT16 Cluster Buffer
; -- [2000] Stage 4 file will be loaded here
; -- [3000] Stage 4 code starts here

#include version_h.asm
#include <stdconio_h.asm>

%define FAT16_CLUSTER_BUFFER_ADDR 0x1200
%define STAGE4_FILE_ADDR 0x2000
%define STAGE4_EXEC_ADDR 0x3000

var short ELF.fileLocation
var int ELF.entryPoint
var int ELF.progHeaderTable
var word ELF.progHeaderSize
var word ELF.progHeaderCount

; Variables to be passed to XtLoader
var void XtLoaderStruct
	var byte vidmode.columns
	var byte vidmode.id
var void XtLoaderStruct.end

SECTION stack vstart=0x500 progbits
; Global descriptor table imported by LGDT instruction
GDT: {
	; Entry 0 must be null
	dq 0     

	; Entry 1 (CS)
	dw 0xFFFF ; Limit (0:15)
	dw 0      ; Base (0:15)
	db 0      ; Base (16:23)
	db 10011010b
	db 11001111b
	db 0
	
	; Entry 2 (DS)
	dw 0xFFFF ; Limit (0:15)
	dw 0      ; Base (0:15)
	db 0      ; Base (16:23)
	db 10010010b
	db 11001111b
	db 0
GDT_End:

GDT_Desc:
	dw GDT_End - GDT
	dd GDT

GDT_Desc_End:
}
times 512-($-$$) db 0x00 ; Fill the reserved stack section

SECTION .text vstart=0x700 follows=stack
jmp Start

dw Drive ; Stores in the binary a pointer to the beginning of the Drive variables and the FATFS variables. 
dw FATFS ; These pointers are used by Stage 2 to transfer the state to Stage 3 when loading it.

Start: {
	mov sp, 0x6F0

	Print(."\N-- XtLoader Head ${VERSION}")

	mov word [Drive.bufferPtr], STAGE4_FILE_ADDR
	mov word [FATFS.clusterBuffer], FAT16_CLUSTER_BUFFER_ADDR

	Print(."\NLoading XTLOADER.ELF\N")
	mov si, ."XTOS/XTLOADERELF"
	mov di, STAGE4_FILE_ADDR
	call ReadFile
		
	mov word [ELF.fileLocation], STAGE4_FILE_ADDR
	call LoadELF
	Print(."\NExecutable loaded.")

	;call SetupPagingStructures
	call GetInfo
	
	Print(."\NPress any key to execute XtLdr32.")
	call WaitKey
	jmp Enable32
}

ReadFile: {
	mov si, ."XTOS       /XTLOADERELF"
	call FATFS.FindFile
	
	mov word [Drive.bufferPtr], di
	push ax
	call FATFS.ReadClusterChain	
ret }

GetInfo: {
	; Get current video mode
	mov ah, 0Fh
	int 10h
	mov byte [vidmode.id], al
	mov byte [vidmode.columns], ah
	
	mov al, ah
	xor ah, ah
	
	Print(."\NVideo columns: ")
	PrintDecNum ax
	
	mov al, [vidmode.id]
	Print(."\NVideo mode: ")
	PrintDecNum ax
ret }

Enable32: {
	Print(."\NEntering 32-bit...")

	cli             ; Interrupts clear.
	lgdt [GDT_Desc] ; Load GDT
	
	; Set Protected Mode bit
	mov eax, cr0
	or al, 1
	mov cr0, eax
	
	jmp 08h:Entry32 ; Far jump to set CS
}

[BITS 32]
Entry32: {
	; Set all segments to data segment
	mov ax, 0x10
	mov ds, ax
	mov es, ax
	mov ss, ax
	mov fs, ax
	mov gs, ax
		
	; Set ESI to variables to be passed and jump
	mov esi, XtLoaderStruct
	jmp [ELF.entryPoint]
.End: }

[BITS 16]
; Loads the ELF file present at 0x3000.
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
	cmp word [bx + 0], 0x457F | jne NotAnElf
	cmp word [bx + 2], 0x464C | jne NotAnElf
	
	mov eax, [bx + 24]
	mov [ELF.entryPoint], eax
	
	mov ax, [bx + 28]
	mov [ELF.progHeaderTable], ax
	
	mov ax, [bx + 42]
	mov [ELF.progHeaderSize], ax
	
	mov ax, [bx + 44]
	mov [ELF.progHeaderCount], ax
	
	Print(."\NEntry Point: 0x")
	PrintHexNum word [ELF.entryPoint]
	Print(."\N")
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
	
	Print(."\Np_offset ")
	PrintDecNum [p_offset]
	
	Print(."\Np_vaddr ")
	PrintDecNum [p_vaddr]
	
	Print(."\Np_filesz ")
	PrintDecNum [p_filesz]
	
	Print(."\Np_memsz ")
	PrintDecNum [p_memsz]
	
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
	Print(."\NNot an ELF file!");
	jmp Halt
}
Halt: {
	Print(."\NHalted.\N")
	cli | hlt
}	
	
FileNotFoundOnDir: {
	Print(."\NFile '")
	;mov si, [FATFS.filePathPtr]
	call print
	
	Print(."' not found on directory.")
	jmp Halt
}

; Code imports
#include <stdconio.asm>
#include <drive.asm>
#include <fat1x.asm>

@rodata:

SECTION .bss
@data: