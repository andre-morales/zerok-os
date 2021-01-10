[BITS 16]
[CPU 8086]

; Author:   André Morales 
; Version:  1.0
; Creation: 07/10/2020
; Modified:
; @ 31/10/2020
; @ 05/01/2021

%define STACK_ADDRESS 0xA00
%define PARTITION_ARRAY 0x1B00

; -- [0x500 - 0xA00] Stack
; -- [0xA00 - 0x1A00] Loaded stage 1.5
; -- [0x1A00 - 0x1B00] Unitialiazed varible storage
; -- [0x1B00 - 0x1C00] Partition array
; -- [0x2000] Generic stuff buffer
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
%include "ext/enter_leave_h.asm"

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
	mov word [lbaDAPS.buffer], 0x2000
	call ReadPartitionMap
	
	Print(Constants.string4)
	mov ax, di
	sub ax, PARTITION_ARRAY
	
	mov cl, 10 
 div cl
	mov [partitionMapSize], al
	
	Print(Constants.string5)
	Pause()
	
MenuStart:	
	mov word [cursor], 0
	
	MainMenu:
		ClearScreen(0b0_110_1111)
		mov bx, 00_00h
		mov ax, 25_17h
		call drawSquare
	
		mov dx, 00_02h 
 call setCursor
		
		Print(Constants.string6)
		
		xor ah, ah 
 mov al, [drive]
		call printHexNumber
		Print(Constants.string7)
	
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
			mov al, 10 
 mul byte [cursor]
			mov di, ax
			add di, PARTITION_ARRAY
			
			cmp byte [es:di + 0], 05h 
 jne .L4
			Print(Constants.string8)
			jmp BackToMainMenu
			
			.L4: 	
				push di
				
				; Fill 0x7C00 with no-ops.
				mov di, 0x7C00
				mov al, 90h
				mov cx, 512
				rep stosb
				
				; Copy the boot failure handler after the boot sector. If control gets there, this handles it.
				mov si, BootFailureHandler
				mov cx, 16
				rep movsw
			
				pop di
			
						
			Print(Constants.string9)
			push word [es:di + 4] 
 push word [es:di + 2] 
			mov word [lbaDAPS.buffer], 0x7C00
			call readSector						
			
			cmp word [es:0x7DFE], 0xAA55 
 jne .notBootable
			Print(Constants.string10)	
			Pause()
			jmp .chain		
			
			.notBootable:
			Print(Constants.string11)	
			Getch()	
			cmp ah, 15h 
 jne BackToMainMenu.clear
			
			.chain:
			ClearScreen(0b0_000_0111)
			
			mov dl, [drive]
			jmp 0x0000:0x7C00	
		
		BackToMainMenu:
			Pause()
			.clear:
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
	
	Print(Constants.string12)
	PrintHexNum [bp + 6]
	Putch(' ')
	PrintHexNum [bp + 4]
	Print(Constants.string13)
	
	cmp byte [drive.LBA_support], 0
	jnz .LBAtoCHS ; LBA not supported. Try CHS translation.
	
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
		Print(Constants.string14)
		call printHexNumber
		
		cmp ax, [drive.CHS_cylinders] 
 jle .CHSRead ; Is cylinder number safe?
		
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
		
		Print(Constants.string15)
		xor ah, ah
		mov al, [bp - 4]
		call printHexNumber
		
		Print(Constants.string16)
		xor ah, ah
		mov al, [bp - 3]
		call printHexNumber
		Print(Constants.string17)
		
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

; void (ES:DI pntrToPartitionArray)
ReadPartitionMap: 
	push bp
	mov bp, sp
	push ds

	; Read MBR
	xor ax, ax
	push ax 
 push ax
	call readSector
	test ax, ax 
 je .ReadTable ; Did it read properly?
	
	; AX is not 0. It failed somehow.
	Print(Constants.string18)
	cmp ax, 1 
 je .OutOfRangeCHS
	Print(Constants.string19)
	jmp .ErrorOut
	
	.OutOfRangeCHS:
	Print(Constants.string20)
	
	.ErrorOut:
	Print(Constants.string21)
	jmp .End
	
	.ReadTable: 	
		
			; Iterate partition table backwards. Since we'll push to the stack and pop the entries later, the 
			; order will be corrected. We need to save the entries to the stack because we are reading from the
			; temporary buffer [0x2000], reading another sector will override this area.
			xor bx, bx
			mov ds, bx
			mov si, 0x2000 + 0x1BE + 48 
			mov cx, 4
			.SavePartitionEntries:
				mov al, [ds:si + 4] ; Get partition type
				test al, al 
 jnz .storeEntry ; Is entry empty?
				jmp .endlspe
				
				.storeEntry:			
				; Save total sector count
				push word [ds:si + 14] ; High
				push word [ds:si + 12] ; Low
				
				; Save starting LBA to stack
				push word [ds:si + 10] ; High
				push word [ds:si + 8]  ; Low
				xor ah, ah 
 push ax  ; Store the partition type followed by 0 (primary partition)
				inc bx
			
				.endlspe:
				sub si, 16
			loop .SavePartitionEntries
		
		
		
			mov ds, [bp - 2]
			mov cx, bx
			.LoadPartitionEntries:
				; Get and store partition type to ES:DI and keep it on BL
				pop ax 
 stosw
				mov bl, al
				
				; Get and store LBA to ES:DI.
				pop ax 
 stosw ; Low  [DI - 8]
				pop ax 
 stosw ; High [DI - 6]
				
				; Get and store total sectors.
				pop ax 
 stosw ; Low  [DI - 4]
				pop ax 
 stosw ; High [DI - 2]
				
				cmp bl, 05h 
 jne .endllpe ; Is it and extended partition?
				mov dx, [es:di - 6]
				mov ax, [es:di - 8]
				mov [extendedPartitionLBA], ax
				mov [extendedPartitionLBA + 2], dx
				call ExploreExtendedPartitionChain
				.endllpe:
			loop .LoadPartitionEntries
		
	
	
	.End:
	mov sp, bp
	pop bp
ret 

ExploreExtendedPartitionChain: 
	push bp
	mov bp, sp
	push ax ; [BP - 2]
	push dx ; [BP - 4]
	push ds ; [BP - 6]
	push es ; [BP - 8]
	push cx ; [BP - 10]
	
	push dx 
 push ax
	call readSector
	
	
		xor ax, ax 
 mov ds, ax
		mov si, 0x2000 + 0x1BE
		; -- Read first partition entry --
		add si, 4
		lodsb             ; Get partition type
		mov ah, 1 
 stosw ; Store partition type followed by 1 (logical partition)
		
		add si, 3
		lodsw
		add ax, word [bp - 2]
		stosw
		
		lodsw
		adc ax, word [bp - 4]
		stosw
		
		movsw
		movsw
		
		; -- Read second partition entry --
		add si, 4
		lodsb
		cmp al, 05h 
 jne .End ; Is there a link to the next logical partition?
		
		
			mov es, [bp - 6] ; Put old DS (0xA0) into ES
			add si, 3
			lodsw
			add ax, word [es:extendedPartitionLBA]
			mov bx, ax
			
			lodsw
			adc ax, word [es:extendedPartitionLBA + 2]
			
			mov dx, ax
			mov ax, bx
			mov ds, [bp - 6]
			mov es, [bp - 8]
			call ExploreExtendedPartitionChain
			
	
	
	.End:
	pop cx
	pop es
	pop ds
	mov sp, bp
	pop bp
ret 

getCurrentVideoMode: 
	mov ah, 0Fh 
 int 10h
	push ax
	Print(Constants.string22)
	xor ah, ah
	call printHexNumber
	
	Print(Constants.string23)
	pop ax
	mov al, ah
	xor ah, ah
	call printDecNumber	
ret 

getDriveGeometry: 
	Print(Constants.string24)
	Print(Constants.string25)
	
	call getDriveCHSProperties
	
	; -- Print CHS properties --
	Print(Constants.string26)
	PrintDecNum [drive.CHS_bytesPerSector]
	
	Print(Constants.string27)
	xor ah, ah
	mov al, [drive.CHS_sectorsPerTrack]
	call printDecNumber

	Print(Constants.string28)
	PrintDecNum [drive.CHS_headsPerCylinder]
	
	Print(Constants.string29)
	PrintDecNum [drive.CHS_sectorsTimesHeads]
	
	Print(Constants.string30)
	PrintDecNum [drive.CHS_cylinders]
	
	Print(Constants.string31)
	call getDriveLBAProperties
	
	mov al, [drive.LBA_support]
	test al, al 
 jz .printLBAProps
	cmp al, 1   
 je .noDriveLBA
	Print(Constants.string32)
	jmp .End
	
	.noDriveLBA:
	Print(Constants.string33)
	jmp .End
	
	.printLBAProps:
	Print(Constants.string34)
	PrintDecNum [drive.LBA_bytesPerSector]
	
	.End:
ret 

DrawMenu: 
	push bp
	mov bp, sp
	sub sp, 4
	mov word [bp - 2], 0
	mov word [bp - 4], 2048
	push ds
	push es
	
	mov dx, 02_02h 
 call setCursor
	
	mov di, PARTITION_ARRAY
	xor cl, cl
	.drawPartition:
		xor ax, ax 
 mov es, ax
		
		call setCursor
		mov bh, ' '  ; (Prefix) = ' '
		mov bl, 0x6F ; (Color) = White on orange.
		cmp cl, [cursor] 
 jne .printIndent ; Is this the selected item? If not, skip.
		
		; Item is selected
		add bh, '>' - ' ' ; Set prefix char to '>'
		cmp byte [es:di], 05h 
 jne .itemBootable ; Is this an extend partition type? If it is, set the bg to blue.
		mov bl, 0x4F                              ; Unbootable item selected color, white on red.
		jmp .printIndent
		
		.itemBootable:
		mov bl, 0x1F ; Bootable item selected color, white on blue.		
		
		; Print and extra indent if listing primary partitions.
		.printIndent:
		cmp byte [es:di + 1], 0 ; Listing primary partitions?
		je .printTypeName
		Putch(' ')
		
		.printTypeName:	
		Putch(bh)		
		mov al, [es:di] ; Partition type
		call getPartitionTypeName
		mov al, bl 
 call printColorStr
				
		PrintColor Constants.string35, bl
		
			push dx 
 push di
			
			mov ax, [es:di + 6]
			mov dx, [es:di + 8]
			div word [bp - 4]
			
			mov si, partitionSizeStrBuff
			mov es, [bp - 6] ; Set ES to DS
			mov di, si
			call decNumToStr
			
			mov al, bl
			call printColorStr
			
			pop di 
 pop dx
		
		
		PrintColor Constants.string36, bl
		
		add di, 10
		inc dh
		inc cx
	cmp cl, [partitionMapSize] 
 jne .drawPartition

	pop es
	mov sp, bp
	pop bp
ret 

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
	mov bh, [bp + 8] ; Foreground / Background
	mov cx, [bp + 6] ; Origin
	mov dx, [bp + 4] ; Destination
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
	push ax
	xor ax, ax           
 push ax
	mov ax, 18_27h       
 push ax
	call clearRect
	
	xor dx, dx
	call setCursor
ret 
		
; -- #include ext/stdconio.csm
; Author:   André Morales 
; Version:  1.9
; Creation: 05/10/2020
; Modified: 25/10/2020

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

getch:
	xor ah, ah
	int 16h
ret

pause:
	push ax
	call getch
	pop ax
ret	

putnch: 	
	push cx
	
	.print:
		call putch
	loop .print
	
	pop cx
ret

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
	
printColorStr:
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
		
		cmp al, NL
		je .putraw
		cmp al, CR
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
ret	
	
getCursor:
	push ax
	push bx
	push cx
	
	mov ah, 03h
	xor bh, bh
	int 10h
	
	pop cx
	pop bx
	pop ax
ret

setCursor:
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
ret

printDecNumber:
	push bp
	mov bp, sp
	sub sp, 6
	push ds
	push es
	push si
	push di
	
	mov di, ss
	mov es, di
	mov ds, di
	
	lea di, [bp - 6]
	call decNumToStr
	
	mov si, di
	call printStr
	
	pop di
	pop si
	pop es
	pop ds
	mov sp, bp
	pop bp
ret
	
decNumToStr:
	push cx
	push dx
	push di
	
	mov cx, 10
	call .printNumber
	
	mov byte [es:di], 0
	
	pop di
	pop dx
	pop cx
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
		stosb
	
		pop dx
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
%include 'ext/pushall_popall.asm'

DivisionErrorHandler: 
	push bp
	mov bp, sp
	push ax 
 push bx 
 push cx 
 push dx
	push si 
 push di
	push ds
	
	push cs 
 pop ds
	Print(Constants.string37)
	Print(Constants.string38)
	PrintHexNum [bp + 4]
	Print(Constants.string39)
	PrintHexNum [bp + 2]
	Print(Constants.string40) 
 PrintHexNum [bp - 2]
	Print(Constants.string41) 
 PrintHexNum [bp - 4]
	Print(Constants.string42) 
 PrintHexNum [bp - 6]
	Print(Constants.string43) 
 PrintHexNum [bp - 8]
	Print(Constants.string44)
	lea ax, [bp + 8]
	call printHexNumber
	Print(Constants.string45) 
 PrintHexNum [bp - 0]
	Print(Constants.string46) 
 PrintHexNum [bp - 10]
	Print(Constants.string47) 
 PrintHexNum [bp - 12]
	Print(Constants.string48)
	cli 
 hlt


BootFailureHandler: 
	jmp 0x00A0:.L1
	
	.L1:
	push cs 
 pop ds
	Print(Constants.string49)
	Pause()
	jmp MenuStart


lbaDAPS:	 db 16       ; Size
			 db 0x00     ; Always 0
			 dw 0x0001   ; Sectors to read
	.buffer: dw 0x2000   ; Destination buffer
			 dw 0x0000   ; Destination segment
	.lba:	 dd 0x000000 ; Lower LBA
			 dd 0x000000 ; Upper LBA

PartitionTypeNamePtrIndexArr:
	db 0, 1, 1, 1, 1, 5, 2, 6
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
	dw Constants.string50
	dw Constants.string51
	dw Constants.string52
	dw Constants.string53
	dw Constants.string54
	dw Constants.string55
	dw Constants.string56
	
Constants:
	.string1: db "", 0Dh, 0Ah, "", 0Ah, "--- Xt Generic Boot Manager ---", 0
	.string2: db "", 0Dh, 0Ah, "Version: 1.0.0", 0Dh, 0Ah, "", 0
	.string3: db "", 0Dh, 0Ah, "Press any key to read the partition map.", 0
	.string4: db "", 0Dh, 0Ah, "Partition map read.", 0
	.string5: db "", 0Dh, 0Ah, "Press any key to enter boot select...", 0Dh, 0Ah, "", 0
	.string6: db "-XtBootMgr v1.0.0 [Drive 0x", 0
	.string7: db "]-", 0
	.string8: db "", 0Dh, 0Ah, "", 0Dh, 0Ah, " You can't boot an extended partition.", 0
	.string9: db "", 0Dh, 0Ah, "", 0Dh, 0Ah, "Reading drive...", 0
	.string10: db "", 0Dh, 0Ah, "Press any key to boot...", 0Dh, 0Ah, "", 0
	.string11: db "", 0Dh, 0Ah, "Boot signature not found.", 0Dh, 0Ah, "Boot anyway [Y/N]?", 0Dh, 0Ah, "", 0
	.string12: db "", 0Dh, 0Ah, "Reading 0x", 0
	.string13: db ". ", 0
	.string14: db "(", 0
	.string15: db "h, ", 0
	.string16: db "h, ", 0
	.string17: db "h)", 0
	.string18: db "", 0Dh, 0Ah, "Sector read failed. The error was:", 0Dh, 0Ah, " ", 0
	.string19: db "Unknown", 0
	.string20: db "CHS (Cylinder) address out of range", 0
	.string21: db ".", 0Dh, 0Ah, "Ignoring the partitions at this sector.", 0
	.string22: db "", 0Dh, 0Ah, "Current video mode: 0x", 0
	.string23: db "", 0Dh, 0Ah, "Columns: ", 0
	.string24: db "", 0Dh, 0Ah, "Figuring out drive properties...", 0Dh, 0Ah, "", 0
	.string25: db "", 0Dh, 0Ah, "[ Drive geometry as CHS (AH = 02h) ]", 0
	.string26: db "", 0Dh, 0Ah, " Bytes per Sector: ", 0
	.string27: db "", 0Dh, 0Ah, " Sectors per Track: ", 0
	.string28: db "", 0Dh, 0Ah, " Heads Per Cylinder: ", 0
	.string29: db "", 0Dh, 0Ah, " HPC * SPT: ", 0
	.string30: db "", 0Dh, 0Ah, " Cylinders: ", 0
	.string31: db "", 0Dh, 0Ah, "[ Drive geometry as LBA (AH = 48h) ]", 0
	.string32: db "", 0Dh, 0Ah, " Error: BIOS doesn't support LBA.", 0
	.string33: db "", 0Dh, 0Ah, " Error: Drive doesn't support LBA.", 0
	.string34: db "", 0Dh, 0Ah, " Bytes per Sector: ", 0
	.string35: db " (", 0
	.string36: db " MiB)", 0
	.string37: db "", 0Dh, 0Ah, "Division overflow or division by zero.", 0Dh, "", 0
	.string38: db "", 0Dh, 0Ah, "Error occurred at: ", 0
	.string39: db "h:", 0
	.string40: db "h", 0Dh, 0Ah, "AX: 0x", 0
	.string41: db " BX: 0x", 0
	.string42: db " CX: 0x", 0
	.string43: db " DX: 0x", 0
	.string44: db "", 0Dh, 0Ah, "SP: 0x", 0
	.string45: db " BP: 0x", 0
	.string46: db " SI: 0x", 0
	.string47: db " DI: 0x", 0
	.string48: db "", 0Dh, 0Ah, "System halted.", 0
	.string49: db "", 0Dh, 0Ah, "XtBootMgr got control back. The bootsector either contains no executable code, or invalid code.", 0Dh, 0Ah, "Going back to the main menu.", 0
	.string50: db "Empty", 0
	.string51: db "Unknown", 0
	.string52: db "FAT16B", 0
	.string53: db "FAT32", 0
	.string54: db "Linux", 0
	.string55: db "Extended Partition", 0
	.string56: db "NTFS", 0

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
extendedPartitionLBA: dd 0
