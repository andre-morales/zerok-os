.section .text
.global _start
_start:
 	/* Prepare stack */
	mov $0xFF0, %esp
	
	 /* Save ESI (argument pointer) on stack so that main pops it later. */
	push %esi

	call setupPagingStructures
	call enablePaging	
	call main		

	hlt
1:
	jmp 1b

setupPagingStructures:
	/* -- Page directory at 0x1000 -- */
	mov $0x1000, %edi

	/* Setup first page directory entry to 0x2000 */
	mov $0b010000000000111, %eax 
	stosl

	/* Zero-out the rest of the page directory entries. */
	xor %eax, %eax
	mov $1023, %ecx
	rep stosl

	/* -- Page table at 0x2000 -- */
	mov $0x2000, %edi
	mov $0b0000000000111, %eax

	/* Identity map 16 pages.*/
	mov $16, %ecx
	.setpage:
		stosl
		add $0b1000000000000, %eax
	loop .setpage

	/* Zero-out rest of page table entries */
	xor %eax, %eax
	mov $1008, %ecx
	rep stosl
ret

enablePaging:
	mov $0x1000, %eax
	mov %eax, %cr3

	mov %cr0, %eax
	or $0x80000000, %eax
	mov %eax, %cr0
ret
