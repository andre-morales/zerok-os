#include <comm/console.h>
#include <comm/console_macros.h>

[SECTION .text]
[BITS 16]
[CPU 8086]

; Request the current position of the curson on the screen
;
; Inputs: []
; Outputs: [DH = Row, DL = Column]
; Destroys: []
GLOBAL Video.GetCursor
Video.GetCursor: {
	push ax
	push bx
	push cx
	
	mov ah, 03h
	xor bh, bh
	int 10h
	
	pop cx
	pop bx
	pop ax
ret }

; Sets the cursor to a specific point on the screen
;
; Inputs: [DH = Row, DL = Column]
; Outputs: []
; Destroys: []
GLOBAL Video.SetCursor
Video.SetCursor: {
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
ret }

; Clear the contents of a rectangle in the screen
;
; Inputs: [$1 = Char Attribs, $2 = Origin point, $3 = Destination point]
; Outputs: []
; Destroys: []
GLOBAL Video.ClearRect
Video.ClearRect: {
	push bp
	mov bp, sp
	push ax | push bx | push cx | push dx
		
	mov ax, 0600h    ; AH = Scroll up, AL = Clear
	mov bh, [bp + 8] ; Param 1: Foreground / Background
	mov cx, [bp + 6] ; Param 2: Origin
	mov dx, [bp + 4] ; Param 3: Destination
	int 10h
		
	pop dx | pop cx | pop bx | pop ax
	pop bp
ret 6 }

; Clear the entire screen with a color and set the character back at the top left of the screen
;
; Inputs: [AX = Char attribs]
; Outputs: []
; Destroys: []
GLOBAL Video.ClearScreen
Video.ClearScreen: {
	; Color
	push ax
	
	; Origin point (0, 0)
	xor ax, ax
	push ax
	
	; Destination point (25, 39)
	mov ax, 18_27h
	push ax
	call Video.ClearRect
	
	xor dx, dx
	call Video.SetCursor
ret }

; Print a string with a color attribute
;
; Inputs: [SI = String, AL = Color]
; Outputs: []
; Destroys: [SI]
GLOBAL Video.PrintColor
Video.PrintColor: {
	push ax
	push bx
	push cx
	push dx
	
	; Save color
	xor bh, bh
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
		
		cmp al, 0Ah
		je .putraw
		cmp al, 0Dh
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
ret }	

; Draw a box with ascii characters on the screen
;
; Inputs: BX = Origin X:Y, AX = Box Width:Height
; Outputs: .
; Destroys: BX
GLOBAL Video.DrawBox
Video.DrawBox: {
	push bp
	mov bp, sp
	
	; Save some registers
	push ax ; Save box size (AX) 
			; [BP - 2] = Height
			; [BP - 1] = Width
	push cx 
	push dx
	
	; Set cursor to top box orgin
	mov dx, bx
	call Video.SetCursor

	; -- Draw top row with edges
	mov al, 0xC9
	call Console.Putch
	
	mov al, 0xCD
	mov cl, [bp - 1]
	call Console.Putnch
	
	mov al, 0xBB
	call Console.Putch
	
	; -- Left column
	mov dx, bx	
	mov al, 0xBA
	
	; Loop on the box height
	mov cl, [bp - 2]
	.leftC:
		inc dh
		call Video.SetCursor	
		call Console.Putch
	loop .leftC
	
	inc dh
	call Video.SetCursor	
	
	; -- Bottom box row with edges
	mov al, 0xC8
	call Console.Putch
	
	mov al, 0xCD
	mov cl, [bp - 1]
	call Console.Putnch
	
	mov al, 0xBC
	call Console.Putch
	
	; -- Right column
	; Set cursor to top right edge
	mov dx, bx
	add dl, [bp - 1]
	inc dl
	
	; Loop on the box height
	mov al, 0xBA
	mov cl, [bp - 2]
	.rightC:
		inc dh
		call Video.SetCursor	
		call Console.Putch
	loop .rightC	
	
	; Restore registers
	pop dx
	pop cx
	pop ax
	
	mov sp, bp
	pop bp
ret }