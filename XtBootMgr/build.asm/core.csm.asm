[BITS 16]
[CPU 8086]

; Author:   André Morales 
; Version:  0.37.1
; Creation: 07/10/2020
; Modified: 28/10/2020

%define STACK_ADDRESS 0xA00
%define PARTITION_ARRAY 0x1B00

; -- [0x500 - 0xA00] Stack
; -- [0xA00 - 0x1A00] Loaded stage 1.5
; -- [0x1A00 - 0x1B00] Unitialiazed varible storage
; -- [0x1B00 - 0x1C00] Partition array
; -- [0x2000] Generic stuff buffer
%include "ext/enter_leave8086_h.asm"
%include "ext/stdconio_h.asm"

db 'Xt' ; Signature

Start:
	mov sp, 0xA00 ; Readjust stack behind us

	push cs 
 pop ds        ; Copy CS [Segment 0xA0] to Data Segment
	xor ax, ax 
 mov es, ax ; Set ES to 0
	
	mov [drive], dl ; Save drive number
	mov [drive.CHS_bytesPerSector], di ; Save bytes per sector.
	sti           ; Reenable interrupt

	Print(Constants.string1)
	Print(Constants.string2)
	
	; Set up division error int handler.
	mov word [es:0000], DivisionErrorHandler
	mov word [es:0002], ds
	
	call getCurrentVideoMode
	call getDriveGeometry
	
	Print(Constants.string3) 
	Pause()
	mov di, PARTITION_ARRAY
	xor ax, ax
	push ax 
 push ax ; LBA 0. (MBR)
	push ax           ; In root mbr.
	call getPartitionMap
	
	Print(Constants.string4)
	mov ax, di
	sub ax, PARTITION_ARRAY
	
	mov cl, 9
	div cl
	mov [partitionMapSize], al
	
	Print(Constants.string5)
	Pause()
		
	mov word [cursor], 0
	
	MainMenu:
		call clearScreen
		mov bx, 00_00h
		mov ax, 25_17h
		call drawSquare
	
		mov dx, 01_01h 
 call setCursor
		
		Print(Constants.string6)
		
		xor ah, ah 
 mov al, [drive]
		call printHexNumber
	
	MenuSelect:	
		call DrawMenu	
			
		Getch()
		cmp ah, 48h 
 je .upKey
		cmp ah, 50h 
 je .downKey
		cmp ah, 1Ch 
 je .enterKey
		jmp MenuSelect
		
		.upKey:
			mov ax, [cursor]
			test ax, ax 
 jnz .L3
			
			mov al, [partitionMapSize]
			
			.L3:
			dec ax
			div byte [partitionMapSize]
			mov [cursor], ah
		jmp MenuSelect
		
		.downKey:
			mov ax, [cursor]
			inc ax
			div byte [partitionMapSize]
			mov [cursor], ah
		jmp MenuSelect
		
		.enterKey:
			mov al, 9 
 mul byte [cursor]
			mov di, ax
			
			lodsb
			cmp byte [es:PARTITION_ARRAY + di], 05h 
 jne .L4
			Print(Constants.string7)
			jmp BackToMainMenu
			
			.L4:
			Print(Constants.string8)
		jmp BackToMainMenu
		
		BackToMainMenu:
			Pause()
			call clearScreen
		jmp MainMenu

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
	
	Print(Constants.string9)
	PrintHexNum [bp + 6]
	PrintHexNum [bp + 4]
	Print(Constants.string10)
	
	cmp byte [drive.LBA_support], 0
	jne .LBAtoCHS ; LBA not supported. Try CHS translation.
	
	; -- Reading as LBA --
	mov ax, [bp + 4] 
 mov [lbaDAPS.lba + 0], ax
	mov ax, [bp + 6] 
 mov [lbaDAPS.lba + 2], ax
	mov dl, [drive]
	mov si, lbaDAPS
	mov ah, 0x42 
 int 13h ; Extended read
	xor ax, ax
	jmp .End
	
	; -- Reading as CHS (Convert LBA to CHS) --
	.LBAtoCHS: 		
		; Calculate cylinder to BP - 2
		mov dx, [bp + 6] 
 mov ax, [bp + 4]          ; Get LBA
		div word [drive.CHS_sectorsTimesHeads]       ; LBA / (HPC * SPT) | DX:AX / (HPC * SPT)
		mov [bp - 2], ax                             ; Save Cylinders
		
		; Print cylinder
		Print(Constants.string11)
		call printHexNumber
		
		cmp ax, [drive.CHS_cylinders] 
 jle .CHSRead ; Is cylinder number sabe?
		
		mov ax, 1 
 jmp .End ; Error code 1. Cylinder too big.
		
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
		
		Print(Constants.string12)
		xor ah, ah
		mov al, [bp - 4]
		call printHexNumber
		
		Print(Constants.string13)
		xor ah, ah
		mov al, [bp - 3]
		call printHexNumber
		Print(Constants.string14)
		
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
		mov bx, 0x2000
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

; void (ES:DI pntrToPartitionArray, int32 LBA, int16 inMBR)
getPartitionMap: 
	; + 6 (32) Address of the MBR we are going to load.
	; + 4 (16) If we are at the root MBR (0) or exploring the EBR daisy chain (1)
	; + 2 (16) Return Address
	; + 0 (16) Older BP.

	push bp
	mov bp, sp
	push ds ; Save DS
	push bx ; save BX
	push cx ; Save CX
	push si ; Save SI

	; Push to stack the address of the MBR, and read the MBR to the common buffer at 0x2000.
	push word [bp + 8] 
 push word [bp + 6] 
	call readSector
	test ax, ax 
 je .GetPartitionEntries ; Did it read properly?
	
	; AX is not 0. It failed somehow.
	Print(Constants.string15)
	cmp ax, 1 
 je .OutOfRangeCHS
	Print(Constants.string16)
	jmp .ErrorOut
	
	.OutOfRangeCHS:
	Print(Constants.string17)
	
	.ErrorOut:
	Print(Constants.string18)
	jmp .End
	
	.GetPartitionEntries:
	; Set DS:SI to point to the common buffer + end of the partion table.
	mov ax, 0 
 mov ds, ax
	mov si, 0x2000 + 0x1BE + 48
	
	mov cx, 4
	mov dx, 0
	.FindPart:
		mov al, [ds:si + 4]     ; Get partition type.
		test al, al 
 je .next0 ; Partition type null, look next slot.
		
		inc dx
		push ax        ; Save partition type.
		
		; Add current MBR address with starting LBA address.
		; Save starting LBA (low)
		mov ax, [ds:si + 8]
		add ax, [ss:bp + 6]
		push ax
		
		; Save starting LBA (high)
		mov ax, [ds:si + 10]
		adc ax, [ss:bp + 8]
		push ax	
		
		; Save partition size
		push word [ds:si + 12]
		push word [ds:si + 14]
		
		.next0:
		sub si, 16
	loop .FindPart
	
	mov ds, [bp - 2] ; Get DS back
	mov cx, dx
	.GetPart:
		mov bx, sp
		mov dl, [ss:bx + 8] ; Get partition type
		cmp dl, 05h ; Is it an extended partition?
		jne .store  ; It's not, just store it.
		
		cmp byte [bp + 4], 1 ; Are we already exploring the EBR daisy chain?
		je .ebr              ; Yes, don't store yet another EBR entry, go straight to the recursion.
		
		.store:		
		mov al, dl          
 stosb ; Store partition type to ES:DI
		mov ax, [ss:bx + 6] 
 stosw ; Store low part of LBA address
		mov ax, [ss:bx + 4] 
 stosw ; Store high part of LBA address
		mov ax, [ss:bx + 2] 
 stosw ; Store low part of partition size
		mov ax, [ss:bx + 0] 
 stosw ; Store high part of partition size
		
		cmp dl, 05h 
 jne .next1 ; Is it a extended partition type?
		
		.ebr:		
		; It is. Call ourselves with its LBA address...	
		; Push LBA address and push nesting depth
		push word [ss:bx + 4] ; High part
		push word [ss:bx + 6] ; Low part
		mov dx, 1 
 push dx   ; Explore the EBR daisy chain
		call getPartitionMap
		
		.next1:
		add sp, 10  ; Remove partition entry from stack.
	loop .GetPart
	
	.End:
	pop si
	pop cx
	pop bx
	
	mov sp, bp
	pop bp
	pop dx    ; Get return address
	add sp, 6 ; Remove parameters at the stack.
jmp dx 

getCurrentVideoMode: 
	mov ah, 0Fh 
 int 10h
	push ax
	Print(Constants.string19)
	xor ah, ah
	call printHexNumber
	
	Print(Constants.string20)
	pop ax
	mov al, ah
	xor ah, ah
	call printDecNumber	
ret 

getDriveGeometry: 
	Print(Constants.string21)
	Print(Constants.string22)
	
	call getDriveCHSProperties
	
	; -- Print CHS properties --
	Print(Constants.string23)
	PrintDecNum [drive.CHS_bytesPerSector]
	
	xor ah, ah
	Print(Constants.string24)
	mov al, [drive.CHS_sectorsPerTrack]
	call printDecNumber

	Print(Constants.string25)
	PrintDecNum [drive.CHS_headsPerCylinder]
	
	Print(Constants.string26)
	PrintDecNum [drive.CHS_sectorsTimesHeads]
	
	Print(Constants.string27)
	PrintDecNum [drive.CHS_cylinders]
	
	Print(Constants.string28)
	call getDriveLBAProperties
	
	mov al, [drive.LBA_support]
	cmp al, 2 
 je .printLBAProps
	cmp al, 1 
 je .noDriveLBA
	Print(Constants.string29)
	jmp .End
	
	.noDriveLBA:
	Print(Constants.string30)
	jmp .End
	
	.printLBAProps:
	Print(Constants.string31)
	PrintDecNum [drive.LBA_bytesPerSector]
	
	.End:
ret 

DrawMenu: 
	push bp
	mov bp, sp
	sub sp, 2
	mov word [bp - 2], 0
	push ds
	push es
	
	mov dx, 03_03h 
 call setCursor
	
	mov di, PARTITION_ARRAY
	xor cl, cl
	.drawPartition:
		xor ax, ax 
 mov es, ax
		
		call setCursor
		mov byte [bp - 2], 0x6F ; Default color, white on orange.
		
		cmp cl, [cursor] 
 jne .printIndent ; Is this the selected item? If not, skip.
		cmp byte [es:di], 05h 
 jne .blueBg ; Is this a bootable item type? If it is, set the bg to blue.
		mov byte [bp - 2], 0x4F             ; Unbootable selected color, white on red.
		jmp .printIndent
		
		.blueBg:
		mov byte [bp - 2], 0x1F             ; Bootable selected color, white on blue.		
		
		.printIndent:
		cmp byte [bp - 1], 0 ; Listing primary partitions?
		je .printTypeName
		
		PrintColor Constants.string32, [bp - 2]
		
		.printTypeName:		
		mov al, [es:di] ; Partition type
		cmp al, 05h 
 jne .printTypeName2
		mov byte [bp - 1], 1
		
		.printTypeName2:
		call getPartitionTypeName
		mov al, [bp - 2] 
 call printColorStr
				
		PrintColor Constants.string33, [bp - 2]	
		
		
			push dx 
 push di
			
			mov ax, [es:di + 5]
			mov dx, [es:di + 7]
			mov bx, 2048 
 div bx
			
			mov si, partitionSizeStrBuff
			mov es, [bp - 4] ; Set ES to DS
			mov di, si
			call decNumToStr
			
			mov al, [bp - 2]
			call printColorStr
			
			pop di 
 pop dx
		
		
		PrintColor Constants.string34, [bp - 2]
		
		add di, 9
		inc dh
		inc cx
	cmp cl, [partitionMapSize] 
 jne .drawPartition

	pop es
	mov sp, bp
	pop bp
