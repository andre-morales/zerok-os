#define LOADER_ARGS_SIZE 13
%define BREAK xchg bx, bx

EXTERN main

GLOBAL _start
GLOBAL loader_args

var byte[$#LOADER_ARGS_SIZE#] loader_args

_start: {
	; Set all segments to 0x10
	mov ax, 0x10
	mov ds, ax
	mov es, ax
	mov ss, ax
	mov fs, ax
	mov gs, ax

 	; Prepare stack
	mov esp, 0xFF0
	
	call copyLoaderStruct	
	call main		
	jmp halt
}

copyLoaderStruct: {
	; ESI is already set to point to loader args structure.
	; CX should contain the size of the structure.
	;
	; If the structure signature is invalid or the passed size
	; is different than the one declared here, mark the structure
	; as invalid.
	cmp word [esi], 'Zk'
	jne .badSignature	
	
	cmp cx, $#LOADER_ARGS_SIZE#
	jne .badSignature
	
	; Copy the structure to our BSS section.
	mov edi, loader_args
	rep movsb
ret

	.badSignature:
		mov word [loader_args], 0xBAD
	ret
}

halt: {
	cli 
	hlt
	jmp halt
}

[SECTION .bss]
@bss: