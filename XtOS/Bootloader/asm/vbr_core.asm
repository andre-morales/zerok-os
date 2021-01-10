[BITS 16]
[CPU 8086]
[ORG 0xA00]

; Author:   André Morales 
; Version:  0.1.2
; Creation: 02/01/2021
; Modified: 05/01/2021

; -- [0x0500 - 0x09FF] Stack
; -- [0x0A00 - 0x15FF] Stage 1.5 (Us)
; -- [0x2000 - 0x21FF] Fat16 Directory
; -- [0x7C00 - 0x7DFF] VBR

db 'Xt'
dw 5

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


Start: 
	xor ax, ax
	mov ds, ax
	mov es, ax
	mov ss, ax
	pop word [BegginingSector]
	pop word [BegginingSector + 2]
	
	mov [drive], dl
	Print(Constants.string1)
	
	call getDriveGeometry
	
	call getBootPartitionProperties
	
	Getch()
	call LoadBootBin
	
	jmp 0x2000


LoadBootBin: 
	mov si, Constants.string2
	call FindFile
	
	mov word [lbaDAPS.buffer], 0x2000
	push word [fileCluster]
	call readClusterChain
ret 


FindFile: 
	push bp
	mov bp, sp

	mov [filePathPtr], si
	mov byte [lookingForFolder], 1
	mov byte [inRootDirectory], 1
	
	mov si, RootDirPtr
	mov di, directorySector
	movsw
	movsw
	
	mov word [lbaDAPS.buffer], 0x2000
	
	; Read first sector of root directory.
	push word [directorySector + 2]
	push word [directorySector + 0]
	call readSector
	
	.ReadDirectory:
	; Copy specific file name from the
	; full path to currentFile
	.GetFileName:
	mov si, [filePathPtr]
	mov di, currentFile

		.l1:
		lodsb
		cmp al, '/' 
 jne .l2
		xor al, al 
 stosb
		jmp .SearchDirectory
		
		.l2:
		stosb
		test al, al 
 jnz .l1
		
		mov byte [lookingForFolder], 0
	
	.SearchDirectory:
	mov [filePathPtr], si ; Save our file path ptr back.
	
	.LoadFileEntries:
	mov si, 0x2000
	
	cmp byte [inRootDirectory], 1 
 je .l3
	mov cx, [DirEntriesPerCluster]
	jmp .LoadFileEntry
	
	.l3:
	mov cx, 16
	
	.LoadFileEntry:
	call TestFATFileEntry
	cmp al, 1 
 je .FileNotFound
	cmp al, 2 
 je FileNotFoundOnDir
	
	; Store cluster number at 0x1A
	mov ax, [si + 0x1A]
	mov [fileCluster], ax
	
	; Were we looking for a folder?
	cmp byte [lookingForFolder], 1 
 je .FoundFolder
	
	Print(Constants.string3)
	jmp .End
	
	.FoundFolder:
	Print(Constants.string4)
	push ax
	call readCluster
		
	mov byte [inRootDirectory], 0
	jmp .ReadDirectory
	
	.FileNotFound:
	add si, 32
	loop .LoadFileEntry
	
	.LoadNextSector:
	Print(Constants.string5)
	cli 
 hlt
	
	; File not present on this sector.
	.End:
	mov sp, bp
	pop bp
ret 

TestFATFileEntry: 
	push si 
 push si
	Print(Constants.string6)
	Print(currentFile)
	pop si
	
	mov al, [si + 0x00]
	D_Putch al
	
	cmp al, 0 
 jne .NotEmpty
	mov al, 2 
 jmp .End

	.NotEmpty:
	xor bx, bx
	.cmpFileName:
		lodsb
		mov ah, [currentFile + bx]
		D_Putch al
		D_Putch ah
		D_Putch ' '
		cmp ah, al 
 je .nxt
		mov al, 1 
 jmp .End
		
		.nxt:
		inc bx
	cmp bx, 11 
 jl .cmpFileName
	
	;mov al, [si + 0x0B]	; File Attribs
	;and al, 0x20
	;xor al, [lookingForFolder]
	;jnz FileTypeMismatch
	
	xor al, al
	
	.End:
	pop si
ret 

FileTypeMismatch: 
	Print(Constants.string7)
	cli 
 hlt


FileNotFoundOnDir: 
	Print(Constants.string8)
	cli 
 hlt


getBootPartitionProperties: 
	Print(Constants.string9)
	
	push ds 
	
	push ds 
 pop es
	mov ax, 0 
 mov ds, ax
	
	mov si, 0x7C00 + 0x0B
	mov di, BPB
	
	xor ah, ah
	
	movsw
	lodsb 
 stosw
	movsw
	lodsb 
 stosw
	movsw
	add si, 3
	movsw
	
	add si, 8
	movsw 
 movsw
	
	add si, 7
	mov cx, 11 
 rep movsb
	xor al, al 
 stosb
	
	mov cx, 8 
 rep movsb
	xor al, al 
 stosb
	
	pop ds	
	
	mov bx, [BegginingSector]
	mov cx, [BegginingSector + 2]
	add bx, [BPB.ReservedLogicalSectors]
	adc cx, 0
	mov [FATPtr], bx
	mov [FATPtr + 2], cx
	
	mov ax, [BPB.LogicalSectorsPerFAT]
	mul word [BPB.FATs]
	add bx, ax
	adc cx, dx
	mov [RootDirPtr], bx
	mov [RootDirPtr + 2], cx	
	
	mov ax, 32
	mul word [BPB.RootDirEntries] 
	mov di, 512
	div di
	
	add bx, ax
	adc cx, 0
	mov [DataAreaPtr], bx
	mov [DataAreaPtr + 2], cx
	
	mov ax, [BPB.BytesPerLogicalSector]
	mul word [BPB.LogicalSectorsPerCluster]
	mov [BytesPerCluster], ax
	mov bx, 32 
 div bx
	mov [DirEntriesPerCluster], ax
	
	Print(Constants.string10)
	Print(BPB.Label)
	Print(Constants.string11)
	PrintHexNum [BegginingSector + 2]
	Putch(':')
	PrintHexNum [BegginingSector]
	
	Print(Constants.string12)
	PrintHexNum [FATPtr + 2]
	Putch(':')
	PrintHexNum [FATPtr]
	
	Print(Constants.string13)
	PrintHexNum [RootDirPtr + 2]
	Putch(':')
	PrintHexNum [RootDirPtr]

	Print(Constants.string14)
	PrintHexNum [DataAreaPtr + 2]
	Putch(':')
	PrintHexNum [DataAreaPtr]
	
	Print(Constants.string15)
	PrintDecNum [BPB.BytesPerLogicalSector] 
	Print(Constants.string16)
	PrintDecNum [BPB.LogicalSectorsPerCluster] 
	Print(Constants.string17)
	PrintDecNum [BytesPerCluster] 
	Print(Constants.string18)
	PrintDecNum [BPB.LogicalSectorsPerFAT] 
	Print(Constants.string19)
	PrintDecNum [BPB.FATs]
	Print(Constants.string20)
	PrintDecNum [BPB.RootDirEntries] 
	Print(Constants.string21)
	PrintDecNum [DirEntriesPerCluster] 
ret 

getDriveGeometry: 
	call getDriveCHSProperties
	call getDriveLBAProperties

	Print(Constants.string22)
	xor ah, ah
	mov al, [drive]
	call printHexNumber
	Print(Constants.string23)
	
	Print(Constants.string24)
	Print(Constants.string25)
	PrintDecNum [drive.CHS_bytesPerSector]
	
	Print(Constants.string26)
	xor ah, ah
	mov al, [drive.CHS_sectorsPerTrack]
	call printDecNumber

	Print(Constants.string27)
	PrintDecNum [drive.CHS_headsPerCylinder]
	
	Print(Constants.string28)
	PrintDecNum [drive.CHS_cylinders]
	
	Print(Constants.string29)
	
	mov al, [drive.LBA_support]
	test al, al 
 jz .printLBAProps
	cmp al, 1   
 je .noDriveLBA
	Print(Constants.string30)
	jmp .End
	
	.noDriveLBA:
	Print(Constants.string31)
	jmp .End
	
	.printLBAProps:
	Print(Constants.string32)
	PrintDecNum [drive.LBA_bytesPerSector]
	
	.End:
ret 

; void (int LBA)
readSector: 
	push bp
	mov bp, sp
	sub sp, 4
	
	push es 
 push di
	push si
	push cx 
 push dx
	
	Print(Constants.string33)
	PrintHexNum [bp + 6]
	Putch(' ')
	PrintHexNum [bp + 4]
	
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
		Print(Constants.string34)
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
		
		Print(Constants.string35)
		xor ah, ah
		mov al, [bp - 4]
		call printHexNumber
		
		Print(Constants.string36)
		xor ah, ah
		mov al, [bp - 3]
		call printHexNumber
		Print(Constants.string37)
		
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

