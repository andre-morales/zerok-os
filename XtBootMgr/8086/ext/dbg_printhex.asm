; Author:   André Morales 
; Version:  1.1
; Creation: 28/10/2020
; Modified: 28/10/2020

DBG_PrintHex:
	push bp
	mov bp, sp
	push ds
	push si
	push ax
	push bx
	push cx
	push dx
	
	xor bx, bx
	xor dh, dh
	mov cx, [bp + 8]
	lds si, [bp + 4]
	.l1:
		lodsb
		mov dl, al
		cmp dx, 15
		jg .print
		
		Putch('0')
		
		.print:
		mov ax, dx
		call printHexNumber
		Putch(' ')
		
		inc bx
		cmp bx, [bp + 10]
		jne .l2
		
		xor bx, bx
		Putch(NL)
		
		.l2:
	loop .l1
	pop dx
	pop cx
	pop bx
	pop ax
	pop si
	pop ds
	pop bp
ret