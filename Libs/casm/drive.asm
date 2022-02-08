/* Drive reading system
   Author:   André Morales 
   Version:  1.08
   Creation: 02/01/2021
   Modified: 05/02/2022 */

var void Drive
	var byte .id	
	var void Drive.CHS
		var short .bytesPerSector
		var byte .sectorsPerTrack
		var short .headsPerCylinder
		var short .sectorsTimesHeads
		var short .cylinders

	var void Drive.LBA
		var bool .available
		var short .bytesPerSector

	var void lbaDAPS
		var byte .size
		var byte .t02
		var short .sectors
		var short Drive.bufferPtr
		var short .t03
		var int Drive.readLBA
		var int .t04

var void Drive.vars_end

Drive.Init: {
	push es
	push ds | pop es
	mov di, lbaDAPS
	xor ax, ax
	mov cx, 8 | rep stosw
	mov byte [lbaDAPS.size], 16
	mov word [lbaDAPS.sectors], 1
	pop es
ret }

Drive.ReadSector: {
	push bp
	mov bp, sp
	
	_clstack()
	farg short sector_l
	farg short sector_h
	lvar short addr_cylinder
	lvar byte addr_sector
	lvar byte addr_head
	sub sp, $stack_vars_size
	
	push es
	push di | push si
	push dx | push cx | push bx | push ax
	
	#ifdef DRIVE_DBG
	Print(."\NSector 0x")
	PrintHexNum [sector_h]
	Putch(' ')
	PrintHexNum [sector_l]
	#endif
	
	cmp byte [Drive.LBA.available], 0
	jnz .LBAtoCHS ; LBA not supported. Try CHS translation.
	
	; -- Reading as LBA --
	mov ax, [$sector_l] | mov [Drive.readLBA + 0], ax
	mov ax, [$sector_h] | mov [Drive.readLBA + 2], ax
	mov dl, [Drive.id]
	mov si, lbaDAPS
	mov ah, 0x42 | int 13h ; Extended read
	xor ax, ax
	jmp .End
	
	; -- Reading as CHS (Convert LBA to CHS) --
	.LBAtoCHS: {		
		; Calculate cylinder
		mov dx, [$sector_h] | mov ax, [$sector_l]    ; Get LBA
		div word [Drive.CHS.sectorsTimesHeads] ; LBA / (HPC * SPT) | DX:AX / (HPC * SPT)
		mov [$addr_cylinder], ax               ; Save Cylinders

		cmp ax, [Drive.CHS.cylinders] | jle .CHSRead ; Is cylinder number safe?
		mov ax, 1 | jmp .End ; Error code 1. Cylinder too big.
		
		.CHSRead:
		; Calculate sector
		mov dx, [$sector_h] | mov ax, [$sector_l]              ; Get LBA
		xor ch, ch | mov cl, [Drive.CHS.sectorsPerTrack] 
		div cx                                           ; LBA % SPT + 1 | LBA % CX + 1
		inc dx
		mov [$addr_sector], dl
		
		; Calculate head
		xor dx, dx
		div word [Drive.CHS.headsPerCylinder] ; (LBA / SPT) % HPC # (LBA / CX) % HPC
		mov [$addr_head], dl
		
		; Cylinder
		mov ax, [$addr_cylinder]
		mov cl, 8 | rol ax, cl
		mov cl, 6 | shl al, cl 
		mov cx, ax
		
		or cl, [$addr_sector] ; Sector
		mov dh, [$addr_head]  ; Head
		
		xor bx, bx | mov es, bx
		mov bx, [Drive.bufferPtr]
		mov dl, [Drive.id]
		mov al, 1
		mov ah, 0x02 | int 13h ; CHS read
		
		xor ax, ax
	}
	
	.End:
	pop ax | pop bx | pop cx | pop dx
	pop si | pop di
	pop es
	
	mov sp, bp
	pop bp
	
ret $stack_args_size }

Drive.CHS.GetProperties: {
	push es
	
	mov word [Drive.CHS.bytesPerSector], 512
	
	mov dl, [Drive.id]
	mov ah, 08h | int 13h ; Query drive geometry
	
	inc dh
	xor ah, ah | mov al, dh
	mov [Drive.CHS.headsPerCylinder], ax
	
	mov ax, cx
	and al, 00111111b
	mov [Drive.CHS.sectorsPerTrack], al
	
	mul dh
	mov [Drive.CHS.sectorsTimesHeads], ax
	
	mov ax, cx ; LLLLLLLL|HHxxxxxx
	
	mov cl, 8
	rol ax, cl ; HHxxxxxx|LLLLLLLL
	
	mov cl, 6
	shr ah, cl ; ------HH|LLLLLLLL
	inc ax
	mov [Drive.CHS.cylinders], ax
	
	pop es
ret }

Drive.LBA.GetProperties: {
	mov dl, [Drive.id]
	
	mov bx, 0x55AA
	mov ah, 41h | int 13h ; LBA available?
	
	jc .NoDriveLBA
	
	cmp bx, 0xAA55 | jne .NoBiosLBA
	
	push ds                ; Save DS
	mov ax, 0 | mov ds, ax ; Set DS to 0
	mov si, 0x2000         ; Load table to [0x0000:2000h]
	mov word [si], 1Ah     ; Set buffer size
	mov ah, 48h | int 13h  ; Query extended drive parameters.
		
	mov ax, [si + 0x18]                     ; Get bytes/sector
	pop ds                                  ; Get DS back
	mov byte [Drive.LBA.available], 0       ; LBA is supported
	mov word [Drive.LBA.bytesPerSector], ax ; Save bytes/sector
	jmp .End
	
	.NoDriveLBA:
	mov byte [Drive.LBA.available], 1
	jmp .End
	
	.NoBiosLBA:
	mov byte [Drive.LBA.available], 2
	
	.End:
ret }