; void (short cluster)
readCluster: 
	push bp
	mov bp, sp
	
	Print(Constants.string38)
	PrintHexNum [bp + 4]
	
	mov ax, [bp + 4]
	sub ax, 2
	mul word [BPB.LogicalSectorsPerCluster]

	add ax, [DataAreaPtr]
	adc dx, [DataAreaPtr + 2]
	
	mov cx, [BPB.LogicalSectorsPerCluster]
	push word [lbaDAPS.buffer]
	.readSector:
		push ax
		
		push dx 
 push ax
		call readSector
		
		pop ax
		
		add ax, 1
		adc dx, 0
		add word [lbaDAPS.buffer], 0x200
	loop .readSector
	pop word [lbaDAPS.buffer]
	
	mov sp, bp
	pop bp
	
	pop bx
	add sp, 2
jmp bx

; void (short cluster)
readClusterChain: 
	push bp
	mov bp, sp
	sub sp, 2
	
	push word [lbaDAPS.buffer]
	push word [bp + 4] 
 pop word [bp - 2]
	
	.readCluster:
	push word [bp - 2]
	call readCluster
		
	mov ax, [BytesPerCluster]
	add [lbaDAPS.buffer], ax
	
	xor dx, dx
	mov ax, [bp - 2]
	mov cx, 256 
 div cx
	
	xor dx, dx
	add ax, [FATPtr]
	adc dx, [FATPtr + 2]
	
	push word [lbaDAPS.buffer]
	mov word [lbaDAPS.buffer], fatClusterMapBuffer
	push dx 
 push ax
	call readSector
	pop word [lbaDAPS.buffer]
	
	mov ax, 2
	mul word [bp - 2]
	mov di, ax
	mov ax, [fatClusterMapBuffer + di]
	
	mov [bp - 2], ax
	
	Print(Constants.string39)
	PrintHexNum ax
	Print(Constants.string40)
	PrintHexNum di
	Print(Constants.string41)
	PrintHexNum fatClusterMapBuffer
	Print(Constants.string42)
	PrintHexNum [lbaDAPS.buffer]
	
	cmp word [bp - 2], 0xFFFF 
 je .end

	jmp .readCluster
	
	.end:
	pop word [lbaDAPS.buffer]
	
	mov sp, bp
	pop bp
	pop bx
	add sp, 2
jmp bx 

; -- #include ext/stdconio.csm
; Author:   André Morales 
; Version:  2.0
; Creation: 05/10/2020
; Modified:
; @ 25/10/2020
; @ 04/01/2021

printStr: 
	push ax 
 push bx	
	
	.char:
		lodsb
		test al, al 
 jz .end
		
		 
		xor bh, bh  ; Page 0
		mov ah, 0Eh 
 int 10h ; Print character
	jmp .char
		
	.end:
	pop bx 
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

getch: 
	xor ah, ah 
 int 16h
ret 
;
;pause:
;	push ax
;	call getch
;	pop ax
;ret	
;
;putnch: 	
;	push cx
;	
;	.print:
;		call putch
;	loop .print
;	
;	pop cx
;ret
;

;	
;printColorStr:
;	push ax
;	push bx
;	push cx
;	push dx
;	
;	; Save color
;	xor bh, bh
;	mov bl, al
;	push bx
;	
;	; Get cursor position
;	mov ah, 03h
;	xor bh, bh
;	int 10h
;
;	pop bx ; Get color back
;	
;	.char:
;		lodsb
;		test al, al
;		jz .end
;		
;		cmp al, NL
;		je .putraw
;		cmp al, CR
;		je .putraw
;		
;		; Print only at cursor position with color
;		mov ah, 09h
;		mov cx, 1
;		int 10h
;		
;		; Set cursor position
;		inc dl ; Increase X
;		mov ah, 02h
;		int 10h
;	jmp .char
;	
;	.putraw:
;		; Teletype output
;		mov ah, 0Eh
;		int 10h
;		
;		; Get cursor position
;		mov ah, 03h
;		int 10h
;	jmp .char
;	
;	.end:
;	pop dx
;	pop cx
;	pop bx
;	pop ax
;ret	
;	
;getCursor:
;	push ax
;	push bx
;	push cx
;	
;	mov ah, 03h
;	xor bh, bh
;	int 10h
;	
;	pop cx
;	pop bx
;	pop ax
;ret
;
;setCursor:
;	push ax
;	push bx
;	push cx
;	push dx 
;	
;	mov ah, 02h ; Set cursor position
;	xor bh, bh
;	int 10h
;	
;	pop dx
;	pop cx
;	pop bx
;	pop ax
;ret
;
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

