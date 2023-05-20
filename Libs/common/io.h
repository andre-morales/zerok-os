#define IO_H 1

#ifdef SERIAL_H
	%macro Serial.Print 1
		push si
		mov si, %1
		call Serial.print
		pop si
	%endmacro
	
	%macro Serial.PrintHexNum 1
		push word %1
		call Serial.printHexNum
	%endmacro
#else
	%macro Serial.Print 1
	%endmacro
	
	%macro Serial.PrintHexNum 1
	%endmacro
#endif

