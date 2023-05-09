; Author:   André Morales 
; Version:  2.01
; Creation: 06/10/2020
; Modified: 31/01/2022

/* Prints a string placed in SI */
print: {
	push ax
	push si
	
	.char:
		lodsb
		test al, al
		jz .end
		
		call putch
	jmp .char
		
	.end:
	pop si
	pop ax
ret }


/* Prints a single character that was put into AL */
putch: {
	push ax | push bx
	
	cmp al, 0Ah ; Is character newline?
	jne .print
	
	mov al, 0Dh ; Print a carriage return
	call putch
	mov al, 0Ah ; Then print an actual new line
	
	.print:
	mov ah, 0Eh
	mov bx, 00_1Ah ; BH (0) BL (1Ah)
	int 10h
	
	pop bx | pop ax
ret }

#ifdef STDCONIO_MINIMAL

printHexNum: {
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

#else

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
	call hexNumToStr
	
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
	call itoa
	
	mov si, di
	call print
	
	pop di
	pop si
	pop es
	pop ds
	
	LEAVEFN
}

; Turns a 16-bit integer into a string.
; The number is in the AX register.
itoa: {
	push cx
	push dx
	push di
	
	mov cx, 10
	call .printNumber
	
	mov byte [es:di], 0
	
	pop di
	pop dx
	pop cx
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
		stosb
	
		pop dx
		pop ax
    ret	
}

hexNumToStr: {
	push ax
	push cx
	push di

	mov cx, 16
	call .printNumber
	
	mov byte [es:di], 0
	
	pop di
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
		stosb
	
		pop dx
		pop ax
    ret
}

#endif
