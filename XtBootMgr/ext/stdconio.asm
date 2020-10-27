putch: 
	push ax
	push bx
	
	cmp al, NL ; Is character newline?
	jne .print
	
	mov al, CR ; Print a carriage return
	call putch
	mov al, NL ; Then print an actual new line
	
	.print:
	mov ah, 0Eh
	xor bh, bh
	mov bl, 1Ah
	int 10h
	
	pop bx
	pop ax
ret

getch:
	xor ah, ah
	int 16h
ret

pause:
	push ax
	call getch
	pop ax
ret	

putnch: 	
	push cx
	
	.print:
		call putch
	loop .print
	
	pop cx
ret

printStr:
	push ax
	push bx	
	
	.char:
		lodsb
		test al, al
		jz .end
		
		mov ah, 0Eh ; Print character
		xor bh, bh  ; Page 0
		int 10h
		jmp .char
		
	.end:
	pop bx
	pop ax
ret
	
printColorStr:
	push ax
	push bx
	push cx
	push dx
	
	; Save color
	mov bl, al
	push bx
	
	; Get cursor position
	mov ah, 03h
	xor bh, bh
	int 10h

	pop bx ; Get color back
	
	.char:
		lodsb
		test al, al
		jz .end
		
		cmp al, NL
		je .putraw
		cmp al, CR
		je .putraw
		
		; Print only at cursor position with color
		mov ah, 09h
		mov cx, 1
		int 10h
		
		; Set cursor position
		inc dl ; Increase X
		mov ah, 02h
		int 10h
	jmp .char
	
	.putraw:
		; Teletype output
		mov ah, 0Eh
		int 10h
		
		; Get cursor position
		mov ah, 03h
		int 10h
	jmp .char
	
	.end:
	pop dx
	pop cx
	pop bx
	pop ax
ret	
	
getCursor:
	push ax
	push bx
	push cx
	
	mov ah, 03h
	xor bh, bh
	int 10h
	
	pop cx
	pop bx
	pop ax
ret

setCursor:
	push ax
	push bx
	push cx
	push dx 
	
	mov ah, 02h ; Set cursor position
	xor bh, bh
	int 10h
	
	pop dx
	pop cx
	pop bx
	pop ax
ret

printDecNumber:
	push bp
	mov bp, sp
	sub sp, 6
	push ds
	push es
	push si
	push di
	
	push ss
	pop es
	push ss
	pop ds
	
	mov di, [bp - 6]
	call decNumToStr
	
	mov si, di
	call printStr
	
	pop di
	pop si
	pop es
	pop ds
	mov sp, bp
	pop bp
ret
	
decNumToStr:
	push cx
	push dx
	push di
	
	mov cx, 10
	call .printNumber
	
	; Add null terminator
	xor al, al
	stosb
	
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
	
printHexNumber:
	push ax
	push cx
	push dx
	
	mov cx, 16
	call .printNumber
	
	pop dx
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
	
clearScreen:
	push ax
	push bx
	push cx
	push dx
	
	mov ax, 0600h        ; AH = Scroll up, AL = Clear
	mov bh, 0b0_110_1111 ; Foreground / Background
	xor cx, cx           ; Start on top left corner
	mov dx, 18_27h       ; End on bottom right corner
	int 10h
		
	pop dx
	pop cx
	pop bx
	pop ax
ret