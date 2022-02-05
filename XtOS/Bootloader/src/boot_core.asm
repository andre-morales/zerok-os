[BITS 16]
[CPU 8086]
[ORG 0x6000]

; Author:   André Morales 
; Version:  0.6.3
; Creation: 02/01/2021
; Modified: 25/01/2021

; -- [...    - 0x06FF] Stack
; -- [0x0700 -  ...  ] Where Stage 3 will be loaded
; -- [0x3000 -  ...  ] FAT16 Cluster Buffer
; -- [0x6000 -  ...  ] Stage 2 (Us)
; -- [0x7C00 - 0x7DFF] Our VBR still loaded

db 'Xt' ; Binary signature
dw 5    ; How many sectors this stage takes up

#include version_h.asm
#include <stdconio_h.asm>

Start: {
	xor ax, ax
	mov ds, ax
	mov es, ax
	mov ss, ax
	pop word [FATFS.beginningSct]
	pop word [FATFS.beginningSct + 2]
	
	mov [Drive.id], dl

	Print(."\N         XtOS Bootloader v${VERSION}")
	
	mov word [Drive.bufferPtr], 0x0700
	mov word [FATFS.clusterBuffer], 0x2000
	
	call getDriveGeometry
	call getBootPartitionProperties
	
	
	Print(."\NPress any key to load LDRHEAD.BIN.")
	Getch()
	call Load_LdrHeadBin
	
	; Copy all Drive variables to the pointer stored in Stage 3.
	mov si, Drive
	mov di, [0x0702]
	mov cx, Drive.vars_end - Drive
	rep movsb 
	
	; Copy all FATFS variables to the pointer stored in Stage 3.
	mov si, FATFS
	mov di, [0x0704]
	mov cx, FATFS.vars_end - FATFS
	rep movsb 
	
	; Jump to Stage 3.
	jmp 0x0700
}

; -- Load XTOS/LDRHEAD.BIN
Load_LdrHeadBin: {	
	mov si, ."XTOS       /LDRHEAD BIN"
	call FATFS.FindFile
	Print(."\NFound.")
	
	mov word [Drive.bufferPtr], 0x700
	
	push ax
	call FATFS.ReadClusterChain
	
	Print(." Loaded.\N")
ret }

FileNotFoundOnDir: {
	Print(."\NFile '")
	mov si, [FATFS.filePathPtr]
	call print
	
	Print(."' not found on directory.")
	jmp Halt
}


Halt: {
	Print(."\NSystem halted.")
	cli | hlt
}

getBootPartitionProperties: {
	Print(."\N--- [Boot partition properties] ---")
	
	push ds 
	
	push ds | pop es
	xor ax, ax | mov ds, ax
	
	mov si, 0x7C00
	call FATFS.Initialize
	pop ds	
	
	Print(."\NLabel: ")
	Print(FATFS.label)
	Print(."\NBeginning: 0x")
	PrintHexNum word [FATFS.beginningSct + 2]
	Putch(':')
	PrintHexNum word [FATFS.beginningSct]
	
	Print(."\NFAT: 0x")
	PrintHexNum word [FATFS.fatSct + 2]
	Putch(':')
	PrintHexNum word [FATFS.fatSct]
	
	Print(."\NRoot Dir: 0x")
	PrintHexNum word [FATFS.rootDirSct + 2]
	Putch(':')
	PrintHexNum word [FATFS.rootDirSct]

	Print(."\NData Area: 0x")
	PrintHexNum word [FATFS.dataAreaSct + 2]
	Putch(':')
	PrintHexNum word [FATFS.dataAreaSct]
	
	Print(."\NBytes per Logical Sector: ")
	PrintDecNum [FATFS.bytesPerLogicalSector] 
	Print(."\NLogical Sectors per Cluster: ")
	PrintDecNum [FATFS.logicalSectorsPerCluster] 
	Print(."\NBytes per Cluster: ")
	PrintDecNum [FATFS.bytesPerCluster] 
	Print(."\NLogical Sectors per FAT: ")
	PrintDecNum [FATFS.logicalSectorsPerFAT] 
	Print(."\NFATs: ")
	PrintDecNum [FATFS.fats]
	Print(."\NRoot directory entries: ")
	PrintDecNum [FATFS.rootDirectoryEntries] 
	Print(."\NDirectory entries per cluster: ")
	PrintDecNum [FATFS.directoryEntriesPerCluster] 
ret }

getDriveGeometry: {	
	call Drive.Init
	call Drive.CHS.GetProperties
	call Drive.LBA.GetProperties

	Print(."\N--- [Geometries of drive: ")
	xor ah, ah
	mov al, [Drive.id]
	PrintHexNum(ax)
	Print(."] ---")
	
	Print(."\NCHS (AH = 02h)")
	Print(."\N  Bytes per Sector: ")
	PrintDecNum [Drive.CHS.bytesPerSector]
	
	Print(."\N  Sectors per Track: ")
	xor ah, ah
	mov al, [Drive.CHS.sectorsPerTrack]
	call printDecNum

	Print(."\N  Heads Per Cylinder: ")
	PrintDecNum [Drive.CHS.headsPerCylinder]
	
	Print(."\N  Cylinders: ")
	PrintDecNum [Drive.CHS.cylinders]
	
	Print(."\NLBA (AH = 48h)")
	
	mov al, [Drive.LBA.available]
	test al, al | jz .printLBAProps
	cmp al, 1   | je .noDriveLBA
	Print(."\N  The BIOS doesn't support LBA.")
	jmp .End
	
	.noDriveLBA:
	Print(."\N  The drive doesn't support LBA.")
	jmp .End
	
	.printLBAProps:
	Print(."\N  Bytes per Sector: ")
	PrintDecNum [Drive.LBA.bytesPerSector]
		
	.End:
ret }

#include <stdconio.asm>
#include <drive.asm>
#include <fat1x.asm>

@rodata:

times (512 * 5)-($-$$) db 0x90 ; Round to 1kb.

@data:
