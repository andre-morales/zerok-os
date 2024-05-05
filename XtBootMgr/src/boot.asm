; Author:   André Morales 
; Version:  1.2
; Creation: 06/10/2020
; Modified: 22/05/2023

%define BEGIN_ADDR 0x7C00
%define STAGE2_SEGMENT 0xA0
%define STAGE2_ADDRESS 0xA00
%define STAGE2_SIZE_IN_SECTORS 8

[CPU 8086]
[BITS 16]

#include "version.h"
#define CONSOLE_MACROS_MINIMAL 1
#include <comm/console_macros.h>

[SECTION .text]
entry:	
	; Clear segment registers and set up the stack right behind us.
	cli ; Prevent interrupts while the stack is being setup

	xor cx, cx
	mov ds, cx
	mov es, cx
	mov ss, cx
	mov sp, BEGIN_ADDR 
	
	sti ; Interrupts are safe again
	
	; This call/pop allows us to get the address of the current instruction.
	; By subtracting this from the offset of where our code began, we can
	; figure where our code was placed by the BIOS. This is normally 0x7C00.
	call .getIP
	.getIP:
	pop bx							   ; [BX = IP]
	sub bx, (.getIP - entry) 
	
	push cs          ; Save CS to print it later
	jmp 0000h:start  ; Far jump to our safe Start while setting CS to 0 too.

/** In our Start procedure, it is safe to refer to our own strings, functions, variables, etc. */
start:
	; Print welcome message followed by boot info
	Print(."@XtBootMgr v$#VERSION# \NBooted at [")	
	
	; Print boot CS:IP
	pop ax
	call printHexNum_short
	Putch(':')
	PrintHexNum(bx) 
	
	; Print boot drive ID
	Print(."] | Drive 0x")
	xor dh, dh
	PrintHexNum(dx)

	; DL is still preserved
	call TryBootDrive
	
	; Maybe DL was set incorrectly so let's 
	; try the standard drive 0x80 to boot ourselves
	mov dl, 0x80
	call TryBootDrive
	
	Print(."\nStage 2 not found. Halted.")
	jmp halt

; [DL = Drive]
TryBootDrive: {
	Print(."\n\nLooking in drive 0x")
	PrintHexNum(dx)
	
	; Reset drive system
	xor ah, ah
	int 13h  
	
	; Read Drive MBR and compare it to ourselves
	mov al, 1
	mov cl, 1
	call ReadSectors
	
	; Compare what we loaded at 0xA00 to ourselves at 0x7C00
	mov si, 0x7C00
	mov di, STAGE2_ADDRESS
	mov cx, 256
	repe cmpsw
	jne mbrMismatch
	
	; MBR is equal, lets load Stage 2 then
	mov al, STAGE2_SIZE_IN_SECTORS
	mov cl, 02
	call ReadSectors

	; Test Stage 2 signature
	mov ax, [STAGE2_ADDRESS]
	cmp ax, 'Xt' ; Test Stage 2 signature to make sure everything went right.
	jne signatureBad
		
	; Signature is good!
	; Jump to stage 2 after the 2-byte signature [00A0h:0002h]
	Print(."\nReady.")
	jmp STAGE2_SEGMENT:0002h
	
	mbrMismatch:
	Print(."\nMBR mismatch.")
	ret
	
	signatureBad:
	Print(."\nBad signature: ")
	PrintHexNum(ax)
ret	}

; [AL = Sector amount ; CL = Sector index + 1]
ReadSectors: {
	mov bx, STAGE2_ADDRESS			; Load drive sectors at [ES:BX] = [0:0A00] 
	xor ch, ch  					; CH = Cylinder 0
	mov ah, 02 | int 13h     		; Read drive
ret }

halt: {
	hlt
jmp halt }

putch: {
	push ax | push bx | push dx
	
	cmp al, 0Ah ; Is character newline?
	jne .print
	
	mov al, 0Dh ; Print a carriage return
	call putch
	mov al, 0Ah ; Then print an actual new line
	
	.print:
	mov ah, 0Eh
	mov bx, 00_1Ah ; BH (0) BL (1Ah)
	int 10h
	
	pop dx | pop bx | pop ax
ret }

/* Prints a string placed in SI */
print: {
	push ax
	
	.char:
		lodsb
		test al, al
		jz .end
		
		call putch
	jmp .char
		
	.end:
	pop ax
ret }

printHexNum_short: {
	push ax
	push cx

	mov cx, 16
	call .printNumber
	
	pop cx
	pop ax
ret
	
	.printNumber:
		push ax
		push dx
		
		xor dx, dx
		div cx            ; AX = Quotient, DX = Remainder
		test ax, ax       ; Is quotient zero?
		
		jz .printDigit    ; Yes, just print the digit in the remainder.
		call .printNumber ; No, recurse and divide the quotient by 16 again. Then print the digit in the remainder.
		
		.printDigit:
		mov al, dl
		add al, '0'
		cmp al, '9'
		jle .putc
		
		add al, 7
		
		.putc:
		call putch
	
		pop dx
		pop ax
    ret
}

@rodata:

%xdefine padding (440 - ($ - $$))
times padding db 0x90 ; Fill the rest of the boostsector code with no-ops

[SECTION .bss]
@bss:
