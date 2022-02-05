/* FAT16 reading lib
   Author:   André Morales 
   Version:  0.32
   Creation: 02/01/2021
   Modified: 05/02/2022 */

var void FATFS.BPB
var void FATFS
	var short .bytesPerLogicalSector
	var short .logicalSectorsPerCluster
	var short .reservedLogicalSectors
	var short .fats
	var short .rootDirectoryEntries
	var short .logicalSectorsPerFAT
	var short .totalLogicalSectors
	var char[12] .label

	; FAT12 or FAT16?
	var byte .clusterBits

	var int .beginningSct
	var int .fatSct
	var int .rootDirSct
	var int .dataAreaSct

	var short .directoryEntriesPerCluster
	var short .bytesPerCluster

	var char* .filePathPtr
	var int .directorySector
	var short .fileCluster
	var char[12] .currentFile
	var bool .lookingForFolder
	var bool .inRootDirectory
	var byte* .clusterBuffer
	var byte[512] .clusterMapBuffer
var void .vars_end

FATFS.Initialize: {
	push bp
	mov bp, sp
	_clstack()
	
	; Read all important stuff from BPB
	add si, 0x0B
	mov di, FATFS.BPB
	
	xor ah, ah
	
	movsw         ; [0B] Bytes per logical sector
	lodsb | stosw ; [0D] Logical sectors per cluster
	movsw         ; [0E] Reserved logical sectors
	lodsb | stosw ; [10] FATs
	movsw         ; [11] Root Dir. Entries
	
	lodsw         ; [13] Total logical sectors
	
	call .testClusterBits ; Discover type of FAT     
	
	inc si  
	movsw         ; [16] Logical sectors per FAT
	
	; [2B] Volume label
	add si, 0x11
	mov cx, 11 | rep movsb
	xor al, al | stosb
	
	; Sector of First FAT is Beginning + Reserved sectors.
	mov bx, [FATFS.beginningSct]
	mov cx, [FATFS.beginningSct + 2]
	add bx, [FATFS.reservedLogicalSectors]
	adc cx, 0
	mov [FATFS.fatSct], bx
	mov [FATFS.fatSct + 2], cx
	
	; Sector of the Root Directory is the First FAT + Size of a FAT * The amount of FATs
	mov ax, [FATFS.logicalSectorsPerFAT]
	mul word [FATFS.fats]
	add bx, ax
	adc cx, dx
	mov [FATFS.rootDirSct], bx
	mov [FATFS.rootDirSct + 2], cx	
	
	; Size of the Root Directory in sectors is the total
	; amount of root directory entries * size of a directory
	; entry (32 bytes) divided by the size of a sector (512 bytes)
	mov ax, 32
	mul word [FATFS.rootDirectoryEntries] 
	mov di, 512
	div di
	
	; Beginning of Data Area is Root Dir. beginning + Root Dir. size
	add bx, ax
	adc cx, 0
	mov [FATFS.dataAreaSct], bx
	mov [FATFS.dataAreaSct + 2], cx
	
	; Calculate Dir. Entries / Cluster 
	mov ax, [FATFS.bytesPerLogicalSector]
	mul word [FATFS.logicalSectorsPerCluster]
	mov [FATFS.bytesPerCluster], ax
	mov bx, 32 | div bx
	mov [FATFS.directoryEntriesPerCluster], ax
	
	mov sp, bp
	pop bp
ret

	.testClusterBits: {
		test ax, ax | jz Halt ; FAT32. Not supported.
		cmp ax, 4085 | jg .fat16
		mov byte [FATFS.clusterBits], 12
		ret
		
		.fat16:
		mov byte [FATFS.clusterBits], 16
	ret }
}

FATFS.FindFile: {
	push bp
	mov bp, sp

	mov [FATFS.filePathPtr], si
	mov byte [FATFS.lookingForFolder], 1
	mov byte [FATFS.inRootDirectory], 1
	
	mov si, FATFS.rootDirSct
	mov di, FATFS.directorySector
	movsw
	movsw
	
	mov ax, [FATFS.clusterBuffer]
	mov word [Drive.bufferPtr], ax
	
	; Read first sector of root directory.
	push word [FATFS.directorySector + 2]
	push word [FATFS.directorySector + 0]
	call Drive.ReadSector
	
	.ReadDirectory:
	; Copy specific file name from the
	; full path to currentFile
	.GetFileName:
	mov si, [FATFS.filePathPtr]
	mov di, FATFS.currentFile

		.l1:
		lodsb
		cmp al, '/' | jne .l2
		xor al, al | stosb
		jmp .SearchDirectory
		
		.l2:
		stosb
		test al, al | jnz .l1
		
		mov byte [FATFS.lookingForFolder], 0
	
	.SearchDirectory:
	mov [FATFS.filePathPtr], si ; Save our file path ptr back.
	
	.LoadFileEntries:
	mov si, [FATFS.clusterBuffer]
	
	cmp byte [FATFS.inRootDirectory], 1 | je .l3
	mov cx, [FATFS.directoryEntriesPerCluster]
	jmp .LoadFileEntry
	
	.l3:
	mov cx, 16
	
	.LoadFileEntry:
	call FATFS._testFATFileEntry
	cmp al, 1 | je .FileNotFound
	cmp al, 2 | je FileNotFoundOnDir
	
	; Store cluster number at 0x1A
	mov ax, [si + 0x1A]
	mov [FATFS.fileCluster], ax
	
	; Were we looking for a folder?
	cmp byte [FATFS.lookingForFolder], 1 | je .FoundFolder
	
	;Print(."\NFound file.")
	mov ax, [FATFS.fileCluster]
	jmp .End
	
	.FoundFolder:
	;Print(."\NFound folder.")
	push ax
	call FATFS.ReadCluster
		
	mov byte [FATFS.inRootDirectory], 0
	jmp .ReadDirectory
	
	.FileNotFound:
	add si, 32
	loop .LoadFileEntry
	
	.LoadNextSector:
	Print(."LNS.")
	cli | hlt
	
	; File not present on this sector.
	.End:
	mov sp, bp
	pop bp
ret }

/* Compares the string at DS:SI with the current file being searched. */
FATFS._testFATFileEntry: {
	push si
	
	mov al, [si + 0x00]
	
	cmp al, 0 | jne .NotEmpty
	mov al, 2 | jmp .End

	.NotEmpty:
	xor bx, bx
	.cmpFileName:
		lodsb
		mov ah, [FATFS.currentFile + bx]
		cmp ah, al | je .nxt
		mov al, 1 | jmp .End
		
		.nxt:
		inc bx
	cmp bx, 11 | jl .cmpFileName
	
	xor al, al
	
	.End:
	pop si
ret }

; void (short cluster)
FATFS.ReadCluster: {
	push bp
	mov bp, sp
	
	_clstack()
	farg short cluster
	
	push word [Drive.bufferPtr]
	
	mov ax, [$cluster]

	#ifdef FAT16_DEBUG
	Print(."\NReading cluster: ")
	PrintDecNum ax
	#endif
	
	cmp ax, 2
	jg .read
		
	#ifdef FAT16_DEBUG
	Print(."\NInvalid cluster.\N")
	#endif
	jmp Halt
	
	.read:
	dec ax 
	dec ax
	; Calculate beginning sector in the data area.
	mul word [FATFS.logicalSectorsPerCluster]
	
	; Sum offset with beginning of data area
	add ax, [FATFS.dataAreaSct]
	adc dx, [FATFS.dataAreaSct + 2]
	
	mov cx, [FATFS.logicalSectorsPerCluster]
	.readSector:
		push dx | push ax
		call Drive.ReadSector
		
		add ax, 1
		adc dx, 0
		add word [Drive.bufferPtr], 0x200
	loop .readSector
	pop word [Drive.bufferPtr]
	
	mov sp, bp
	pop bp
ret $stack_args_size }


; void (short cluster)
FATFS.ReadClusterChain: {
	push bp
	mov bp, sp

	_clstack()
	farg short cluster
	
	push word [Drive.bufferPtr]              ; Save drive buffer pointer

	cmp byte [FATFS.clusterBits], 12 | je ._readClusterChain12
	cmp byte [FATFS.clusterBits], 16 | je ._readClusterChain16
	
	.end:
	pop word [Drive.bufferPtr]
	
	mov sp, bp
	pop bp
ret $stack_args_size

	._readClusterChain16:
		; Read current cluster
		push word [$cluster]
		call FATFS.ReadCluster
		
		; Increase buffer ptr by cluster size
		mov ax, [FATFS.bytesPerCluster]
		add [Drive.bufferPtr], ax
		
		; Calculate the sector of the FAT we need to load
		xor dx, dx
		mov ax, [$cluster]
		mov cx, 256 | div cx
		
		; Reads a sector of the FAT table
		push ax
		call FATFS._readFATSector
		
		; Calculate the offset into the FAT table and get the next cluster index
		mov di, [$cluster]
		shl di, 1 ; Multiply by 2 because each FAT entry is 2 bytes.
		mov ax, [FATFS.clusterMapBuffer + di]
		
		mov [$cluster], ax
		cmp ax, 0xFFFF | jne ._readClusterChain16
	jmp FATFS.ReadClusterChain.end
		
	._readClusterChain12:
		; Read current cluster
		push word [$cluster]
		call FATFS.ReadCluster
		
		; Increase buffer ptr by cluster size
		mov ax, [FATFS.bytesPerCluster]
		add [Drive.bufferPtr], ax
		
		; Calculate the sector of the FAT we need to load
		xor dx, dx
		mov ax, [$cluster]
		mov cx, 341 | div cx ; TODO - edge case, literally
		
		; Reads a sector of the FAT table
		push ax
		call FATFS._readFATSector
		
		; Calculate the offset into the FAT table and get the next cluster index
		; Current cluster * 3 / 2
		mov ax, [$cluster]
		mov cx, 3
		mul cx
		
		dec cx
		div cx		
		
		; Get the packed cluster number
		mov bx, ax
		mov ax, [FATFS.clusterMapBuffer + bx]
		
		test dl, dl | jnz .oddcluster
		and ah, 0x0F		
		jmp .l2
		
		.oddcluster:
		mov cl, 4
		shr ax, cl
		
		.l2:
		mov [$cluster], ax
		cmp ax, 0xFFF | jne ._readClusterChain12
	jmp FATFS.ReadClusterChain.end
}

FATFS._readFATSector: {
	push bp
	mov bp, sp
	
	_clstack()
	farg short sector
	
	mov ax, [$sector]
	cwd
	
	add ax, [FATFS.fatSct]
	adc dx, [FATFS.fatSct + 2]
	
	mov bx, Drive.bufferPtr
	mov cx, FATFS.clusterMapBuffer
	
	xchg cx, [bx]
	push dx | push ax
	call Drive.ReadSector
	mov [bx], cx
	
	mov sp, bp
	pop bp
ret $stack_args_size}