ret 

; DBG_RegDump: {
;	; IP      [BP + 2] 
;	push bp ; [BP + 0]
;	mov bp, sp
;	push ax ; [BP - 2]
;	push bx
;	push cx
;	push dx
;	push si
;	push di
;	push cs
;	push ds
;	push es
;	push ss
;	Print(Constants.string35) | PrintHexNum [bp - 2]
;	Print(Constants.string36) | PrintHexNum [bp - 4]
;	Print(Constants.string37) | PrintHexNum [bp - 6]
;	Print(Constants.string38) | PrintHexNum [bp - 8]
;	
;	Print(Constants.string39)
;	lea ax, [bp + 4]
;	call printHexNumber
;	Print(Constants.string40) | PrintHexNum [bp - 0]
;	Print(Constants.string41) | PrintHexNum [bp - 10]
;	Print(Constants.string42) | PrintHexNum [bp - 12]
;	
;	Print(Constants.string43) | PrintHexNum [bp - 14]
;	Print(Constants.string44) | PrintHexNum [bp - 16]
;	Print(Constants.string45) | PrintHexNum [bp - 18]
;	Print(Constants.string46) | PrintHexNum [bp - 20]
;	
;	add sp, 4 * 2
;	pop di
;	pop si
;	pop dx
;	pop cx
;	pop bx
;	pop ax
;	mov sp, bp
;	pop bp
; ret }

; %include 'ext/dbg_printhex.asm'
; %include 'ext/dbg_clearstack.asm'	
	
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
	
getPartitionTypeName: 
	push bx
	
	mov bl, al
	xor bh, bh
	mov bl, [PartitionTypeNamePtrIndexArr + bx]	
	add bx, bx
	mov si, [PartitionTypeNamePtrArr + bx]
	
	pop bx
ret 
	
drawSquare: 
	push bp
	mov bp, sp
	push ax
	
	xor ch, ch
	
	; Top box row
	mov dx, bx
	call setCursor
	
	Putch(0xC9)
	Putnch 0xCD, [bp - 1]
	Putch(0xBB)
	
	; Left box column
	mov dx, bx	
	mov al, 0xBA
	
	mov cl, [bp - 2]
	.leftC:
		inc dh
		call setCursor	
		call putch
	loop .leftC
	
	inc dh
	call setCursor	
	
	; Bottom box row
	Putch(0xC8)
	Putnch 0xCD, [bp - 1]
	Putch(0xBC)
	
	; Right box row
	mov dx, bx
	add dl, [bp - 1]
	inc dl
	mov al, 0xBA
	mov cl, [bp - 2]
	.rightC:
		inc dh
		call setCursor	
		call putch
	loop .rightC	
	
	mov sp, bp
	pop bp
ret 

clearRect: 
	push bp
	mov bp, sp
	push ax 
 push bx 
 push cx 
 push dx
	
	mov ax, 0600h    ; AH = Scroll up, AL = Clear
	mov bh, [bp + 4] ; Foreground / Background
	mov cx, [bp + 8] ; Origin
	mov dx, [bp + 6] ; Destination
	int 10h
		
	pop dx 
 pop cx 
 pop bx 
 pop ax
	pop bp
	pop ax
	add sp, 6
jmp ax 

clearScreen:
	xor ax, ax           
 push ax
	mov ax, 18_27h       
 push ax
	mov ax, 0b0_110_1111 
 push ax
	call clearRect
ret
		
%include 'ext/stdconio.asm'
%include 'ext/pushall_popall8086.asm'

DivisionErrorHandler: 
	push bp
	mov bp, sp
	push ax 
 push bx 
 push cx 
 push dx
	push si 
 push di
	
	Print(Constants.string47)
	Print(Constants.string48)
	PrintHexNum [bp + 4]
	Print(Constants.string49)
	PrintHexNum [bp + 2]
	Print(Constants.string50) 
 PrintHexNum [bp - 2]
	Print(Constants.string51) 
 PrintHexNum [bp - 4]
	Print(Constants.string52) 
 PrintHexNum [bp - 6]
	Print(Constants.string53) 
 PrintHexNum [bp - 8]
	Print(Constants.string54)
	lea ax, [bp + 8]
	call printHexNumber
	Print(Constants.string55) 
 PrintHexNum [bp - 0]
	Print(Constants.string56) 
 PrintHexNum [bp - 10]
	Print(Constants.string57) 
 PrintHexNum [bp - 12]
	Print(Constants.string58)
	jmp $


