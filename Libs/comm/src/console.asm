; Author:   André Morales 
; Version:  2.01
; Creation: 06/10/2020
; Modified: 31/01/2022

#include <strings.h>
#include <serial.h>

GLOBAL print
GLOBAL classLog
GLOBAL Getch
GLOBAL WaitKey
GLOBAL printDecNum
GLOBAL printHexNum
GLOBAL putch
GLOBAL putnch

[SECTION .text]
[BITS 16]

/* Prints a single character that was put into AL */
putch: {
	push ax | push bx | push dx
	
	cmp al, 0Ah ; Is character newline?
	jne .print
	
	mov al, 0Dh ; Print a carriage return
	call putch
	mov al, 0Ah ; Then print an actual new line
	
	.print:
	call Serial.Putch
	
	mov ah, 0Eh
	mov bx, 00_1Ah ; BH (0) BL (1Ah)
	int 10h
	
	pop dx | pop bx | pop ax
ret }

classLog: {
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
	call print
	
	mov si, ."&7]"
	call print
	
	pop si
	call print
	
	pop ax
ret }

/* Prints a string placed in SI */
print: {
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
		call putch		
	jmp .char
		
	.end:
	pop dx | pop cx | pop bx | pop ax
ret }

putnch: {
	xor ch, ch
	
	.printch:
		call putch
	loop .printch
ret }

/* Waits for a key press and stores the key in the AL register. */
Getch: {
	xor ah, ah
	int 16h
ret }

/* Waits for a key press. */
WaitKey: {
	push ax
	call Getch
	pop ax
ret }

printHexNum: {
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
	call print
	
	pop di | pop si
	pop es | pop ds
		
	LEAVEFN
}

printDecNum: {
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
	call print
	
	pop di
	pop si
	pop es
	pop ds
	
	LEAVEFN
}

@rodata: