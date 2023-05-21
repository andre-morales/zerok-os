/* FAT12/16 reading lib
 *
 * Author:   André Morales 
 * Version:  0.4
 * Creation: 02/01/2021
 * Modified: 20/05/2023 */

var void FATFS
	var void .BPB
	var short .bytesPerLogicalSector
	var short .logicalSectorsPerCluster
	var short .reservedLogicalSectors
	var short .fats
	var short .rootDirectoryEntries
	var short .totalLogicalSectors
	var short .logicalSectorsPerFAT
	var char[12] .label

	var short .directoryEntriesPerCluster
	var short .bytesPerCluster
	var short .totalRootDirSectors

	; FAT12 or FAT16?
	var byte .clusterBits
	
	; LBA pointers to sections
	var int .beginningSct
	var int .fatSct
	var int .rootDirSct
	var int .dataAreaSct

	; General state
	var byte* .clusterBuffer
	var short .lastReadFATSector
	
	var byte[512] .clusterMapBuffer
var void .vars_end

FATFS.Initialize: {
	CLSTACK
	farg byte* firstSectorPtr
	ENTERFN
		
	; Read all important stuff from BPB
	mov bx, [$firstSectorPtr]
	lea si, [bx + 0x0B]	
	mov di, FATFS.BPB
	
	xor ah, ah
	movsw         ; [0B] Bytes per logical sector
	lodsb | stosw ; [0D] Logical sectors per cluster
	movsw         ; [0E] Reserved logical sectors
	lodsb | stosw ; [10] FATs
	movsw         ; [11] Root Dir. Entries
	
	lodsw         ; [13] Total logical sectors
	stosw
	call .testClusterCount ; Discover type of FAT     
	
	inc si  
	movsw         ; [16] Logical sectors per FAT
	
	; [2B] Volume label
	lea si, [bx + 0x2B]	
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
	mov [FATFS.totalRootDirSectors], ax
	
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
	
	
	; Initialize variables
	mov word [FATFS.lastReadFATSector], 65535
	
	jmp .end
	
	.testClusterCount: {
		test ax, ax | jz .halt  ; This is FAT32, and is not supported.
		cmp ax, 4085 | jg .fat16
		mov byte [FATFS.clusterBits], 12
		ret
		
		.fat16:
		mov byte [FATFS.clusterBits], 16
	ret
	
		.halt:
		int 30h
	}
	
	.end:
	LEAVEFN
}

; short (char* path)
; Locates a file given its extended path.
FATFS.LocateFile: {
	CLSTACK
	farg char* pathStr
	ENTERFN
	
	mov si, [$pathStr]
	push si
	call FATFS.FindFileInRootDir
	jc .notFound

	.nextSegment:
		add si, 11
		mov cl, [si]
		test cl, cl
		jz .end
		
		cmp cl, '/'
		jne .badPath
		
		inc si
				
		push ax
		push si
		call FATFS.FindFileInDir
		
		jc .notFound
	jmp .nextSegment
	
	.notFound:
	Print(."\NNot found.")
	jmp Halt
	
	.badPath:
	Print(."\NBad path.")
	jmp Halt
	
	.end:
	LEAVEFN
}

; void (char* fileName)
; Finds a single file in the root directory.
FATFS.FindFileInRootDir: {
	CLSTACK
	farg char* fileNameStr
	lvar int currentSector
	lvar short sectorsRemaining
	ENTERFN
	
	push si
	push word [Drive.bufferPtr]
	mov word [Drive.bufferPtr], FATFS.clusterBuffer
	
	; $currentSector = FATFS.rootDirSct
	mov ax, [FATFS.rootDirSct + 0]
	mov [$currentSector + 0], ax
	mov ax, [FATFS.rootDirSct + 2]
	mov [$currentSector + 2], ax
	
	; $sectorsRemaining = FATFS.totalRootDirSectors
	push word [FATFS.totalRootDirSectors]
	pop word [$sectorsRemaining]
	
	.findInSector:	
		; Read current sector
		push word [$currentSector + 2]
		push word [$currentSector + 0]
		call Drive.ReadSector
		
		mov si, [$fileNameStr]
		mov di, [Drive.bufferPtr]
		
		; 16 Directory entries per sector
		mov dl, 16
		.entry:
			call FATFS._TestFileEntry
			jnc .found
			
			add di, 32
			
			dec dl
		jnz .entry
		
		add word [$currentSector + 0], 1
		adc word [$currentSector + 2], 0
	
		dec word [$sectorsRemaining]
	jnz .findInSector
	
	; Return with AX = 0 to indicate the entry wasn't found.
	xor ax, ax
	stc
	
	.found:
	.end:
	pop word [Drive.bufferPtr]
	pop si
	LEAVEFN
}

/* short (char* fileName, short dirCluster)
 * looks for a file entry within the directory
 * stored at dirCluster */
FATFS.FindFileInDir: {
	CLSTACK
	farg char* fileNameStr
	farg short dirCluster
	ENTERFN
	
	push word [Drive.bufferPtr]
	mov word [Drive.bufferPtr], FATFS.clusterBuffer
	
	.readCluster:
		push word [$dirCluster]
		call FATFS.ReadCluster
		
		mov si, [$fileNameStr]
		mov di, [Drive.bufferPtr]
		
		; 16 Directory entries per sector
		mov dl, 16
		.entry:
			call FATFS._TestFileEntry
			jnc .found
			
			add di, 32
			
			dec dl
		jnz .entry
		
		push word [$dirCluster]
		call FATFS.GetNextClusterOf
		mov [$dirCluster], ax
		jc .notFound
	jmp .readCluster
	
	.notFound
	Print(."not found")
	jmp Halt
	
	.found:
	Serial.Print(."\N[FS]Located in root")
	
	.end:
	pop word [Drive.bufferPtr]
	LEAVEFN
}

; [SI] = file name | [DI] = ptr
; Destroys: AX, CX
FATFS._TestFileEntry: {
	;Serial.Print(."\NTest: ")
	;Serial.PrintHexNum si
	;Serial.Print(." and ")
	;Serial.PrintHexNum di
	
	{
		push cx
		push si | push di
		
		mov cx, 11
		rep cmpsb
	
		pop di | pop si
		pop cx
	}
	jne .notEqual
	
	; Get cluster number, and return with carry flag clear
	mov ax, [di + 0x1A]
	clc
	ret
	
	; Return with carry set to represent an error
	.notEqual:
	stc
	ret 
}

; void (short cluster)
FATFS.ReadCluster: {
	CLSTACK
	farg short cluster
	ENTERFN
	
	push dx
	push word [Drive.bufferPtr]
	
	mov ax, [$cluster]
	
	Serial.Print(."\N[FS] Cls ")
	Serial.PrintHexNum ax
	Serial.Print(." to ")
	Serial.PrintHexNum word [Drive.bufferPtr]
	
	; If cluster number <= 2, it is invalid.
	cmp ax, 2
	jg .read
		
	Print(."\NBad cluster.")
	jmp Halt
	
	.read:
	; Calculate beginning sector in the data area.
	sub ax, 2
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
	pop dx
	LEAVEFN
}

; short (short cluster)
; Reads FAT table and returns the next cluster in the chain.
; If the end of the chain has been reached, returns 0xFFFF and sets the carry flag.
;
; Destroys AX, BX, CX, DI
FATFS.GetNextClusterOf: {
	CLSTACK
	farg short cluster
	ENTERFN
	
	push dx
	
	cmp byte [FATFS.clusterBits], 16
	je .fat16
	jmp Halt
		
	.fat16:	{
		; Use the cluster number to find the next one.
		; Each cluster number is 2 bytes. We need to find
		; in what FAT map sector our next cluster number is.
		xor dx, dx
		mov ax, [$cluster]
		mov cx, 256 | div cx
		
		; Reads a sector of the FAT table, if necessary
		push ax
		call FATFS._readFATSector
		
		; Calculate the offset into the FAT table and get the next cluster index
		mov di, [$cluster]
		shl di, 1 ; Multiply by 2 because each FAT entry is 2 bytes.
		mov ax, [FATFS.clusterMapBuffer + di]
		
		; Save the cluster number, and check if we are done.
		cmp ax, 0xFFFF
		jne .found
		
		stc
		jmp .end
	}
	
	.fat12: {
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
		jmp .done
		
		.oddcluster:
		mov cl, 4
		shr ax, cl
		
		.done:
		cmp ax, 0xFFF
		jne .found
		
		stc
		jmp .end
	}
	
	.found:
	clc
	
	.end:
	pop dx
	LEAVEFN
}

; void (short cluster)
FATFS.ReadClusterChain: {
	CLSTACK
	farg short cluster
	ENTERFN
	
	; Save drive buffer pointer
	push word [Drive.bufferPtr]
	
	Serial.Print(."\N[FS] Chain ")
	Serial.PrintHexNum word [$cluster]
	
	mov dx, [$cluster]
	.chainLoop:
		; Read current cluster first
		push dx
		call FATFS.ReadCluster
		
		; Increase buffer ptr by cluster size
		mov ax, [FATFS.bytesPerCluster]
		add [Drive.bufferPtr], ax
		
		push dx
		call FATFS.GetNextClusterOf
		mov dx, ax		
		jc .end
	jmp .chainLoop
	
	.end:
	pop word [Drive.bufferPtr]
	
	LEAVEFN
}

; void (short sect)
; Reads a single sector of the FAT map.
FATFS._readFATSector: {
	CLSTACK
	farg short sector
	ENTERFN
	
	; If we already have this sector loaded, no point in loading it again.
	mov ax, [$sector]
	cmp ax, [FATFS.lastReadFATSector]
	je .end
	
	; DX:AX = AX
	cwd
	mov [FATFS.lastReadFATSector], ax
	
	; LBA = FAT_Start + Sector
	add ax, [FATFS.fatSct]
	adc dx, [FATFS.fatSct + 2]
	
	push word [Drive.bufferPtr]
		mov word [Drive.bufferPtr], FATFS.clusterMapBuffer
		push dx | push ax
		call Drive.ReadSector
	pop word [Drive.bufferPtr]

	.end:
	LEAVEFN
}