; Author:   André Morales 
; Version:  2.0
; Creation: 06/10/2020
; Modified: 31/01/2022

%macro Print 1
	mov si, %1
	call print
%endmacro

%macro PrintDecNum 1
	mov ax, %1
	call printDecNum
%endmacro

%macro Putch 1
	mov al, %1
	call putch
%endmacro

%macro Putnch 2
	mov al, %1
	mov cl, %2
	call putnch
%endmacro

%define Getch() call getch
%define Pause() call pause

%macro PrintColor 2
	mov si, %1
	mov al, %2
	call printColor
%endmacro
%macro ClearScreen 1
	mov ax, %1
	call clearScreen
%endmacro

#ifdef STDCONIO_MINIMAL
	%macro PrintHexNum 1
		mov ax, %1
		call printHexNum
	%endmacro
#else
	%macro PrintHexNum 1
		push %1
		call printHexNum
	%endmacro
#endif

