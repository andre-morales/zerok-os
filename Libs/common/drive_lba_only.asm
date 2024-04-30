/* Drive reading system
   Author:   André Morales 
   Version:  1.08
   Creation: 02/01/2021
   Modified: 05/02/2022 */

var void Drive
	var byte .id	

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
	PrintHexNum word [$sector_h]
	Putch(' ')
	PrintHexNum word [$sector_l]
	#endif
	
	cmp byte [Drive.LBA.available], 0
	jz Halt ; LBA not supported. Try CHS translation.
	
	; -- Reading as LBA --
	mov ax, [$sector_l] | mov [Drive.readLBA + 0], ax
	mov ax, [$sector_h] | mov [Drive.readLBA + 2], ax
	mov dl, [Drive.id]
	mov si, lbaDAPS
	mov ah, 0x42 | int 13h ; Extended read
	xor ax, ax
	jmp .End
	
	.End:
	pop ax | pop bx | pop cx | pop dx
	pop si | pop di
	pop es
	
	mov sp, bp
	pop bp
	
ret $stack_args_size }

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