Constants:
	.string1: db "", 0Dh, 0Ah, "         XtOS Bootloader v0.1.0", 0
	.string2: db "XTOS       /XTLOADERBIN", 0
	.string3: db "", 0Dh, 0Ah, "Found file.", 0
	.string4: db "", 0Dh, 0Ah, "Found folder.", 0
	.string5: db "LNS.", 0
	.string6: db "", 0Dh, 0Ah, "Looking for ", 0
	.string7: db "", 0Dh, 0Ah, "File type mismatch.", 0
	.string8: db "", 0Dh, 0Ah, "File not found on directory.", 0
	.string9: db "", 0Dh, 0Ah, "--- [Boot partition properties] ---", 0
	.string10: db "", 0Dh, 0Ah, "Label: ", 0
	.string11: db "", 0Dh, 0Ah, "Beggining: 0x", 0
	.string12: db "", 0Dh, 0Ah, "FAT: 0x", 0
	.string13: db "", 0Dh, 0Ah, "Root Dir: 0x", 0
	.string14: db "", 0Dh, 0Ah, "Data Area: 0x", 0
	.string15: db "", 0Dh, 0Ah, "Bytes per Logical Sector: ", 0
	.string16: db "", 0Dh, 0Ah, "Logical Sectors per Cluster: ", 0
	.string17: db "", 0Dh, 0Ah, "Bytes per Cluster: ", 0
	.string18: db "", 0Dh, 0Ah, "Logical Sectors per FAT: ", 0
	.string19: db "", 0Dh, 0Ah, "FATs: ", 0
	.string20: db "", 0Dh, 0Ah, "Root directory entries: ", 0
	.string21: db "", 0Dh, 0Ah, "Directory entries per cluster: ", 0
	.string22: db "", 0Dh, 0Ah, "--- [Geometries of drive: ", 0
	.string23: db "] ---", 0
	.string24: db "", 0Dh, 0Ah, "CHS (AH = 02h)", 0
	.string25: db "", 0Dh, 0Ah, "  Bytes per Sector: ", 0
	.string26: db "", 0Dh, 0Ah, "  Sectors per Track: ", 0
	.string27: db "", 0Dh, 0Ah, "  Heads Per Cylinder: ", 0
	.string28: db "", 0Dh, 0Ah, "  Cylinders: ", 0
	.string29: db "", 0Dh, 0Ah, "LBA (AH = 48h)", 0
	.string30: db "", 0Dh, 0Ah, "  The BIOS doesn't support LBA.", 0
	.string31: db "", 0Dh, 0Ah, "  The drive doesn't support LBA.", 0
	.string32: db "", 0Dh, 0Ah, "  Bytes per Sector: ", 0
	.string33: db "", 0Dh, 0Ah, "Sector 0x", 0
	.string34: db "(", 0
	.string35: db "h, ", 0
	.string36: db "h, ", 0
	.string37: db "h)", 0
	.string38: db "", 0Dh, 0Ah, "Cluster 0x", 0
	.string39: db "", 0Dh, 0Ah, "NCL 0x", 0
	.string40: db "", 0Dh, 0Ah, "PCL 0x", 0
	.string41: db "", 0Dh, 0Ah, "CMB 0x", 0
	.string42: db "", 0Dh, 0Ah, "DAPS 0x", 0

times (512 * 5)-($-$$) db 0x90 ; Round to 1kb.

; -- Variable space --

Variables:
	DirEntriesPerCluster: dw 0
	BytesPerCluster: dw 0
	filePathPtr: dw 0
	directorySector: dd 0
	fileCluster: dw 0
	currentFile: times 12 db 0
	lookingForFolder: db 0
	inRootDirectory: db 0
	fatClusterMapBuffer: times 512 db 0

BegginingSector: dd 0

FATPtr: dd 0
RootDirPtr: dd 0
DataAreaPtr: dd 0

BPB:
	.BytesPerLogicalSector: dw 0x0000
	.LogicalSectorsPerCluster: dw 0x00
	.ReservedLogicalSectors: dw 0x0000
	.FATs: dw 0x0000
	.RootDirEntries: dw 0x0000
	.LogicalSectorsPerFAT: dw 0x0000
	.LTotalLogicalSectors: dd 0x00000000
	.Label: times 12 db 0x00
	.FSType: times 9 db 0x00
	


	
