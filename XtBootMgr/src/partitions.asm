#include <comm/drive.h>
#include <comm/console.h>
#include <comm/console_macros.h>

var long extendedPartitionLBA

GLOBAL Partitions.entriesLength
var short Partitions.entriesLength

GLOBAL Partitions.entries
var long Partitions.entries

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

; Read the entire partition map of the disk. The amount of entries read can be querid trough
; Partitions.entriesLength
;
; Inputs: ES:DI = Pointer to reserved array
; Outputs: .
; Destroys: AX, CX
GLOBAL Partitions.ReadPartitionMap
Partitions.ReadPartitionMap: {
	push bp
	mov bp, sp
	
	; Save important registers
	push ds ; [BP - 2]
	push di ; [BP - 4]

	; Save ES:DI pointer to entries
	mov [Partitions.entries + 0], di
	mov [Partitions.entries + 2], es

	; Read MBR (Sector 0)
	xor ax, ax
	push ax | push ax
	call Drive.ReadSector
	
	; If the disk read was successfull, go read the partition table
	test ax, ax
	je .readTable
	
	; The read failed somehow.
	CONSOLE_PRINT(."\NSector read failed. The error was:\N ")
	
	; Test possible error conditions
	cmp ax, 1
	je .outOfRangeCHS
	
	CONSOLE_PRINT(."Unknown")
	jmp .errorOut
	
	.outOfRangeCHS:
	CONSOLE_PRINT(."CHS (Cylinder) address out of range")
	
	.errorOut:
	CONSOLE_PRINT(.".\NIgnoring the partitions at this sector.")
	jmp .end
	
	.readTable: {
		; Step 1: Read the four partition entries in the MBR
		; Iterate partition table backwards. Since we'll push to the stack and pop the entries later, the 
		; order will be corrected. We need to save the entries to the stack because we are reading from the
		; temporary buffer [0x2000], and reading another sector (such as an EBR) would override this area.	
		{
			; Clear BX and DS (data segment) = 0
			xor bx, bx
			mov ds, bx
			
			; Set SI to the last MBR entry
			mov si, 0x2000 + 0x1BE + 48 
			mov cx, 4
			.processMBREntry:
				; Get partition type
				mov al, [ds:si + 4] 
				
				; If the partition is empty, skip it
				test al, al
				jz .endlspe
				
				; Save total sector count
				push word [ds:si + 14] ; High
				push word [ds:si + 12] ; Low
				
				; Save starting LBA to stack
				push word [ds:si + 10] ; High
				push word [ds:si + 8]  ; Low
				
				; Store the partition type followed by a 0, indicating it is a primary partition
				xor ah, ah
				push ax  
				
				; Increment the amount of primary partitions found
				inc bx
			
				.endlspe:
				sub si, 16
			loop .processMBREntry
		}
		
		; Step 2: Here we pop the primary partitions back.
		; BX contains how many primary partitions were found.
		{
			; Restore original DS
			mov ds, [bp - 2]	
			
			; If no partitions were found, skip the loop
			test bx, bx
			jz .end
			
			; We'll loop of the amount of primary partitions found
			mov cx, bx
			.processEntry:
				; Get and store partition type to ES:DI. Save it on BL
				pop ax
				stosw
				mov bl, al
				
				; Get and store LBA to ES:DI.
				pop ax | stosw ; Low  [DI - 8]
				pop ax | stosw ; High [DI - 6]
				
				; Get and store total sectors.
				pop ax | stosw ; Low  [DI - 4]
				pop ax | stosw ; High [DI - 2]
				
				; Check if the partition is an extended partition (05h / 0Fh)
				cmp bl, 05h | je .isExtended ; CHS type
				cmp bl, 0Fh | je .isExtended ; LBA type
				
				jmp .endllpe
				
				.isExtended:
				; The partition is extended. Save its origin LBA
				mov dx, [es:di - 6]
				mov ax, [es:di - 8]
				mov [extendedPartitionLBA], ax
				mov [extendedPartitionLBA + 2], dx
				
				; Explore the EBR chain
				push cx
				call ExploreExtendedPartitionChain
				pop cx
				
				.endllpe:
			loop .processEntry			
		}
	}
	
	.end:
	; See how much DI advanced to calculate how many entries
	xor dx, dx
	mov ax, di
	sub ax, [bp - 4] ; Original DI
	
	; Each entry is 10 bytes long, divide DX:AX by 10
	mov cx, 10
	div cx
	mov [Partitions.entriesLength], ax

	; Restore registers and leave
	pop di
	pop ds
	
	mov sp, bp
	pop bp
ret }

; Explore the partition chain following a EBR, this function is recursive
;
; Inputs: ES:DI = Current pointer to partition entry array
;         DX:AX = LBA of the EBR
; Destroys: AX, BX, CX, DX, SI
ExploreExtendedPartitionChain: {
	push bp
	mov bp, sp
	
	; Save LBA on the stack
	push ax ; [BP - 2] Low word of the EBR LBA
	push dx ; [BP - 4] High word of the EBR LBA
	
	; Save important registers
	push ds ; [BP - 6]
	push es ; [BP - 8]
	
	; AX:DX is the LBA of the EBR. Read it to 0x2000
	push dx | push ax
	call Drive.ReadSector
	
	; Step 1: Read the first entry of the EBR. It must contain a partition entry.
	{
		; Clear DS
		xor ax, ax
		mov ds, ax
		
		; Point SI to the first entry
		mov si, 0x2000 + 0x1BE
		
		; Set AL to the partition type (4h)
		add si, 4
		lodsb
		
		; Store partition type followed by a 1, indicating it is a logical partition
		mov ah, 1
		stosw
		
		; Read low word of the starting LBA (8h).
		; Add to it the LBA of the extended partition to get the absolute LBA 
		add si, 3
		lodsw
		add ax, word [bp - 2]
		stosw
		
		; Read high word of the starting LBA (Ah). Add the EBR LBA and store it
		lodsw
		adc ax, word [bp - 4]
		stosw
		
		; Read and store the sector count (Ch)
		movsw
		movsw
	}
	
	; Step 2: Read the second entry of the MBR. It either points to another EBR, or it is empty.
	{
		; Set AL to the partition type
		add si, 4
		lodsb
		
		; Check if this entry points to another EBR
		cmp al, 05h
		jne .End
		
		; Put saved DS (0xA0) into ES
		mov es, [bp - 6] 
		
		; Read low starting LBA and add it to the origin of the extended partition
		add si, 3
		lodsw
		add ax, word [es:extendedPartitionLBA]
		mov bx, ax
		
		; Read high starting LBA and add it to the Extended partition origin
		lodsw
		adc ax, word [es:extendedPartitionLBA + 2]
		
		; Restore saved segments
		mov ds, [bp - 6]
		mov es, [bp - 8]
		
		; Set AX:DX to the address of the next EBR in the chain
		mov dx, ax
		mov ax, bx	
		call ExploreExtendedPartitionChain
	}	
	
	.End:
	pop es
	pop ds
	
	mov sp, bp
	pop bp
ret }

[SECTION .rodata]
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

@rodata:
	unknownPart:
	db "Empty", 0

[SECTION .bss]
@bss:
