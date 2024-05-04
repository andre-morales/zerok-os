#include <strings.h>

%define PORT 0x3F8 

%macro outb 2
	mov dx, %1
	mov al, %2
	out dx, al
%endmacro

%macro inb 1
	mov dx, %1
	in al, dx
%endmacro

GLOBAL Serial.Init
GLOBAL Serial.Print
GLOBAL Serial.PrintHexNum
GLOBAL Serial.Putch

var bool Serial.initialized

[SECTION .text]
[BITS 16]
Serial.Init: {
	push ax | push dx

	mov byte [Serial.initialized], 0x00
	outb PORT+1, 0x00 ; Disable all interrupts
	outb PORT+3, 0x80 ; Enable DLAB (set baud rate divisor)
	outb PORT+0, 0x06 ; Set divisor to 6 (lo byte) 19200 baud
	outb PORT+1, 0x00 ;                  (hi byte)
	outb PORT+3, 0x03 ; 8 bits, no parity, one stop bit
	outb PORT+2, 0xC7 ; Enable FIFO, clear them, with 14-byte threshold
	outb PORT+4, 0x0B ; IRQs enabled, RTS/DSR set
	outb PORT+4, 0x1E ; Set in loopback mode, test the serial chip
	outb PORT+0, 0xAE ; Test serial chip (send byte 0xAE and check if serial returns same byte)		
	
	inb PORT
	cmp al, 0xAE
	jne .failure
	
	mov byte [Serial.initialized], 0x01
	outb PORT+4, 0x0F
	jmp .end
	
.failure:
	jmp .end
	
.end:
	pop dx | pop ax 
	ret
}

Serial.Putch: {
	cmp byte [Serial.initialized], 0x01
	jne .end
	
	push ax
	
	; How many tries before giving up
	mov cx, 20
	
	.wait:
		inb PORT+5
		and al, 0x20
		
		test al, al
		jnz .done
	loop .wait
		
	.done:
	pop ax
	mov dx, PORT
	out dx, al

.end:
	ret
}

Serial.Print: {
	push ax | push cx | push dx
	
.putc:
	lodsb
	test al, al | jz .end
	
	call Serial.Putch
	jmp .putc
	
.end:
	pop dx | pop cx | pop ax
	ret
}

Serial.PrintHexNum {
	CLSTACK
	farg word number
	lvar char[8] str
	ENTERFN
	
	push ds | push es
	push ax | push dx
	push si | push di
	
	mov di, ss
	mov es, di
	mov ds, di
		
	mov ax, [$number]
	lea di, [$str]
	call Strings.HexToStr
	
	mov si, di
	call Serial.Print
	
	pop di | pop si
	pop dx | pop ax
	pop es | pop ds
		
	LEAVEFN
}

[SECTION .bss]
@bss:
