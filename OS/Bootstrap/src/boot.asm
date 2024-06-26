/** 
 * Boot (Stage 1) 
 *
 * Author:   André Morales 
 * Creation: 07/10/2020
 * Modified: 06/05/2024
 *
 * First stage in the booting process. This loader will be recored in the VBR of the partition
 * the OS gets installed on.
 * Due to size limits, this loader can only use CHS or LBA but not both.
 *
 * :: MEMORY MAP ::
 * -- [...    - 0x1000] Stack
 * -- [0x6000 -   ... ] Where Stage 2 will be loaded.
 * -- [0x7600 -    #  ] Loaded MBR.
 * -- [0x7800 -    #  ] Test VBR/EBR.
 * -- [0x7A00 -    #  ] Test VBR from EBR.
 * -- [0x7C00 -    #  ] Our loaded VBR (Stage 1).
 * -- [0x7E00 -   ... ] Varible storage
 **/

#include "version.h"
#define CONSOLE_MACROS_MINIMAL 1
#include <comm/console.h>
#include <comm/console_macros.h>

%define STAGE2_ADDR 0x6000

[SECTION .text]
[BITS 16]
[CPU 8086]

; 3-byte jmp instruction
jmp start | nop

; Dummy space for BPB.
times (21 + 12 + 26) db 0x11

; Actual start of code at 0x3E
start: {
	cli
	
	; Clear all segments and setup stack from 0x1000 and behind
	xor ax, ax
	mov ds, ax
	mov es, ax	
	mov ss, ax
	mov sp, 0x1000
	
	; Check drive number and save it
	call VerifyDriveNumber
	mov [Drive.id], dl
	
	CONSOLE_PRINT(."-- ZkBootrap $#VERSION#")
	
	call TryDrive
	
	; If loading fails, try drive 0x80.
	mov byte [Drive.id], 0x80
	call TryDrive
	
	; If that fails. Just halt.
	mov al, 'N'
	jmp haltm
}

; Check if drive number is sane, if it's not, set it to 0x80
; This procedure is the same one used by GRUB 2
VerifyDriveNumber: {
	; If DL is less than 0x80, set it to 0x80.
	test dl, 0x80
	jz .reset
	
	; If DL is greater than 0x8F. Set it to 0x80.
	test dl, 0x70
	jz .end ; Drive number is safely between 0x80 - 0x8F
	
	.reset:
	mov dl, 0x80
	
	.end:
ret }

TryDrive: {
	; Initialize drive system
	call Drive.Init

	/* Now we will read the VBRs of the 4 partition entries in the MBR and check 
	if they refer to our current partition. If any of these entries is an extended partiton,
	check the extended partitions too. */

	; Load MBR (sector 0) to 0x7600
	xor dx, dx
	xor bx, bx
	mov di, 0x7600
	call Drive.ReadSector

	; Point SI to the first entry in the MBR
	mov si, (0x7600+0x1BE)
	mov cx, 4
	
	; Load and compare VBRs in 0x7800
	.ReadPrimaryVBR:
		; If the first byte of the entry is 0, skip this entry.
		cmp byte [si + 4], 0 | jz .nextpart
		
		; Load first sector of the partition to 0x7800
		mov dx, [si + 8]
		mov bx, [si + 10]
		mov di, 0x7800
		call Drive.ReadSector
		
		; Check if it is an extended partition (type 0x05)
		cmp byte [si + 4], 5 | jne .normalPartition
		
		call ScanExtendedPartition
		jmp .nextpart
		
		; It is a normal partition. Compare the loaded VBR to our own code.
		.normalPartition: {
			mov di, 0x7800
			call CompareVBR
		}
		
		.nextpart:
		add si, 16
	loop .ReadPrimaryVBR
ret }

/** Compares the sector pointed at DI to our VBR loaded at 0x7C00.
If they are equal, jump to loadStage2, if not, return. */
CompareVBR: {
	push si | push cx
		
	mov si, 0x7C00
	mov cx, 256
	repe cmpsw
	
	pop cx | pop si
	je loadStage2
ret }

ScanExtendedPartition: {
	push bp
	mov bp, sp
	push cx | push si
	
	CLSTACK
	lvar word extendedLBA_H
	lvar word extendedLBA_L
	sub sp, $stack_vars_size
	
	mov [$extendedLBA_L], dx
	mov [$extendedLBA_H], bx
	mov si, 0x7800 + 0x1BE
	
	.firstEntry:
		push bx | push dx

		add dx, [ds:si + 8]
		adc bx, [ds:si + 10]
		mov di, 0x7A00
		call Drive.ReadSector
				
		push si
			mov si, 0x7A00
			mov di, 0x7C00
			mov cx, 256
			repe cmpsw
		pop si
		je loadStage2
		
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

		mov di, 0x7800
		call Drive.ReadSector
		
		jmp .firstEntry
		
	.end:
	pop si | pop cx
	
	mov sp, bp
	pop bp
ret }

; Loads stage 2.
loadStage2: {
	; Sector where this VBR was found. This is used in Stage 2.	
	push bx
	push dx

	; Read the first sector after our VBR
	mov si, STAGE2_ADDR
	mov di, si
	call .ReadNextSector
	
	; Get the signature stored in the begginning of Stage 2 and test it.
	lodsw 		 
	cmp ax, 'Xt'
	jne .invalidSignature
	
	; Get sector count stored in the begginning of Stage 2.
	; And load that many sectors
	mov cx, [si] 
	.lsect:
		call .ReadNextSector
	loop .lsect
	
	; Restore drive number and jump to Stage 2
	mov dl, [Drive.id]
	jmp STAGE2_ADDR + 4
	
	.invalidSignature: {
		mov al, 's'
		jmp haltm
	}
	
	/* Subroutine that reads a sector stored in DX:BX,
	then increases DX:BX, and moves the buffer pointer forward
	by 0x200 bytes. */
	.ReadNextSector: {
		add dx, 1
		adc bx, 0
		
		call Drive.ReadSector
				
		add di, 0x200
	ret }
}

