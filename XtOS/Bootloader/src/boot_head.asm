[BITS 16]
[CPU 8086]
[ORG 0x7C00]

/* Boot Head (Stage 1)
   Author:   André Morales 
   Version:  0.6.3
   Creation: 07/10/2020
   Modified: 27/01/2022 */

#include <stdconio_h.asm>
#include version_h.asm

%define STAGE2_ADDR 0x6000

; -- [...    - 0x06FF] Stack
; -- [0x6000 -   ... ] Where Stage 2 will be loaded.
; -- [0x7600 - 0x77FF] Loaded MBR.
; -- [0x7800 - 0x79FF] Test VBR/EBR.
; -- [0x7A00 - 0x7BFF] Test VBR from EBR.
; -- [0x7C00 - 0x7DFF] Our loaded VBR (Stage 1).
; -- [0x7E00 - 0x7FFF] Varible storage

; 3-byte jmp instruction
jmp Start

; Space for BPB.
times (21 + 12 + 26) db 0xFF

; Start of code at 0x3E
SECTION .text
Start: {
	cli
	
	xor ax, ax
	mov ds, ax
	mov es, ax	
	mov ss, ax
	mov sp, 0x0700
		
	mov [Drive.id], dl
	
	Print(."${VERSION}")
	
	call Drive.GetProperties

	; Load MBR to 0x7600
	xor dx, dx
	xor bx, bx
	mov word [Drive.bufferPtr], 0x7600
	call Drive.ReadSector
	
	; Load and compare VBRs in 0x7800
	mov si, 0x7600 + 0x1BE
	mov cx, 4
	
	; Test the VBRs of the 4 primary partitions listed in the MBR.
	.ReadPrimaryVBR:
		cmp byte [si + 4], 0 | jz .nextpart
	
		mov dx, [si + 8]
		mov bx, [si + 10]
		mov word [Drive.bufferPtr], 0x7800
		call Drive.ReadSector
		
		; Check if it is an extended partition (type 0x05)
		cmp byte [si + 4], 5 | jne .normalPartition
		
		call ScanExtendedPartition
		jmp .nextpart
		
		; It is a normal partition. Compare the loaded VBR to our own code.
		.normalPartition: {
			push si | push cx
			
			mov si, 0x7800
			mov di, 0x7C00
			mov cx, 256
			repe cmpsw
			pop cx | pop si
			jz LoadStage2
		}
		.nextpart:
		add si, 16
	loop .ReadPrimaryVBR
	jmp Halt
}

ScanExtendedPartition: {
	push bp
	mov bp, sp
	push cx | push si
	
	_clstack()
	lvar word extendedLBA_H
	lvar word extendedLBA_L
	sub sp, $stack_vars_size
	
	mov [$extendedLBA_L], dx
	mov [$extendedLBA_H], bx
	mov si, 0x7800 + 0x1BE
	
	.firstEntry:
		push bx | push dx
		mov word [Drive.bufferPtr], 0x7A00

		add dx, [ds:si + 8]
		adc bx, [ds:si + 10]
		call Drive.ReadSector
				
		push si
			mov si, 0x7A00
			mov di, 0x7C00
			mov cx, 256
			repe cmpsw
		pop si
		je LoadStage2
		
		pop dx | pop bx

	.secondEntry:
		cmp byte [ds:si + 16 + 4], 0
		jz .end

		mov ax, [ds:si + 16 + 8]
		mov cx, [ds:si + 16 + 10]
		
		add ax, [$extendedLBA_L]
		mov dx, ax
		
		adc cx, [$extendedLBA_H]
		mov bx, cx		

		mov word [Drive.bufferPtr], 0x7800
		call Drive.ReadSector
		
		jmp .firstEntry
		
	.end:
	pop si | pop cx
	
	mov sp, bp
	pop bp
ret }

; Loads stage 2.
LoadStage2: {
	; Sector where this VBR was found. This is used in Stage 2.	
	push bx | push dx

	; BP = 0; Still not found the signature.
	; BP = 1; Found the Xt signature and is loading sectors.
	xor bp, bp
	
	mov si, STAGE2_ADDR
	mov word [Drive.bufferPtr], si
	.loadSector:
		add dx, 1
		adc bx, 0
		
		call Drive.ReadSector
		
		add word [Drive.bufferPtr], 0x0200
		
		test bp, bp | jz .getSignature_SectCount
	loop .loadSector
	
	mov dl, [Drive.id]
	jmp STAGE2_ADDR + 4
	
	.getSignature_SectCount:
		lodsw
		cmp ax, 'Xt' | jne Halt ; Halt on invalid signature.
		mov cx, [si]
		inc bp
	loop .loadSector
	
}

Halt: {
	mov ax, 0E48h ; ah = 0x0E al = 'H'
	int 10h	
	hlt	
}

Drive:
	var byte Drive.id	
	var short Drive.bytesPerSector
	
#ifdef LBA_AVAILABLE
	.GetProperties: {
		mov di, lbaDAPS
		xor ax, ax
		mov cx, 16 | rep stosb
		mov byte [lbaDAPS.size], 16
		mov word [lbaDAPS.sectors], 1
	
		mov dl, [Drive.id]
		
		mov bx, 0x55AA
		mov ah, 41h | int 13h ; LBA available?
		
		jc .NoLBA
		cmp bx, 0xAA55 | jne .NoLBA
		
		push ds                ; Save DS
		mov ax, 0 | mov ds, ax ; Set DS to 0
		mov si, 0x2000         ; Load table to [0x0000:2000h]
		mov ah, 48h | int 13h  ; Query extended drive parameters.
			
		mov ax, [0x2000 + 0x18]              ; Get bytes/sector
		pop ds                               ; Get DS back
		mov word [Drive.bytesPerSector], ax  ; Save bytes/sector
	ret }
	
	.NoLBA:
		jmp Halt
	
	; readSector(DX:BX lba)
	.ReadSector: {
		push bp
		mov bp, sp
		push bx | push dx
		push es | push di
		push si
		push cx
		
		mov ax, [bp - 4] | mov [Drive.readLBA + 0], ax
		mov ax, [bp - 2] | mov [Drive.readLBA + 2], ax
		mov dl, [Drive.id]
		mov si, lbaDAPS
				
		mov ah, 0x42 | int 13h ; Extended read
		xor ax, ax

		pop cx
		pop si
		pop di | pop es
		pop dx | pop bx
		
		mov sp, bp
		pop bp
	ret }
#else
	var void Drive.CHSaddr
	var short Drive.headsPerCylinder
	var short Drive.sectorsPerTrack
	var short Drive.sectorsTimesHeads
	var short Drive.cylinders
	
	.GetProperties: {
		push es
		
		mov dl, [Drive.id]
		mov word [Drive.bytesPerSector], 512
		mov ah, 08h | int 13h ; Query drive geometry
		
		pop es
		
		mov di, Drive.CHSaddr
		
		; Calculate heads.		
		inc dh
		xor ah, ah | mov al, dh
		stosw ; Heads per Cylinder
		
		; Calculate sectors
		mov ax, cx
		and ax, 00000000_00111111b
		stosw ; Sectors per Track
		
		; Sectors * Heads
		mul dh
		stosw ; Sectors times Heads
		
		; Cylinders
		mov ax, cx  ; LLLLLLLL|HHxxxxxx
		xchg ah, al ; HHxxxxxx|LLLLLLLL
		
		mov cl, 6
		shr ah, cl ; ------HH|LLLLLLLL
		inc ax
		stosw ; Cylinders
	ret }
	
	.ReadSector: {
		push bp
		mov bp, sp
		
		_clstack()
		lvar short CYLINDER
		lvar byte SECTOR
		lvar byte HEAD
		sub sp, $stack_vars_size
		
		push bx | push dx
		push si
		push cx
			
		; -- Reading as CHS (Convert LBA to CHS) --
		; Calculate cylinder
		mov dx, [bp - 6] | mov ax, [bp - 8] ; Get LBA
		div word [Drive.sectorsTimesHeads]  ; LBA / (HPC * SPT) | DX:AX / (HPC * SPT)
		mov [$CYLINDER], ax                 ; Save Cylinders
		
		cmp ax, [Drive.cylinders] | jg Halt ; Is cylinder number safe (out of bounds)?

		; Calculate sector to BP - 3
		mov dx, [bp - 6] | mov ax, [bp - 8]              ; Get LBA
		div word [Drive.sectorsPerTrack]                 ; LBA % SPT + 1 | LBA % CX + 1
		inc dx
		mov [$SECTOR], dl
		
		; Calculate head to BP - 4
		xor dx, dx
		div word [Drive.headsPerCylinder]            ; (LBA / SPT) % HPC # (LBA / CX) % HPC
		mov [$HEAD], dl
		
		; Cylinder
		mov ax, [$CYLINDER]
		xchg ah, al
		mov cl, 6 | shl al, cl 
		mov cx, ax
		
		or cl, [$SECTOR] ; Sector
		mov dh, [$HEAD]  ; Head
		
		mov bx, [Drive.bufferPtr]
		mov dl, [Drive.id]
		mov ax, 0x02_01 | int 13h ; CHS read
		
		pop cx
		pop si
		pop dx | pop bx
		
		mov sp, bp
		pop bp	
	ret }
#endif

print: {
	push ax | push bx	
	
	.char:
		lodsb
		test al, al | jz .end
		
		xor bh, bh  ; Page 0
		mov ah, 0Eh
		int 10h     ; Print character
	jmp .char
		
	.end:
	pop bx | pop ax
ret }

@rodata:

times 510-($-$$) db 0x90 ; Fill the rest of the boostsector code with no-ops
dw 0xAA55                ; Boot signature

; --------- Variable space ---------
SECTION .bss vstart=0x7E00
#ifdef LBA_AVAILABLE
lbaDAPS:			 
	.size:			 resb 1 ; Size (16)
					 resb 1 ; Always 0
	.sectors:		 resw 1 ; Sectors to read (1)
	Drive.bufferPtr: resw 1 ; Destination buffer (0x2000)
					 resw 1 ; Destination segment (0)
	Drive.readLBA:	 resd 1 ; Lower LBA (~)
					 resd 1 ; Upper LBA (0)
#else
	Drive.bufferPtr: resw 1 ; Destination buffer (0x2000)
#endif

@data:
