/**
 * Author:   André Morales 
 * Version:  2.02
 * Creation: 06/10/2020
 * Modified: 08/05/2024
 */
#include <strings.h>
#include <serial.h>

GLOBAL Console.Getch
GLOBAL Console.WaitKey
GLOBAL Console.Putch
GLOBAL Console.Putnch
GLOBAL Console.Print
GLOBAL Console.FLog
GLOBAL Console.PrintDecNum
GLOBAL Console.PrintHexNum

[SECTION .text]
[CPU 8086]
[BITS 16]

; Prints a single character
;
; Inputs: AL = Character
; Outputs: .
; Destroys: .
Console.Putch: {
	push ax | push bx | push dx
	
	cmp al, 0Ah ; Is character newline?
	jne .print
	
	mov al, 0Dh ; Print a carriage return
	call Console.Putch
	mov al, 0Ah ; Then print an actual new line
	
	.print:
	call Serial.Putch
	
	mov ah, 0Eh
	mov bx, 00_1Ah ; BH (0) BL (1Ah)
	int 10h
	
	pop dx | pop bx | pop ax
ret }

; Prints a single character many times
;
; Inputs: AL = Character, CL = Count
; Outputs: .
; Destroys: CX
Console.Putnch: {
	xor ch, ch
	
	.printch:
		call Console.Putch
	loop .printch
ret }

Console.FLog: {
	push ax
	lodsb
	push si
	
	cmp al, 'E' | je .err
	cmp al, 'W' | je .warn
	cmp al, 'I' | je .info
	cmp al, 'K' | je .ok
	jmp .msg
	
	.err:
	mov si, ."[&4ER"
	jmp .end
	
	.warn:
	mov si, ."[&eWR"
	jmp .end
	
	.info:
	mov si, ."[&9In"
	jmp .end
	
	.ok:
	mov si, ."[&2Ok"
	jmp .end
	
	.msg:
	mov si, ."[&3.."
	
	.end:
	call Console.Print
	
	mov si, ."&7]"
	call Console.Print
	
	pop si
	call Console.Print
	
	pop ax
ret }

/* Prints a string placed in SI */
Console.Print: {
	push ax | push bx | push cx | push dx
	mov bl, 07h
	
	.char:
		lodsb
		test al, al
		jz .end
			
		cmp al, '&'
		jne .place
		
		lodsb
		mov bl, al
		cmp bl, 'a'
		jl .n
		
		sub bl, 39
		
		.n:
		sub bl, '0'
		jmp .char

		.place:
		cmp al, 0Ah ; Is newline?
		je .sputch
		
		; Save char
		mov dl, al
		
		; Stamp color
		mov al, ' '
		mov ah, 09h
		xor bh, bh
		mov cx, 1
		int 10h
		
		; Print char
		mov al, dl
		.sputch:
		call Console.Putch		
	jmp .char
		
	.end:
	pop dx | pop cx | pop bx | pop ax
ret }

/* Waits for a key press and stores the key in the AL register. */
Console.Getch: {
	xor ah, ah
	int 16h
ret }

/* Waits for a key press. */
Console.WaitKey: {
	push ax
	call Console.Getch
	pop ax
ret }

Console.PrintHexNum: {
	CLSTACK
	farg word number
	lvar char[8] str
	ENTERFN
	
	push ds | push es
	push si | push di
	
	mov di, ss
	mov es, di
	mov ds, di
		
	mov ax, [$number]
	lea di, [$str]
	call Strings.HexToStr
	
	mov si, di
	call Console.Print
	
	pop di | pop si
	pop es | pop ds
		
	LEAVEFN
}

Console.PrintDecNum: {
	CLSTACK
	lvar char[6] str
	ENTERFN
	
	push ds
	push es
	push si
	push di
	
	mov di, ss
	mov es, di
	mov ds, di
	
	lea di, [$str]
	call Strings.IntToStr
	
	mov si, di
	call Console.Print
	
	pop di
	pop si
	pop es
	pop ds
	
	LEAVEFN
}

@rodata: