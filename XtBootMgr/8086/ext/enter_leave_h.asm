%macro ENTERF 1
	push bp
	mov bp, sp
	sub sp, %1
%endmacro
%macro LEAVEF 0
	mov sp, bp
	pop bp
%endmacro