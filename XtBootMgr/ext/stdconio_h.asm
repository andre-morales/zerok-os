; Author:   André Morales 
; Version:  1.1
; Creation: 06/10/2020
; Modified: 24/10/2020

%define NL 0Ah
%define CR 0Dh
%define NLCR CR, NL

%macro Putch 1
	mov al, %1
	call putch
%endmacro
%macro Putnch 2
	mov al, %1
	mov cl, %2
	call putnch
%endmacro
%macro Pause 1
	call pause
%endmacro

%macro Getch 1
	call getch
%endmacro

%macro Print 1
	mov si, %1
	call printStr
%endmacro
%macro PrintColor 2
	mov si, %1
	mov al, %2
	call printColorStr
%endmacro
%macro PrintDecNum 1
	mov ax, %1
	call printDecNumber
%endmacro
%macro DecNumToStr 1 
	mov ax, %1
	call decNumToStr
%endmacro
%macro PrintHexNum 1
	mov ax, %1
	call printHexNumber
%endmacro
%macro ClearScreen 1
	call clearScreen
%endmacro
%macro D_PrintHexNum 1
	push ax
	mov ax, %1
	call printHexNumber
	pop ax
%endmacro
%macro D_Print 1
	push si
	mov si, %1
	call printStr
	pop si
%endmacro