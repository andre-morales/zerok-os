#define IO_H 1
#ifndef SERIAL_ENABLED
	#ifdef SERIAL_H
		#define SERIAL_ENABLED 1
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
#endif
