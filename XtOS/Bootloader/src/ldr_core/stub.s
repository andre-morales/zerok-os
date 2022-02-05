.section .text
.global _start
_start:
	mov $0x7FF0, %esp
	
	push %esi /* Pass ESI (argument pointer) to main */
	call kmain
		
	cli
1:  hlt
	jmp 1b
