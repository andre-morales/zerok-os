[BITS 16]
[CPU 8086]
%include "ext/stdconio_h.csm"

Start:
	push cs 
 pop ds
	
	mov [drive], dl
	Print(Constants.string1)
	
	
	
	cli 
 hlt

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

; -- #include ext/drive/query_drive_chs.csm
getDriveCHSProperties: 
	push es
	
	mov dl, [drive]
	mov ah, 08h 
 int 13h ; Query drive geometry
	
	inc dh
	xor ah, ah 
 mov al, dh
	mov [drive.CHS_headsPerCylinder], ax
	
	mov ax, cx
	and al, 0b00111111
	mov [drive.CHS_sectorsPerTrack], al
	
	mul dh
	mov [drive.CHS_sectorsTimesHeads], ax
	
	mov ax, cx ; LLLLLLLL|HHxxxxxx
	
	mov cl, 8
	rol ax, cl ; HHxxxxxx|LLLLLLLL
	
	mov cl, 6
	shr ah, cl ; ------HH|LLLLLLLL
	inc ax
	mov [drive.CHS_cylinders], ax
	
	pop es
ret 
; -- #include ext/drive/query_drive_lba.csm
getDriveLBAProperties: 
	mov dl, [drive]
	
	mov bx, 0x55AA
	mov ah, 41h 
 int 13h ; LBA available?
	
	jc .NoDriveLBA
	
	cmp bx, 0xAA55 
 jne .NoBiosLBA
	
	push ds                ; Save DS
	mov ax, 0 
 mov ds, ax ; Set DS to 0
	mov si, 0x2000         ; Load table to [0x0000:2000h]
	mov ah, 48h 
 int 13h  ; Query extended drive parameters.
		
	mov ax, [0x2000 + 0x18]                  ; Get bytes/sector
	pop ds                                   ; Get DS back
	mov byte [drive.LBA_support], 0          ; LBA is supported
	mov word [drive.LBA_bytesPerSector], ax  ; Save bytes/sector
	jmp .End
	
	.NoDriveLBA:
	mov byte [drive.LBA_support], 1
	jmp .End
	
	.NoBiosLBA:
	mov byte [drive.LBA_support], 2
	
	.End:
ret 

Constants:
	.string1: db "Welcome to XtOS!", 0

; --------- Variable space ---------
; -- #include ext/drive/daps.csm
lbaDAPS:	 db 16       ; Size
			 db 0x00     ; Always 0
			 dw 0x0001   ; Sectors to read
	.buffer: dw 0x2000   ; Destination buffer
			 dw 0x0000   ; Destination segment
	.lba:	 dd 0x000000 ; Lower LBA
			 dd 0x000000 ; Upper LBA
; -- #include ext/drive/drive_properties.csm
drive: db 0
	.CHS_bytesPerSector:    dw 0
	.CHS_sectorsPerTrack:   db 0
	.CHS_headsPerCylinder:  dw 0
	.CHS_sectorsTimesHeads: dw 0
	.CHS_cylinders:         dw 0	
	.LBA_support:           db 0
	.LBA_bytesPerSector:    dw 0
	.logicalBytesPerSector: dw 0

times (1024+512)-($-$$) db 0x90 ; Round to 1kb.