lbaDAPS:  db 16       ; Size
	      db 0x00     ; Always 0
	      dw 0x0001   ; Sectors to read
		  dw 0x2000   ; Destination buffer
	      dw 0x0000   ; Destination segment
	.lba: dd 0x000000 ; Lower LBA
	      dd 0x000000 ; Upper LBA

PartitionTypeNamePtrIndexArr:
	db 0, 1, 1, 1, 1, 5, 2, 1
	db 1, 1, 1, 3, 1, 1, 1, 1
	db 1, 1, 1, 1, 1, 1, 1, 1
	db 1, 1, 1, 1, 1, 1, 1, 1
	db 1, 1, 1, 1, 1, 1, 1, 1
	db 1, 1, 1, 1, 1, 1, 1, 1
	db 1, 1, 1, 1, 1, 1, 1, 1
	db 1, 1, 1, 1, 1, 1, 1, 1
	db 1, 1, 1, 1, 1, 1, 1, 1
	db 1, 1, 1, 1, 1, 1, 1, 1
	db 1, 1, 1, 1, 1, 1, 1, 1
	db 1, 1, 1, 1, 1, 1, 1, 1
	db 1, 1, 1, 1, 1, 1, 1, 1
	db 1, 1, 1, 1, 1, 1, 1, 1
	db 1, 1, 1, 1, 1, 1, 1, 1
	db 1, 1, 1, 1, 1, 1, 1, 1
	db 1, 1, 1, 4, 1, 1, 1, 1
	db 1, 1, 1, 1, 1, 1, 1, 1
	db 1, 1, 1, 1, 1, 1, 1, 1
	db 1, 1, 1, 1, 1, 1, 1, 1
	db 1, 1, 1, 1, 1, 1, 1, 1
	db 1, 1, 1, 1, 1, 1, 1, 1
	db 1, 1, 1, 1, 1, 1, 1, 1
	db 1, 1, 1, 1, 1, 1, 1, 1
	db 1, 1, 1, 1, 1, 1, 1, 1
	db 1, 1, 1, 1, 1, 1, 1, 1
	db 1, 1, 1, 1, 1, 1, 1, 1
	db 1, 1, 1, 1, 1, 1, 1, 1
	db 1, 1, 1, 1, 1, 1, 1, 1
	db 1, 1, 1, 1, 1, 1, 1, 1
	db 1, 1, 1, 1, 1, 1, 1, 1
	db 1, 1, 1, 1, 1, 1, 1, 1

PartitionTypeNamePtrArr:
	dw Constants.string59
	dw Constants.string60
	dw Constants.string61
	dw Constants.string62
	dw Constants.string63
	dw Constants.string64

Constants:
	.string1: db "", 0Dh, 0Ah, "", 0Ah, "--- Xt Generic Boot Manager ---", 0
	.string2: db "", 0Dh, 0Ah, "Version: 0.37.2", 0Dh, 0Ah, "", 0
	.string3: db "", 0Dh, 0Ah, "Press any key to read the partition map.", 0
	.string4: db "", 0Dh, 0Ah, "Partition map read.", 0
	.string5: db "", 0Dh, 0Ah, "Press any key to enter boot select...", 0Dh, 0Ah, "", 0
	.string6: db "Partitions on drive 0x", 0
	.string7: db "", 0Dh, 0Ah, "", 0Dh, 0Ah, " You can't boot an extended partition.", 0
	.string8: db "", 0Dh, 0Ah, "", 0Dh, 0Ah, " Booting...", 0
	.string9: db "", 0Dh, 0Ah, "Reading 0x", 0
	.string10: db ". ", 0
	.string11: db "(", 0
	.string12: db "h, ", 0
	.string13: db "h, ", 0
	.string14: db "h)", 0
	.string15: db "", 0Dh, 0Ah, "Sector read failed. The error was:", 0Dh, 0Ah, " ", 0
	.string16: db "Unknown", 0
	.string17: db "CHS (Cylinder) address out of range", 0
	.string18: db ".", 0Dh, 0Ah, "Ignoring the partitions at this sector.", 0
	.string19: db "", 0Dh, 0Ah, "Current video mode: 0x", 0
	.string20: db "", 0Dh, 0Ah, "Columns: ", 0
	.string21: db "", 0Dh, 0Ah, "Figuring out drive properties...", 0Dh, 0Ah, "", 0
	.string22: db "", 0Dh, 0Ah, "[ Drive geometry as CHS (AH = 02h) ]", 0
	.string23: db "", 0Dh, 0Ah, " Bytes per Sector: ", 0
	.string24: db "", 0Dh, 0Ah, " Sectors per Track: ", 0
	.string25: db "", 0Dh, 0Ah, " Heads Per Cylinder: ", 0
	.string26: db "", 0Dh, 0Ah, " HPC * SPT: ", 0
	.string27: db "", 0Dh, 0Ah, " Cylinders: ", 0
	.string28: db "", 0Dh, 0Ah, "[ Drive geometry as LBA (AH = 48h) ]", 0
	.string29: db "", 0Dh, 0Ah, " Error: BIOS doesn't support LBA.", 0
	.string30: db "", 0Dh, 0Ah, " Error: Drive doesn't support LBA.", 0
	.string31: db "", 0Dh, 0Ah, " Bytes per Sector: ", 0
	.string32: db " ", 0
	.string33: db " (", 0
	.string34: db " MiB)", 0
	.string35: db "", 0Dh, 0Ah, "AX: 0x", 0
	.string36: db " BX: 0x", 0
	.string37: db " CX: 0x", 0
	.string38: db " DX: 0x", 0
	.string39: db "", 0Dh, 0Ah, "SP: 0x", 0
	.string40: db " BP: 0x", 0
	.string41: db " SI: 0x", 0
	.string42: db " DI: 0x", 0
	.string43: db "", 0Dh, 0Ah, "CS: 0x", 0
	.string44: db " DS: 0x", 0
	.string45: db " ES: 0x", 0
	.string46: db " SS: 0x", 0
	.string47: db "", 0Dh, 0Ah, "Division overflow or division by zero.", 0Dh, "", 0
	.string48: db "", 0Dh, 0Ah, "Error occurred at: ", 0
	.string49: db "h:", 0
	.string50: db "h", 0Dh, 0Ah, "AX: 0x", 0
	.string51: db " BX: 0x", 0
	.string52: db " CX: 0x", 0
	.string53: db " DX: 0x", 0
	.string54: db "", 0Dh, 0Ah, "SP: 0x", 0
	.string55: db " BP: 0x", 0
	.string56: db " SI: 0x", 0
	.string57: db " DI: 0x", 0
	.string58: db "", 0Dh, 0Ah, "System halted.", 0
	.string59: db "Empty", 0
	.string60: db "Unknown", 0
	.string61: db "FAT16B", 0
	.string62: db "FAT32", 0
	.string63: db "Linux", 0
	.string64: db "Extended Partition", 0

times 8*512-($-$$) db 0x90 ; Fill rest of stage 1.5 with no-ops. (For alignment.)

; -- Variable space --
drive: db 0
	.CHS_bytesPerSector:    dw 0
	.CHS_sectorsPerTrack:   db 0
	.CHS_headsPerCylinder:  dw 0
	.CHS_sectorsTimesHeads: dw 0
	.CHS_cylinders:         dw 0	
	.LBA_support:           db 0
	.LBA_bytesPerSector:    dw 0
	.logicalBytesPerSector: dw 0

cursor: dw 0
partitionMapSize: db 0
partitionSizeStrBuff: times 6 db 0
