; Author:   André Morales 
; Version:  1.1
; Creation: 27/10/2020
; Modified: 28/10/2020

DBG_ClearStack:
	pop bx     ; Get return address
	mov ax, bp ; Save BP in other register
	mov bp, sp
	
	mov cx, 512
	mov dx, 0xFFFF
	.store:
		push dx
	loop .store
	
	mov sp, bp
	mov bp, ax
jmp bx