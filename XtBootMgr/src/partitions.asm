[SECTION .text]
[BITS 16]
[CPU 8086]

; Obtains a descriptive name for a partition type
;
; Inputs: [AL = Partition index byte]
; Outputs: [SI = String pointer]
; Destroys: []
GLOBAL Partitions.GetPartTypeName
Partitions.GetPartTypeName: {
	push bx
	
	mov bl, al
	xor bh, bh
	
	add bx, bx
	mov si, [nameTable + bx]
	
	pop bx
ret }

nameTable: {
	dw ."Empty"						; 0x00
	times 4 dw unknownPart
	dw ."Extended Partition (CHS)"  ; 0x05
	dw ."FAT / RAW" 				; 0x06
	dw ."NTFS"						; 0x07
	times 3 dw unknownPart
	dw ."FAT32"						; 0x0B
	times 2 dw unknownPart
	dw ."FAT(12/16)"				; 0x0E
	dw ."Extended Partition (LBA)"	; 0x0F
	times 240 dw unknownPart
}

[SECTION .rodata]
@rodata:
	unknownPart:
	db "Empty", 0

