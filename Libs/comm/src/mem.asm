[SECTION .text]
[BITS 16]
[CPU 8086]

EXTERN __alloc_base

var short base

; Initializes memory allocation system
;
; Inputs: .
; Outputs: .
; Destroys: .
GLOBAL Mem.Init
Mem.Init: {
	mov word [base], __alloc_base
ret }

; Allocates a memory block
;
; Inputs: AX = Size
; Outputs: AX = Pointer to memory block
; Destroys: .
GLOBAL Mem.Alloc
Mem.Alloc: {
	push word [base]
	add [base], ax
	pop ax
ret }

GLOBAL Mem.Free
Mem.Free {
ret }

[SECTION .bss]
@bss:
