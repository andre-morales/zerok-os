#ifdef SERIAL_H
%macro SERIAL_PRINT 1
		push si
		mov si, %1
		call Serial.Print
		pop si
	%endmacro
	
	%macro SERIAL_PRINT_HEX_NUM 1
		push word %1
		call Serial.PrintHexNum
	%endmacro
#else
	%macro SERIAL_PRINT 1
	%endmacro
	
	%macro SERIAL_PRINT_HEX_NUM 1
	%endmacro
#endif