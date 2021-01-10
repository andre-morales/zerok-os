[BITS 16]
[CPU 8086]
[ORG 0x7C00]

; Author:   André Morales 
; Version:  0.3.0
; Creation: 07/10/2020
; Modified:
; @ 31/10/2020
; @ 02/01/2021

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
			%elif %1 == al
				xor ah, ah
				call printDecNumber
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
%macro D_Putch 1
	push ax
	mov al, %1
	call putch
	pop ax
%endmacro
; -- [0x0A00 -    ?  ] Stage 1.5
; -- [0x7600 - 0x77FF] MBR.
; -- [0x7800 - 0x79FF] Test VBR/EBR.
; -- [0x7A00 - 0x7BFF] Test VBR from EBR.
; -- [0x7C00 - 0x7DFF] Our loaded VBR (Stage 1).
; -- [0x7E00 - 0x7FFF] Unitialiazed varible storage

jmp Start 
 nop

times (21 + 12 + 26) db 0x00

Start:
	cli
	
	xor ax, ax
	mov ds, ax
	mov es, ax	
	mov ss, ax
	mov sp, 0x0A00
	
	mov [drive], dl
	mov word [drive.CHS_bytesPerSector], 512		
	call getDriveCHSProperties

	; Load MBR to 0x7600
	mov ax, 0
	push ax 
 push ax
	mov word [lbaDAPS.buffer], 0x7600
	call readSector
	
	; Load and compare VBRs in 0x7800
	mov si, 0x7600 + 0x1BE
	mov cx, 4
		
	.ReadPrimaryPartitionVBR:
		cmp byte [ds:si + 4], 0 
 jz .nextpart
	
		mov dx, [ds:si + 8]
		mov bx, [ds:si + 10]
		
			push bx
			
			mov word [lbaDAPS.buffer], 0x7800
			push bx 
 push dx
			call readSector
			
			pop bx
		
		
		cmp byte [ds:si + 4], 5 
 jne .normalPartition
		
		call ScanExtendedPartition
		jmp .nextpart
		
		.normalPartition: 
			push si 
 push cx
			
			mov si, 0x7800
			mov di, 0x7C00
			mov cx, 256
			repe cmpsw
			pop cx 
 pop si
			jz LoadStage2
		
		.nextpart:
		add si, 16
	loop .ReadPrimaryPartitionVBR
	jmp Halt

ScanExtendedPartition: 
	push bp
	mov bp, sp
	push cx 
 push si
	
	mov [extendedPartitionLBA], dx
	mov [extendedPartitionLBA + 2], bx
	mov si, 0x7800 + 0x1BE
	
	.firstEntry:
		push bx 
 push dx
		mov word [lbaDAPS.buffer], 0x7A00

		add dx, [ds:si + 8]
		adc bx, [ds:si + 10]
		
		
			push bx 
			push bx 
 push dx
			call readSector
			pop bx
		
		
		push si
			mov si, 0x7A00
			mov di, 0x7C00
			mov cx, 256
			repe cmpsw
		pop si
		jz .equal
		
		pop dx 
 pop bx
		jmp .secondEntry
		
		.equal:
		jmp LoadStage2		
	
	
	.secondEntry:
		cmp byte [ds:si + 16 + 4], 0
		jz .end
		
		mov ax, [ds:si + 16 + 8]
		mov cx, [ds:si + 16 + 10]
		
		add ax, [extendedPartitionLBA]
		mov dx, ax
		
		adc cx, [extendedPartitionLBA + 2]
		mov bx, cx		
		
			push bx 
			mov word [lbaDAPS.buffer], 0x7800
			push bx 
 push dx
			call readSector
			pop bx 
		
		
		jmp .firstEntry
		
	.end:
	pop si 
 pop cx
	
	mov sp, bp
	pop bp
ret 

LoadStage2:
	push bx 
 push dx
	xor bp, bp
	
	mov word [lbaDAPS.buffer], 0x0A00
	.loadSector:
		add dx, 1
		adc bx, 0
		
		push bx
		push bx 
 push dx
		call readSector
		pop bx
		
		add word [lbaDAPS.buffer], 0x0200
		
		test bp, bp 
 jz .getSignature_SectCount
	loop .loadSector
	jmp .jump	
	
		.getSignature_SectCount:
		cmp word [0x0A00], 'Xt' 
 jne SignatureError
		mov cx, [0x0A02]
		inc bp
	loop .loadSector
		
	.jump:
	mov dl, [drive]
	jmp 0x0A04

SignatureError:
	

Halt:
	mov ah, 0Eh
	mov al, 'H'
	int 10h
	
	cli 
 hlt	

; void (int32 LBA)
readSector: 
	push bp
	mov bp, sp
	sub sp, 4
	
	push es 
 push di
	push si
	push cx 
 push dx
		
	; -- Reading as CHS (Convert LBA to CHS) --
	; Calculate cylinder to BP - 2
	mov dx, [bp + 6] 
 mov ax, [bp + 4]          ; Get LBA
	div word [drive.CHS_sectorsTimesHeads]       ; LBA / (HPC * SPT) | DX:AX / (HPC * SPT)
	mov [bp - 2], ax                             ; Save Cylinders
	
	cmp ax, [drive.CHS_cylinders] 
 jle .CHSRead ; Is cylinder number safe?
	mov ah, 1 
 jmp Halt ; Error code 1. Cylinder too big.
	
	.CHSRead:
	; Calculate sector to BP - 3
	mov dx, [bp + 6] 
 mov ax, [bp + 4]              ; Get LBA
	xor ch, ch 
 mov cl, [drive.CHS_sectorsPerTrack] 
	div cx                                           ; LBA % SPT + 1 | LBA % CX + 1
	inc dx
	mov [bp - 3], dl
	
	; Calculate head to BP - 4
	xor dx, dx
	div word [drive.CHS_headsPerCylinder]            ; (LBA / SPT) % HPC # (LBA / CX) % HPC
	mov [bp - 4], dl
	
	; Cylinder
	mov ax, [bp - 2]
	mov cl, 8 
 rol ax, cl
	mov cl, 6 
 shl al, cl 
	mov cx, ax
	
	or cl, [bp - 3]  ; Sector
	mov dh, [bp - 4] ; Head
	
	xor bx, bx 
 mov es, bx
	mov bx, [lbaDAPS.buffer]
	mov dl, [drive]
	mov al, 1
	mov ah, 0x02 
 int 13h ; CHS read
	
	xor ax, ax
	
	.End:
	pop dx 
 pop cx
	pop si
	pop di 
 pop es
	
	mov sp, bp
	pop bp
	
	pop bx    ; Get return address from stack
	add sp, 4 ; Remove argument from stack
jmp bx 
	
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

Constants:

times 510-($-$$) db 0x90 ; Fill the rest of the boostsector code with no-ops
dw 0xAA55                ; Boot signature

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

extendedPartitionLBA: dd 0
