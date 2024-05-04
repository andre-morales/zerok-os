%macro Putch 1
	push ax
	mov al, %1
	call putch
	pop ax
%endmacro

%macro Log 1
	push si
	mov si, %1
	call classLog
	pop si
%endmacro

%macro Print 1
	push si
	mov si, %1
	call print
	pop si
%endmacro

%macro PrintHexNum 1
	push %1
	call printHexNum
%endmacro

%macro Putnch 2
	mov al, %1
	mov cl, %2
	call putnch
%endmacro

%macro PrintDecNum 1
	mov ax, %1
	call printDecNum
%endmacro

%macro PrintColor 2
	mov si, %1
	mov al, %2
	call printColor
%endmacro

%macro ClearScreen 1
	mov ax, %1
	call clearScreen
%endmacro	