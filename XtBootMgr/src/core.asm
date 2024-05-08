/**
 * Author:   André Morales 
 * Version:  1.1.4
 * Creation: 07/10/2020
 * Modified: 08/05/2024
 */

#include "version.h"
#include "video.h"
#include "partitions.h"
#include <comm/mem.h>
#include <comm/strings.h>
#include <comm/console.h>
#include <comm/console_macros.h>
#include <comm/drive.h>

%define STACK_ADDRESS 0xA00
%define PARTITION_ARRAY [Partitions.entries]

%macro PrintColor 2
	mov si, %1
	mov al, %2
	call Video.PrintColor
%endmacro

%macro ClearScreen 1
	mov ax, %1
	call Video.ClearScreen
%endmacro

var short cursor
var byte[6] partitionSizeStrBuff

[SECTION .text]
[BITS 16]
[CPU 8086]

db 'Xt' ; Two byte signature at binary beginning.

/* Entry point. */
Start: {
	; Readjust stack behind us
	mov sp, 0xA00 
	
	; Set CS = DS = ES
	mov ax, cs
	mov ds, ax
	mov es, ax
	
	; Reenable interrupts
	sti
	
	; Save drive number and bytes per sector discovered in the previous stage
	mov [Drive.id], dl
	mov [Drive.CHS.bytesPerSector], di
	
	; Print header
	CONSOLE_PRINT(."\N\n--- Xt Generic Boot Manager ---")
	CONSOLE_PRINT(."\NVersion: $#VERSION#")
	
	; Set up division error int handler.
	mov word [es:0000], DivisionErrorHandler
	mov word [es:0002], ds
	
	; Print video mode and drive geometry
	call PrintCurrentVideoMode
	call GetDriveGeometry
	
	; Wait for key press to read the partition map
	CONSOLE_PRINT(."\NPress any key to read the partition map.") 
	call Console.WaitKey
	
	; Allocate 256-byte block to store partition entries, AX points to the memory block
	call Mem.Init
	mov ax, 256
	call Mem.Alloc
	
	; Direct drive reading sectors to 0x2000
	mov word [Drive.bufferPtr], 0x2000
	
	; Read partition map to allocated memory block pointer by ES:DI
	push ds 
	pop es
	mov di, ax
	call Partitions.ReadPartitionMap
	CONSOLE_PRINT(."\NPartition map read.")

	; Print how many entries were read
	CONSOLE_PRINT(."\nFound ")
	mov ax, [Partitions.entriesLength]
	call Console.PrintDecNum
	CONSOLE_PRINT(." entries.")
	
	; Wait for user input before entering the menu
	CONSOLE_PRINT(."\NPress any key to enter boot select...\N")
	call Console.WaitKey
	jmp Menu
}

Menu: {
	mov word [cursor], 0
	
	MainMenu:
		ClearScreen(0_110_1111b)
		
		mov bx, 00_00h
		mov ax, 25_17h
		call Video.DrawBox
	
		mov dx, 00_03h
		call Video.SetCursor
		
		CONSOLE_PRINT(."-XtBootMgr v$#VERSION# [Drive 0x")
		
		xor ah, ah
		mov al, [Drive.id]
		CONSOLE_PRINT_HEX_NUM(ax)
		CONSOLE_PRINT(."]-")
	
	MenuSelect:	
		call DrawMenu	
			
		call Console.Getch
		cmp ah, 48h | je .upKey
		cmp ah, 50h | je .downKey
		cmp ah, 1Ch | je .enterKey
		jmp MenuSelect
		
		.upKey:
			mov ax, [cursor]
			test ax, ax | jnz .L3
			
			mov al, [Partitions.entriesLength]
			
			.L3:
			dec ax
			div byte [Partitions.entriesLength]
			mov [cursor], ah
		jmp MenuSelect
		
		.downKey:
			mov ax, [cursor]
			inc ax
			div byte [Partitions.entriesLength]
			mov [cursor], ah
		jmp MenuSelect
		
		.enterKey:
			mov al, 10 | mul byte [cursor]
			mov di, ax
			add di, PARTITION_ARRAY
			
			cmp byte [es:di + 0], 05h | jne .L4
			CONSOLE_PRINT(."\N\N You can't boot an extended partition.")
			jmp BackToMainMenu
			
			.L4: {	
				push di
				
				; Fill 0x7C00 with no-ops.
				mov di, 0x7C00
				mov al, 90h
				mov cx, 512
				rep stosb
				
				; Copy the boot failure handler after the boot sector. If control gets there, this handles it.
				mov si, BootFailureHandler
				mov cx, 16
				rep movsw
			
				pop di
			}
						
			CONSOLE_PRINT(."\N\NReading drive...")			
			; Save ES segment reg
			push es
			
			; Push on the stack the partition starting LBA
			push word [es:di + 4] | push word [es:di + 2] 
			
			; Set ES to 0 in order to Read the MBR to 0000:7C00
			xor ax, ax
			mov es, ax
			mov word [Drive.bufferPtr], 0x7C00
			call Drive.ReadSector						
			
			; Get boot signature
			mov ax, [es:0x7DFE]
			
			; Restore ES segment
			pop es
			
			cmp ax, 0xAA55 | jne .notBootable
			CONSOLE_PRINT(."\NPress any key to boot...\N")	
			call Console.WaitKey
			jmp .chain		
			
			.notBootable:
			CONSOLE_PRINT(."\NBoot signature not found.\NBoot anyway [Y/N]?\N")	
			call Console.Getch	
			cmp ah, 15h | jne BackToMainMenu.clear
			
			.chain:
			ClearScreen(0_000_0111b)
			
			mov dl, [Drive.id]
			jmp 0x0000:0x7C00	
		
		BackToMainMenu:
			call Console.WaitKey
			.clear:
		jmp MainMenu
}

/* Prints current video mode and number of columns. */
PrintCurrentVideoMode: {
	mov ah, 0Fh | int 10h
	push ax
	
	CONSOLE_PRINT(."\NCurrent video mode: 0x")
	
	xor ah, ah
	CONSOLE_PRINT_HEX_NUM(ax)
	
	CONSOLE_PRINT(."\NColumns: ")
	pop ax
	mov al, ah
	xor ah, ah
	call Console.PrintDecNum	
ret }

GetDriveGeometry: {	
	call Drive.Init
	call Drive.CHS.GetProperties
	call Drive.LBA.GetProperties

	CONSOLE_PRINT(."\N\N[Geometries of drive: ")
	xor ah, ah
	mov al, [Drive.id]
	CONSOLE_PRINT_HEX_NUM(ax)
	CONSOLE_PRINT(."h] ")
	
	CONSOLE_PRINT(."\N-- CHS")
	CONSOLE_PRINT(."\N Bytes per Sector: ")
	CONSOLE_PRINT_DEC_NUM [Drive.CHS.bytesPerSector]
	
	CONSOLE_PRINT(."\N Sectors per Track: ")
	xor ah, ah
	mov al, [Drive.CHS.sectorsPerTrack]
	call Console.PrintDecNum

	CONSOLE_PRINT(."\N Heads Per Cylinder: ")
	CONSOLE_PRINT_DEC_NUM [Drive.CHS.headsPerCylinder]
	
	CONSOLE_PRINT(."\N Cylinders: ")
	CONSOLE_PRINT_DEC_NUM [Drive.CHS.cylinders]
	 
	CONSOLE_PRINT(."\N-- LBA")
	
	mov al, [Drive.LBA.available]
	test al, al | jz .printLBAProps
	cmp al, 1   | je .noDriveLBA
	CONSOLE_PRINT(."\N The BIOS doesn't support LBA.")
	jmp .End
	
	.noDriveLBA:
	CONSOLE_PRINT(."\N The drive doesn't support LBA.")
	jmp .End
	
	.printLBAProps:
	CONSOLE_PRINT(."\N Bytes per Sector: ")
	CONSOLE_PRINT_DEC_NUM [Drive.LBA.bytesPerSector]
	
	.End:
ret }
	
DrawMenu: {
	CLSTACK
	lvar short sectorsPerMB
	ENTERFN
	
	mov word [$sectorsPerMB], 2048
	push ds
	push es
	
	mov dx, 02_02h | call Video.SetCursor
		
	mov di, PARTITION_ARRAY
	xor cl, cl
	cmp cl, [Partitions.entriesLength] | je .End ; If partition map is empty.
	
	.drawPartition:
		call Video.SetCursor
		mov bh, ' '  ; (Prefix) = ' '
		mov bl, 0x6F ; (Color) = White on orange.
		cmp cl, [cursor] | jne .printIndent ; Is this the selected item? If not, skip.
		
		; Item is selected
		add bh, '>' - ' ' ; Set prefix char to '>'
		cmp byte [es:di], 05h | jne .itemBootable ; Is this an extend partition type? If it is, set the bg to blue.
		mov bl, 0x4F                              ; Unbootable item selected color, white on red.
		jmp .printIndent
		
		.itemBootable:
		mov bl, 0x1F ; Bootable item selected color, white on blue.		
		
		; Print and extra indent if listing primary partitions.
		.printIndent:
		cmp byte [es:di + 1], 0 ; Listing primary partitions?
		je .printTypeName
		CONSOLE_PUTCH(' ')
		
		.printTypeName:	
		CONSOLE_PUTCH(bh)		
		mov al, [es:di] ; Partition type
		call Partitions.GetPartTypeName
		mov al, bl | call Video.PrintColor
				
		PrintColor ." (", bl
		{
			push dx | push di
			
			mov ax, [es:di + 6]
			mov dx, [es:di + 8]
			div word [$sectorsPerMB]
			
			mov si, partitionSizeStrBuff
			mov es, [bp - 4] ; Set ES to DS
			mov di, si
			call Strings.IntToStr
			
			mov al, bl
			call Video.PrintColor
			
			pop di | pop dx
		}
		
		PrintColor ." MiB)", bl
		
		add di, 10
		inc dh
		inc cx
	cmp cl, [Partitions.entriesLength] | jne .drawPartition

	.End:
	pop es
	mov sp, bp
	pop bp
ret }

; A CHS calculation or some division may fail and throw execution here. 
DivisionErrorHandler: {
	push bp
	mov bp, sp
	push ax | push bx | push cx | push dx
	push si | push di
	push ds
	
	push cs | pop ds
	CONSOLE_PRINT(."\NDivision overflow or division by zero.\r")
	CONSOLE_PRINT(."\NError occurred at: ")
	CONSOLE_PRINT_HEX_NUM word [bp + 4]
	CONSOLE_PRINT(."h:")
	CONSOLE_PRINT_HEX_NUM word [bp + 2]
	CONSOLE_PRINT(."h\NAX: 0x") | CONSOLE_PRINT_HEX_NUM word [bp - 2]
	CONSOLE_PRINT(." BX: 0x") | CONSOLE_PRINT_HEX_NUM word [bp - 4]
	CONSOLE_PRINT(." CX: 0x") | CONSOLE_PRINT_HEX_NUM word [bp - 6]
	CONSOLE_PRINT(." DX: 0x") | CONSOLE_PRINT_HEX_NUM word [bp - 8]
	CONSOLE_PRINT(."\NSP: 0x")
	lea ax, [bp + 8]
	CONSOLE_PRINT_HEX_NUM(ax)
	CONSOLE_PRINT(." BP: 0x") | CONSOLE_PRINT_HEX_NUM word [bp - 0]
	CONSOLE_PRINT(." SI: 0x") | CONSOLE_PRINT_HEX_NUM word [bp - 10]
	CONSOLE_PRINT(." DI: 0x") | CONSOLE_PRINT_HEX_NUM word [bp - 12]
	CONSOLE_PRINT(."\NSystem halted.")
	cli | hlt
}


; When booting a partition fails. Handlers throw execution here.
BootFailureHandler: {
	; Far jump to set the CS selector back to A0
	jmp 0x00A0:.land
	
	.land:
	; Set DS = CS
	push cs
	pop ds
	
	CONSOLE_PRINT(."\NXtBootMgr got control back. The bootsector either contains no executable code, or invalid code.\NGoing back to the main menu.")
	call Console.WaitKey
	jmp Menu
}

[SECTION .rodata]
@rodata:

[SECTION .bss]
@bss:
