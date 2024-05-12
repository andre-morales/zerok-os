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

%macro PrintColor 2
	mov si, %1
	mov al, %2
	call Video.PrintColor
%endmacro

EXTERN __data_segment
GLOBAL BootFailureHandler

var short cursor

[SECTION .text]
[BITS 16]
[CPU 8086]

db 'Xt' ; Two byte signature at binary beginning.

/* Entry point. */
Start: {
	; Readjust stack behind us
	mov sp, 0xA00 
	
	; Set DS = CS
	mov ax, __data_segment
	mov ds, ax
	
	; Set ES = 0
	xor ax, ax
	mov es, ax
	
	; Reenable interrupts
	sti
	
	; Save drive number and bytes per sector discovered in the previous stage
	mov [Drive.id], dl
	mov [Drive.CHS.bytesPerSector], di
	
	; Print header
	CONSOLE_PRINT(."\N\n--- Xt Generic Boot Manager ---")
	CONSOLE_PRINT(."\N Version: $#VERSION#")
	
	; Set up division error int handler.
	mov word [es:0000], DivisionErrorHandler
	mov word [es:0002], ds
	
	; Print video mode and drive geometry
	call PrintCurrentVideoMode
	call GetDriveGeometry
	
	; Erase our own boot signature to not missidentify partitions
	mov word [es:0x7C00 + 510], 0x0000
	
	; Wait for key press to read the partition map
	CONSOLE_PRINT(."\NPress any key to read the partition map.") 
	call Console.WaitKey
	
	; Allocate 256-byte block to store partition entries, AX points to the memory block
	call Mem.Init
	mov ax, 256
	call Mem.Alloc
	
	; Direct drive reading sectors to 0x2000
	mov word [Drive.bufferPtr], 0x2000
	
	; Read partition map to allocated memory block pointer
	{	
		; Save ES
		push es
	
		; Set ES:DI = DS:AX
		push ds | pop es	
		mov di, ax
		call Partitions.ReadPartitionMap
		CONSOLE_PRINT(."\NPartition map read.")
		
		; Restore ES
		pop es
	}

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
	
	; MainMenu routine clears the screen and redraws the decoration before entering the select
	; loop
	MainMenu:
		mov ax, 0_110_1111b
		call Video.ClearScreen
		call DrawMenuBox
	
	; Menu selection loop
	MenuSelect:	
		call DrawMenu	
		
		; Wait for user input, looping around if an invalid key was pressed
		.waitKey:
		call Console.Getch
		cmp ah, 48h | je .upKey
		cmp ah, 50h | je .downKey
		cmp ah, 1Ch | je .enterKey
		jmp .waitKey
		
		.upKey:
			; Check if cursor position is 0
			mov ax, [cursor]
			test ax, ax
			jnz .decr
			
			; Wrap cursor around
			mov ax, [Partitions.entriesLength]
			
			.decr:
			dec ax
			mov [cursor], ax
		jmp MenuSelect
		
		.downKey:
			mov ax, [cursor]
			inc ax
			div byte [Partitions.entriesLength]
			mov [cursor], ah
		jmp MenuSelect
		
		; If enter pressed, try to boot the partition
		.enterKey:
			mov ax, [cursor]
			call BootPartition
		jmp MainMenu
}

; Try to boot the partition pointer by AX
;
; Inputs: AX = Partition index
; Outputs: .
; Destroys: AX
BootPartition: {
	; Prepare boot area and check signatures. Partition index in AX.
	call Partitions.PrepareBoot	

	; Check error status codes
	cmp al, 0
	je .doBoot
	
	cmp al, 1
	je .extendedPart
	
	cmp al, 2
	je .noSignature
	
	CONSOLE_PRINT(."\nUnknown error. Aborting.\n")	
	ret	
	
	.doBoot:
	CONSOLE_PRINT(."\NPress any key to boot...\N")	
	call Console.WaitKey
	
	; Perform the chain boot. Clear the screen, restore DL and jump
	.doChainBoot: {
		mov ax, 0_000_0111b
		call Video.ClearScreen

		mov dl, [Drive.id]
		jmp 0x0000:0x7C00
	}
	
	; If the signature was invalid, the partition is probably not bootable.
	; Only boot if the user presses Y	
	.noSignature: {
		CONSOLE_PRINT(."\NBoot signature not found.\NBoot anyway [Y/N]?\N")	
		call Console.Getch	
		cmp ah, 15h
		je .doChainBoot
		ret
	}
	
	.extendedPart:
	CONSOLE_PRINT(."\nYou can't boot an extended partition.")
	call Console.WaitKey
	
	.end:
ret }
	
; Draw menu partition labels
;
; Destroys: .
DrawMenu: {
	CLSTACK
	
	; Enter function
	push bp
	mov bp, sp
	sub sp, $stack_vars_size
	
	mov dx, 02_02h
	call Video.SetCursor
	
	; If partition map is empty.
	xor cx, cx
	cmp cx, [Partitions.entriesLength]
	je .end
	
	.drawPartition:
		call Video.SetCursor
		call DrawPartitionEntry
		
		inc dh
		inc cx
	cmp cx, [Partitions.entriesLength]
	jne .drawPartition

	.end:
	; Leave function
	mov sp, bp
	pop bp
ret }

; Inputs: CX = Partition index
DrawPartitionEntry: {
	CLSTACK
	lvar short sectorsPerMB
	lvar short partition
	lvar short prefix
	lvar char[8] sizeStrBuffer
	
	; Enter function
	push bp
	mov bp, sp
	sub sp, $stack_vars_size
	
	; Save registers
	push cx
	push dx

	mov word [$sectorsPerMB], 2
	mov word [$partition], cx
	mov byte [$prefix], ' '
	
	; Set DI = Partitions.entries + CX * 10
	{
		push dx
	
		mov ax, 10
		mul cx
		add ax, [Partitions.entries]
		mov di, ax
	
		pop dx
	}
	
	; Set color to White on orange.
	mov byte [Video.textColor], 0x6F 
	
	; If this is not the selected entry, jump to the printing already.
	cmp cl, [cursor]
	jne .printIndent 
	
	; Determine color and prefix of a selected entry
	{
		mov byte [$prefix], '>'
		
		; Is this an extend partition type? If it is, set the bg red.
		cmp byte [di], 05h
		je .unbootableItem 
		cmp byte [di], 0Fh
		je .unbootableItem
		
		; Bootable item selected. Set color to white on blue.
		mov word [Video.textColor], 0x1F
		jmp .printIndent
		
		; Unbootable item selected. Set color to white on red.    
		.unbootableItem:
		mov word [Video.textColor], 0x4F
	}
	
	; Print an extra indent if listing logical partitions.
	.printIndent: {
		; Check if primary partition type
		cmp byte [di + 1], 0
		je .printTypeName
		
		; Print two-space indent
		mov al, ' '
		call Console.Putch
		call Console.Putch
	}
	
	.printTypeName:	{
		; Print prefix. A ' ' or a '>' if the partition is selected or not
		mov al, [$prefix]
		call Console.Putch		
		
		; Print partition type name
		mov ax, [$partition]
		call Partitions.GetDescription
		call Video.PrintColor
	}
	
	; Print partition size in between ()
	{
		mov si, ." ("
		call Video.PrintColor
		
		; Divide sector count by sectorsPerMB value
		mov ax, [di + 6]
		mov dx, [di + 8]
		div word [$sectorsPerMB]
		
		; Convert number to string in ES:DI = DS:DI
		push ds 
		push es
		
		; Set DS, ES = SS
		mov dx, ss
		mov ds, dx
		mov es, dx
		
		lea di, [$sizeStrBuffer]
		call Strings.IntToStr

		mov si, di
		call Video.PrintColor
		
		pop es
		pop ds
		
		mov si, ." KiB)"
		call Video.PrintColor
	}
	
	; Restore registers
	pop dx
	pop cx
	
	; Leave function
	mov sp, bp
	pop bp
ret }

; Draws fancy menu frame. Does not clear the screen beforehand
;
; Destroys: AX, BX, DX
DrawMenuBox: {
	; Draw box with origin point to (0, 0), width to columns - 3 and height to 23
	mov bx, 00_00h
	mov ah, [Video.columns]
	sub ah, 3
	mov al, 23
	call Video.DrawBox

	; Point cursor to X: 2, Y: 0
	mov dx, 00_02h
	call Video.SetCursor
	
	; Print header
	CONSOLE_PRINT(." XtBootMgr v$#VERSION# [Drive 0x")
	
	; Print drive number on header
	xor ah, ah
	mov al, [Drive.id]
	CONSOLE_PRINT_HEX_NUM ax
	CONSOLE_PRINT(."] ") 
ret }

/* Prints current video mode and number of columns. */
PrintCurrentVideoMode: {
	call Video.Init

	CONSOLE_PRINT(."\nCurrent video mode: 0x")

	CONSOLE_PRINT_HEX_NUM word [Video.currentMode]
	
	CONSOLE_PRINT(."\nColumns: ")
	
	mov ax, [Video.columns]
	call Console.PrintDecNum	
ret }

; Print current properties of the drive 
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
