#ifdef CONSOLE_MACROS_MINIMAL
	%macro CONSOLE_PRINT 1
		mov si, %1
		call Console.Print
	%endmacro

	%macro CONSOLE_PUTCH 1
		push ax
		mov al, %1
		call Console.Putch
		pop ax
	%endmacro

	%macro CONSOLE_PRINT_HEX_NUM 1
		mov ax, %1
		call Console.PrintHexNumShort
	%endmacro
#else 
	%macro CONSOLE_PRINT 1
		push si
		mov si, %1
		call Console.Print
		pop si
	%endmacro
	
	%macro CONSOLE_PUTCH 1
		push ax
		mov al, %1
		call Console.Putch
		pop ax
	%endmacro

	%macro CONSOLE_PUTNCH 2
		mov al, %1
		mov cl, %2
		call Console.Putnch
	%endmacro

	%macro CONSOLE_FLOG 1
		push si
		mov si, %1
		call Console.FLog
		pop si
	%endmacro

	%macro CONSOLE_PRINT_HEX_NUM 1
		push %1
		call Console.PrintHexNum
	%endmacro
	
	%macro CONSOLE_PRINT_DEC_NUM 1
		mov ax, %1
		call Console.PrintDecNum
	%endmacro
#endif