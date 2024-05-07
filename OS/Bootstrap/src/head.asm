/**
 * Head (Stage 2)
 *
 * Author:   André Morales 
 * Creation: 02/01/2021
 * Modified: 05/05/2024
 *
 * The second stage is stored in the reserved sectors of the boot partition. It is loaded by the
 * first stage all at once.
 *
 *     :: MEMORY MAP ::
 * -- [0x 500 -  ...  ] Where Stage 3 file will be loaded
 * -- [0x 700 -  ...  ] Where Stage 3 code begins
 * -- [0x3000 -  ...  ] FAT16 Cluster Buffer
 * -- [0x6000 -  ...  ] Stage 2 (Us)
 * -- [0x7C00 - 0x7DFF] Our VBR still loaded
 * -- [0x7E00 - 0x7FFF] Stack
 */

#include "version.h"
#include <comm/strings.h>
#include <comm/serial.h>
#include <comm/serial_macros.h>
#include <comm/console.h>
#include <comm/console_macros.h>
#include <comm/drive.h>
#include <comm/fat1x.h>

; How many sectors this stage takes up
%define SECTORS 6
%define LOG CONSOLE_FLOG

[SECTION .text]
[BITS 16]
[CPU 8086]

; Stores in the file our signature and sector count which
; then are used by Stage 1 to indentify and load us.
db 'Xt'
dw SECTORS  

start: {
	; Clear segments
	xor ax, ax
	mov ds, ax
	mov es, ax
	
	; Get beginning sector pushed by boot_head
	pop word [FATFS.beginningSct]      
	pop word [FATFS.beginningSct + 2]
	
	; Setup stack
	mov ss, ax
	mov sp, 0x7FF0

	; Configure free interrupt 30h to halt the system if we need
	mov word [0x30 * 4 + 0], Halt ; Setup interrupt 0x30 to Halt
	mov word [0x30 * 4 + 2], 0
	
	; Store drive number
	mov [Drive.id], dl
	
	; Print header
	CONSOLE_PRINT(."\n-- &bZk&3Loader &4Head &cv$#VERSION#\n")
	
	; Initialize serial
	call Serial.Init	
	LOG(."I Serial ready.\n")
	
	; Configure a buffer region and temporary storage to process the file system
	mov word [Drive.bufferPtr], 0x0500
	mov word [FATFS.clusterBuffer], 0x2000
	
	call InitDrive
	call InitFileSystem
	
	LOG(."I Press any key to load BSTRAP.BIN.\n")
	call Console.WaitKey
	call Load_LdrHeadBin

	; Copy all Drive variables to the pointer stored in Stage 3.
	mov si, Drive.vars_begin
	mov di, [0x702]
	
	mov cx, Drive.vars_end
	sub cx, si
	rep movsb 
	
	; Copy all FATFS variables to the pointer stored in Stage 3.
	mov si, FATFS.vars_begin
	mov di, [0x704]
	
	mov cx, FATFS.vars_end
	sub cx, si
	rep movsb 
	
	; Check the signature
	cmp word [0x500], 'Zk' | je .jump
	LOG(."E Invalid signature.\n")
	int 0x30

; Jump to Stage 3.
.jump:
	LOG(.". Jumping...\n")
	jmp 0x700
}

; -- Load XTOS/BSTRAP.BIN
Load_LdrHeadBin: {
	mov si, ."ZKOS       /BSTRAP  BIN"
	push si
	call FATFS.LocateFile
	LOG(."K Found.\n")
	
	mov word [Drive.bufferPtr], 0x500
	
	push ax
	call FATFS.ReadClusterChain
	
	LOG(."K Loaded.\n")
ret }

FileNotFoundOnDir: {
	push si
	CONSOLE_PRINT(."\nFile '")
	;mov si, [FATFS.filePathPtr]
	pop si
	call Console.Print
	
	CONSOLE_PRINT(."' not found on directory.")
	int 30h
}

Halt: {
	LOG(."E System halted.")
	cli | hlt
}

InitFileSystem: {
	LOG(."I Partition config:")
	
	push ds 
	
	push ds | pop es
	xor ax, ax | mov ds, ax

	mov ax, 0x7C00 | push ax
	call FATFS.Initialize
	
	pop ds	
	
	CONSOLE_PRINT(."\n  FAT")
	
	xor ah, ah
	mov al, [FATFS.clusterBits]
	call Console.PrintDecNum
	
	CONSOLE_PRINT(.": ")
	CONSOLE_PRINT(FATFS.label)
	
	CONSOLE_PRINT(."\n  Start: 0x")
	CONSOLE_PRINT_HEX_NUM word [FATFS.beginningSct + 2]
	CONSOLE_PUTCH(':')
	CONSOLE_PRINT_HEX_NUM word [FATFS.beginningSct]
	
	SERIAL_PRINT(."\n  FAT: 0x")
	SERIAL_PRINT_HEX_NUM word [FATFS.fatSct + 2]
	SERIAL_PRINT(':')
	SERIAL_PRINT_HEX_NUM word [FATFS.fatSct]
	
	SERIAL_PRINT(."\n  Root Dir: 0x")
	SERIAL_PRINT_HEX_NUM word [FATFS.rootDirSct + 2]
	SERIAL_PRINT(':')
	SERIAL_PRINT_HEX_NUM word [FATFS.rootDirSct]

	SERIAL_PRINT(."\n  Data: 0x")
	SERIAL_PRINT_HEX_NUM word [FATFS.dataAreaSct + 2]
	SERIAL_PRINT(':')
	SERIAL_PRINT_HEX_NUM word [FATFS.dataAreaSct]
	
	CONSOLE_PRINT(."\n  Reserved L. Sectors: ")
	CONSOLE_PRINT_DEC_NUM [FATFS.reservedLogicalSectors] 
	
	CONSOLE_PRINT(."\n  Total L. Sectors: ")
	CONSOLE_PRINT_DEC_NUM [FATFS.totalLogicalSectors] 
	
	CONSOLE_PRINT(."\n  FATs: ")
	CONSOLE_PRINT_DEC_NUM [FATFS.fats]
	
	CONSOLE_PRINT(."\n  Bytes per L. Sector: ")
	CONSOLE_PRINT_DEC_NUM [FATFS.bytesPerLogicalSector] 
	CONSOLE_PRINT(."\n  L. Sectors per Cluster: ")
	CONSOLE_PRINT_DEC_NUM [FATFS.logicalSectorsPerCluster] 
	CONSOLE_PRINT(."\n  Bytes per Cluster: ")
	CONSOLE_PRINT_DEC_NUM [FATFS.bytesPerCluster] 
	CONSOLE_PRINT(."\n  L. Sectors per FAT: ")
	CONSOLE_PRINT_DEC_NUM [FATFS.logicalSectorsPerFAT] 
	CONSOLE_PRINT(."\n")
ret }

InitDrive: {	
	call Drive.Init
	call Drive.CHS.GetProperties
	call Drive.LBA.GetProperties

	LOG(."I Drive [")
	xor ah, ah
	mov al, [Drive.id]
	CONSOLE_PRINT_HEX_NUM(ax)
	CONSOLE_PRINT(."] geometry:")
	
	CONSOLE_PRINT(."\n CHS (AH = 02h)")
	CONSOLE_PRINT(."\n  Bytes per Sector: ")
	CONSOLE_PRINT_DEC_NUM [Drive.CHS.bytesPerSector]
	
	CONSOLE_PRINT(."\n  Sectors per Track: ")
	xor ah, ah
	mov al, [Drive.CHS.sectorsPerTrack]
	call Console.PrintDecNum

	CONSOLE_PRINT(."\n  Heads Per Cylinder: ")
	CONSOLE_PRINT_DEC_NUM [Drive.CHS.headsPerCylinder]
	
	CONSOLE_PRINT(."\n  Cylinders: ")
	CONSOLE_PRINT_DEC_NUM [Drive.CHS.cylinders]
	
	CONSOLE_PRINT(."\n LBA (AH = 48h)")
	
	mov al, [Drive.LBA.available]
	test al, al | jz .printLBAProps
	cmp al, 1   | je .noDriveLBA
	CONSOLE_PRINT(."\n  The BIOS doesn't support LBA.")
	jmp .End
	
	.noDriveLBA:
	CONSOLE_PRINT(."\n  The drive doesn't support LBA.")
	jmp .End
	
	.printLBAProps:
	CONSOLE_PRINT(."\n  Bytes per Sector: ")
	CONSOLE_PRINT_DEC_NUM [Drive.LBA.bytesPerSector]
		
	.End:
	CONSOLE_PRINT(."\n")
ret }

@rodata:

; --------- Variable space ---------
[SECTION .bss]
@bss:
