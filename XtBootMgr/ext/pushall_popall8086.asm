; Author:   André Morales 
; Version:  1.1
; Creation: 06/10/2020
; Modified: 08/10/2020

; --- Emulated Push All ---
pushAll:    
    push bp
    mov bp, sp
    
    push ax           ; Save AX 
    mov ax, [bp + 2]  ; Get return address into AX
    mov [bp + 2], bx  ; Replace it with BX
    
    push cx    
    push dx
    push si
    push di

    push ax           ; Push the return address into the stack
    mov ax, [bp - 2]  ; Restore AX
    mov bp, [bp]      ; Restore BP
ret                  
   
; --- Emulated Pop All ---
popAll:
    pop ax            ; Get return address
    mov bp, sp
    
    mov bx, [bp + 12] ; Get BX back
    mov [bp + 12], ax ; Save return address   
   
    pop di
    pop si
    pop dx
    pop cx
    pop ax 
    pop bp 
ret