[BITS 16]
[CPU 8086]
[ORG 0x3C00]

; Author:   André Morales 
; Version:  1.1.0
; Creation: 06/10/2020
; Modified: 01/02/2022

; -- [0x0800 - 0x2802] Test pages
; -- [0x0A00 - 0x1A00] Stage 2 code
; -- [0x3C00 - 0x3E00] Relocation Address

#include version_h.asm
#define STDCONIO_MINIMAL 1
#include <stdconio_h.asm>

; We'll move here to get out of the way and to be sure of our living address.
%define RELOCATION_ADDRESS 0x3C00
%define TEST_AREA_SEGMENT 0x0080
%define BYTES_PER_SECTOR_TEST_PAGE_SIZE (4096 + 1)
%define STAGE2_SEGMENT 0xA0
%define STAGE2_SIZE 7 * 512

Entry:	
	; -- Set up stack and clear segment registers
	cli         ; Preventing firing of interrupts is good pratice with bootloaders.
	
	xor cx, cx
	mov es, cx
	mov ss, cx  ; Stack at segment 0 and behind the relocation address.
	mov sp, RELOCATION_ADDRESS 
	
	call .getIP
	
; -- Get Instruction Pointer that was pushed on the stack by the near call.
.getIP:
	pop bx ; [BX = IP]
	; Calculate the address of the first instruction...
	; wich is where our code begins. Normally it is 7C00 but we test it for good measure.
	sub bx, (.getIP - Entry) 
	
Relocate:	
	; -- Relocate ourselves from --
	; [DS:SI] -> [ES:DI]
	; [CS:SI] -> [0000h:0900h]
	
	push cs | pop ds ; Move CODE segment into DATA segment so that the copy operation works fine.
	mov si, bx       ; The beginning we calculated earlier.
	mov di, sp       ; We'll copy ourselves after the stack pointer. (Wich we set before to be our relocation address.)

	; Copies everything except the boot signature. (510 bytes)
	mov cl, 255 | rep movsw
	push cs         ; Save it to print it later
	
	mov ds, cx      ; Set DS to 0.	
	jmp 0000h:Start ; Far jump to known safe location (CS is also 0 now)

; -- Here it's safe to refer to our own data (strings, functions...) --
Start:	
	; Print welcome message followed by boot info
	Print(."@XtBootMgr v${VERSION} \NBooted at ")	
	
	; Print boot CS:IP
	call printHexNum
	Putch(':')
	PrintHexNum(bx) 
	
	; Print boot drive ID
	Print(."h from drive ")	
	xor dh, dh
	PrintHexNum(dx)
	
	; Discover drive sector size and print it
	Print(."h. \NSector size is: 0x")

	/* -- Sector size test -- */
	; Figure out how many bytes per sector the boot drive has
	; by brute forcing such discovery.
	; We fill two separate areas in RAM with different contents,
	; and then, load the same drive sector into both of them. And finnaly,
	; we compare the two areas until they differ. 
	mov bp, BYTES_PER_SECTOR_TEST_PAGE_SIZE
	
	; First test area at 0x0800 [0080h:0000h]
	mov ax, TEST_AREA_SEGMENT    
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
	xor ax, ax | int 13h 
	
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
	mov si, TEST_AREA_SEGMENT * 0x10 + BYTES_PER_SECTOR_TEST_PAGE_SIZE
	mov cx, bp
	repe cmpsb ; Repeat while they're equal. Stop when encountering a mismatch.
	
	dec di
		
	PrintHexNum(di) ; Print sector size discovered

	Print(." bytes.\NLoading 0x")	
	
	/* Load stage 2 */
	; Save drive number [DL] and HEAD[DH] = 0  
	push dx      

	; Divide the stage 2 size by the drive sector size we discovered
	xor dx, dx
	mov ax, STAGE2_SIZE
	div di

	; Print how many sectors to load
	inc ax ; Always load 1 sector more (round up)
	PrintHexNum(ax)
	Print(." sectors.")

	; --- Read AL Sectors ---
	pop dx ; Get drive number back from the stack
	
	mov ah, 02  ; AH = 02: Read drive ; AL = Sectors to read
	xor bx, bx  ; Load drive sectors at [ES:BX] = [00A0:0000]
	mov cx, 01  ; CH = Cylinder 0, CL = Sector 1
	int 13h     ; Read

	Print(." Loaded; ")

	mov ax, [STAGE2_SEGMENT * 0x10]
	cmp ax, 'Xt' ; Test stage 2 signature to make sure everything went right.
	jne SignatureWrong

	Print(."OK.")
	
	jmp STAGE2_SEGMENT:0002h ; Jump to stage 2 after the 2-byte signature [00A0h:0002h]

SignatureWrong:
	Print(."\NStage 2 missing?\NBad signature: ")
	PrintHexNum(ax)
	hlt

#include <stdconio.asm>

@rodata:

times 440-($-$$) db 0x90 ; Fill the rest of the boostsector code with no-ops
dd 0x00000000            ; 4 bytes reserved for drive unique ID.
dw 0x000                 ; Reserved 2 bytes after UUID
times 64 db 0x00         ; 64 bytes reserved to partition table
dw 0xAA55                ; Boot signature