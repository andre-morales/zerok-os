[BITS 16]
[CPU 8086]
[ORG 0x3C00]

; Author:   André Morales 
; Version:  1.0
; Creation: 06/10/2020
; Modified: 28/10/2020

; -- #include ext/stdconio_h.csm
; Author:   André Morales 
; Version:  1.23
; Creation: 06/10/2020
; Modified:
; @ 05/01/2021

%define NL 0Ah
%define CR 0Dh
%define NLCR CR, NL

%macro Print 1-*
	%rep %0
		%ifid %1
			%if %1 == ax
				call printDecNumber
			%elif %1 == bx
				PrintDecNum %1
			%endif
		%else
			mov si, %1
			call printStr
		%endif
		%rotate 1
	%endrep
%endmacro
%macro PrintDecNum 1
	mov ax, %1
	call printDecNumber
%endmacro
%macro PrintHexNum 1
	mov ax, %1
	call printHexNumber
%endmacro
%macro Putch 1
	mov al, %1
	call putch
%endmacro
%macro Putnch 2
	mov al, %1
	mov cl, %2
	call putnch
%endmacro
%macro Pause 1
	call pause
%endmacro
%define Getch() call getch
%macro PrintColor 2
	mov si, %1
	mov al, %2
	call printColorStr
%endmacro
%macro DecNumToStr 1 
	mov ax, %1
	call decNumToStr
%endmacro
%macro ClearScreen 1
	mov ax, %1
	call clearScreen
%endmacro
%macro D_PrintHexNum 1
	push ax
	mov ax, %1
	call printHexNumber
	pop ax
%endmacro
%macro D_Print 1
	push si
	mov si, %1
	call printStr
	pop si
%endmacro

%macro PrintNumber 1
	push %1
	call PrintNumber16
%endmacro

; -- [0x800 - 0x1A00] Loaded sectors (MBR, Stage 1.5)
; -- [0xA00 - 0x1A00] Stage 1.5 code
; -- [0x800 - 0x2802] Test pages
; -- [0x3C00 - 0x3E00] Relocation Address

%define RELOCATION_ADDRESS 0x3C00
%define STAGE10_LOAD_SEGMENT 0x0080
%define STAGE15_SEGMENT (STAGE10_LOAD_SEGMENT + 0x20)
%define BYTES_PER_SECTOR_TEST_PAGE_SIZE (4096 + 1)
%define STAGE15_SIZE 512 + 8 * 512

Entry:	
	; Set up stack and clear segment registers
	cli
	xor cx, cx
	mov ss, cx
	mov sp, RELOCATION_ADDRESS 
	mov es, cx
	
	call .getIP
	
; Get IP pushed on the stack. [BX = IP]
.getIP:
	pop bx
	sub bx, (.getIP - Entry) ; Calculate correct entry point.
	
Relocate:	
	; -- Relocate ourselves from --
	; [DS:SI] -> [ES:DI]
	; [CS:SI] -> [0000h:0900h]
	
	push cs 
 pop ds
	mov si, bx
	mov di, sp ; Copy ourselves after the stack.

	; Copies everything except the boot signature.
	mov cl, 255 
 rep movsw
	push cs         ; Save it to print it later
	
	mov ds, cx      ; Set DS back to 0.	
	jmp 0000h:Start ; Far jump to known safe location

; -- Here it's safe to refer to our own data (strings, functions...) --
Start:	
	; Print welcome message followed by boot info
	Print(Constants.string1)	
	
	; Print boot CS:IP
	call PrintNumber16
	Putch(':')
	PrintNumber(bx) 
	
	; Boot drive
	Print(Constants.string2)	
	xor dh, dh
	PrintNumber(dx)
	
	; Discover drive sector size and print it
	Print(Constants.string3)
	
	; -- Figure out how many bytes per sector by brute forcing such discovery. --
	; Basically fills two separate areas in RAM with different contents,
	; then, loads the same first drive sector into both of them. And finnaly,
	; compare the two areas until they differ.
	mov bp, BYTES_PER_SECTOR_TEST_PAGE_SIZE
	
	; First area at 0x0800 [0080h:0000h]
	mov ax, STAGE10_LOAD_SEGMENT    
	mov es, ax
	xor di, di
	
	; Fill first area [0080h:0000h] with AL (0xB0).
	mov cx, bp 
	rep stosb
	
	; Fill second area [0080h:1004h] with AL (0xB1).
	inc ax
	mov cx, bp 
	rep stosb
	
	; Reset drive system
	xor ax, ax 
 int 13h 
	
	; Read sector to first area
	mov ax, 02_01h ; Read drive, read a single sector
	push ax
	inc cx         ; CH = Cylinder (0), CL = Sector (1)
	xor dh, dh     ; Head 0
	xor bx, bx     ; [ES:BX] = [00B0h:0000h]
	int 13h
	
	; Read the same sector to second area
	pop ax
	mov bx, bp ; [ES:BX] = [00B0h:1004h]
	int 13h
	
	; Compare [ES:DI](first area) and [DS:SI](second area)
	xor di, di
	mov si, STAGE10_LOAD_SEGMENT * 0x10 + BYTES_PER_SECTOR_TEST_PAGE_SIZE
	mov cx, bp
	repe cmpsb ; Repeat while they're equal. Stop when encountering a mismatch.
	
	dec di
		
	PrintNumber(di) ; Print sector size discovered
	
	Print(Constants.string4)	
	; Save drive number [DL] and HEAD[DH] = 0  
	push dx      

	; Divide stage size that by the sector size
	xor dx, dx
	mov ax, STAGE15_SIZE
	div di

	; Print how many sectors to load
	inc ax ; Always load 1 sector more (round up)
	PrintNumber(ax)
	Print(Constants.string5)

	; --- Read AL Sectors ---
	pop dx ; Get drive number back
	
	mov ah, 02  ; AH = 02: Read drive ; AL = Sectors to read
	xor bx, bx  ; Load drive sectors at [ES:BX] = [0080:0000]
	mov cl, 01  ; CH = Cylinder 0, CL = Sector 1
	int 13h     ; Read

	mov ax, [STAGE15_SEGMENT * 0x10]
	cmp ax, 'Xt'
	jne SignatureWrong

	Print(Constants.string6)
	
	jmp STAGE15_SEGMENT:0002h ; Jump to stage 2 after byte signature [00A0h:0002h]

SignatureWrong:
	Print(Constants.string7)
	PrintNumber(ax)
	cli 
 hlt

putch: 
	push bx
	
	mov ah, 0Eh
	xor bh, bh
	int 10h
	
	pop bx
ret
	
printStr: 
	push ax
	
	.char:
		lodsb
		test al, al
		jz .end
	
		call putch
	jmp .char
	.end:
	
	pop ax
ret 

; Prints 16 bit hexadecimal number.
PrintNumber16:
	Putch('0')	
	Putch('x')	
	
	pop cx ; Return address
	pop ax ; Get number
	push cx 
	
	push dx
			
	mov cx, 16
	call .printNumber
	
	pop dx
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
		jl .putc
		
		add al, 7
		
		.putc:
		call putch
	
		pop dx
		pop ax
    ret

Constants:
	.string1: db " @XtBootMgr v1.0.0", 0Dh, 0Ah, "Booted at ", 0
	.string2: db " from drive ", 0
	.string3: db ". ", 0Dh, 0Ah, "Sector size is: ", 0
	.string4: db " bytes.", 0Dh, 0Ah, "Loading ", 0
	.string5: db " sectors...", 0
	.string6: db " Loaded, OK!", 0
	.string7: db "", 0Dh, 0Ah, "Stage 1.5 is missing! Is it installed on sector 2?", 0Dh, 0Ah, "Bad signature: ", 0

times 440-($-$$) db 0x90 ; Fill the rest of the boostsector code with no-ops
dd 0x00000000            ; 4 bytes reserved for drive unique ID.
dw 0x000                 ; Reserved 2 bytes after UUID
times 64 db 0x00         ; 64 bytes reserved to partition table
dw 0xAA55                ; Boot signature
