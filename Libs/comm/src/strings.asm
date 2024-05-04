GLOBAL Strings.IntToStr
GLOBAL Strings.HexToStr

[SECTION .text]
[BITS 16]

; Turns a 16-bit integer into a string.
; The number is in the AX register.
; [AX] = Number
; [ES:DI] = Pointer to where a null-terminated string will be stored.
; Preserves everything.
Strings.IntToStr: {
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

; [AX] = Number
; [ES:DI] = Pointer to where a null-terminated string will be stored.
; Preserves everything.
Strings.HexToStr: {
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