/** Halt with an error character stored in AL. */
haltm: {
	mov ah, 0Eh
	int 10h	
	
	cli | hlt	
}

Drive:
	var byte Drive.id	
	
#ifdef LBA_AVAILABLE
	var short Drive.bytesPerSector

	.Init: {
		mov di, lbaDAPS
		
		; Clear DAPS
		mov cx, 16
		xor ax, ax
		rep stosb
		
		mov byte [lbaDAPS.size], 16
		mov word [lbaDAPS.sectors], 1
	
		mov dl, [Drive.id]
		
		; INT 13h : 41h : Query LBA availability 
		mov bx, 0x55AA
		mov ah, 41h | int 13h
		
		jc .NoLBA
		cmp bx, 0xAA55 | jne .NoLBA
		
		mov si, 0x2000         ; Load table to [0x0000:2000h]
		mov ah, 48h | int 13h  ; Query extended drive parameters.
			
		mov ax, [0x2000 + 0x18]              ; Get bytes/sector
		mov word [Drive.bytesPerSector], ax  ; Save bytes/sector	
	ret }
	
	.NoLBA:
		mov al, 'L'
		jmp haltm
	
	; readSector(DX:BX lba)
	.ReadSector: {
		CLSTACK
		ENTERFN
		
		push bx | push dx
		push es | push di
		push si | push cx
		
		mov [Drive.bufferPtr], di
		
		mov ax, [bp - 4]
		mov [Drive.readLBA + 0], ax
		
		mov ax, [bp - 2]
		mov [Drive.readLBA + 2], ax

		mov dl, [Drive.id]
		mov si, lbaDAPS
				
		mov ah, 0x42 | int 13h ; Extended read
		xor ax, ax

		pop cx | pop si
		pop di | pop es
		pop dx | pop bx

		LEAVEFN
	}
#else
	var void Drive.CHSaddr
	var short Drive.heads
	var short Drive.sectors
	var short Drive.sectorsTimesHeads
	var short Drive.cylinders
	
	.Init: {
		push es
		
		mov dl, [Drive.id]
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
	
	; [BX:DX] = Sector LBA
	; [DI] = Desination pointer in DX
	.ReadSector: {
		CLSTACK
		; [ BP - 2]
		lvar short CYLINDER 
		; [ BP - 3]
		lvar byte SECTOR  
		; [ BP - 4]		
		lvar byte HEAD      
		ENTERFN

		push si ; [BP - 6]
		push cx ; [BP - 8]
		
		; Save sector LBA BX:DX at the top of the stack
		push bx ; [BP - 10]
		push dx ; [BP - 12]
		
		; -- Reading as CHS (Convert LBA to CHS) --
		; 1) Calculate cylinder
		; Recover LBA into DX:AX and save it again to keep it on the stack
		pop ax
		pop dx
		push dx
		push ax

		div word [Drive.sectorsTimesHeads]   ; LBA / (SPT * HPC)
		mov [$CYLINDER], ax                  ; Save Cylinders
		
		cmp ax, [Drive.cylinders] | jg haltm ; Is cylinder number safe (out of bounds)?

		; 2) Calculate sector
		; Recover LBA into DX:AX and save it again to keep it on the stack
		pop ax
		pop dx
		push dx
		push ax     
		
		div word [Drive.sectors]     ; LBA % SPT + 1 
		inc dx
		mov [$SECTOR], dl
		
		; 3) Calculate head index
		xor dx, dx
		div word [Drive.heads]    ; (LBA / SPT) % HPC
		mov [$HEAD], dl
		
		; Now restore the values calculated to read a sector
		; CH = Cylinder
		; CL = Sector
		; DH = Head
		; DL = Drive
		
		; Cylinder
		mov ax, [$CYLINDER]
		xchg ah, al
		mov cl, 6
		shl al, cl 
		mov cx, ax
		
		; Sector (6 bits)
		or cl, [$SECTOR]
		
		; Head
		mov dh, [$HEAD]
		
		mov bx, di
		mov dl, [Drive.id]
		mov ax, 0x02_01 | int 13h ; CHS read
		
		pop dx | pop bx
		pop cx | pop si
		
		LEAVEFN
	}
#endif

Console.Print: {
	push ax | push bx | push dx	
	
	.char:
		lodsb
		test al, al | jz .end
		
		xor bh, bh  ; Page 0
		mov ah, 0Eh
		int 10h     ; Print character
	jmp .char
		
	.end:
	pop dx | pop bx | pop ax
ret }

@rodata:

; --------- Variable space ---------
[SECTION .bss]
#ifdef LBA_AVAILABLE
lbaDAPS:			 
	.size:			 resb 1 ; Size (16)
					 resb 1 ; Always 0
	.sectors:		 resw 1 ; Sectors to read (1)
	Drive.bufferPtr: resw 1 ; Destination buffer (0x2000)
					 resw 1 ; Destination segment (0)
	Drive.readLBA:	 resd 1 ; Lower LBA (~)
					 resd 1 ; Upper LBA (0)
#endif

@bss:
