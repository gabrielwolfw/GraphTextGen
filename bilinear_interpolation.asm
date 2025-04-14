; Bilinear Interpolation with proper header format
; Compile with: nasm -f elf64 bilinear_interpolation.asm -o bilinear_interpolation.o
; Link with: ld bilinear_interpolation.o -o bilinear_interpolation

section .data
    ; File paths
    input_file      db "input_quadrant.img", 0
    output_file     db "result.img", 0
    
    ; System call numbers
    SYS_OPEN        equ 2
    SYS_CLOSE       equ 3
    SYS_READ        equ 0
    SYS_WRITE       equ 1
    SYS_EXIT        equ 60
    
    ; File modes
    O_RDONLY        equ 0
    O_WRONLY        equ 1
    O_CREAT         equ 0100o
    S_IRUSR         equ 00400o
    S_IWUSR         equ 00200o
    
    ; Image dimensions
    input_width     dq 180      ; Width of input quadrant
    input_height    dq 170      ; Height of input quadrant
    
    ; Output dimensions (computed as 2x input)
    output_width    dd 360      ; 2 * input_width (as 32-bit for header)
    output_height   dd 340      ; 2 * input_height (as 32-bit for header)
    channels        dd 1        ; Grayscale image (1 channel)
    
section .bss
    input_fd        resq 1      ; File descriptor for input file
    output_fd       resq 1      ; File descriptor for output file
    input_buffer    resb 31000  ; Buffer for input image (180*170 = ~32000)
    output_buffer   resb 123000 ; Buffer for output image (360*340 = ~123000)
    header_buffer   resb 12     ; Buffer for header (width, height, channels)

section .text
    global _start

_start:
    ; Open input file
    mov rax, SYS_OPEN
    mov rdi, input_file
    mov rsi, O_RDONLY
    xor rdx, rdx
    syscall
    mov [input_fd], rax
    
    ; Read input file
    mov rax, SYS_READ
    mov rdi, [input_fd]
    mov rsi, input_buffer
    mov rdx, 31000            ; Input buffer size
    syscall
    
    ; Close input file
    mov rax, SYS_CLOSE
    mov rdi, [input_fd]
    syscall
    
    ; Apply bilinear interpolation
    mov rsi, input_buffer     ; Source buffer
    mov rdi, output_buffer+12 ; Destination buffer (skip header)
    call interpolate
    
    ; Prepare header for output file (12 bytes: width, height, channels)
    mov eax, [output_width]
    mov [header_buffer], eax
    mov eax, [output_height]
    mov [header_buffer+4], eax
    mov eax, [channels]
    mov [header_buffer+8], eax
    
    ; Create output file
    mov rax, SYS_OPEN
    mov rdi, output_file
    mov rsi, O_WRONLY | O_CREAT
    mov rdx, S_IRUSR | S_IWUSR
    syscall
    mov [output_fd], rax
    
    ; Write header first
    mov rax, SYS_WRITE
    mov rdi, [output_fd]
    mov rsi, header_buffer
    mov rdx, 12               ; Header size: 12 bytes
    syscall
    
    ; Write output image data
    mov rax, SYS_WRITE
    mov rdi, [output_fd]
    mov rsi, output_buffer+12
    mov rdx, 122400           ; Output image size (360*340)
    syscall
    
    ; Close output file
    mov rax, SYS_CLOSE
    mov rdi, [output_fd]
    syscall
    
    ; Exit program
    mov rax, SYS_EXIT
    xor rdi, rdi
    syscall

;----------------------------------------------------------
; Function: interpolate
; Bilinear interpolation following academic requirements
;
; Input:
;   RSI = pointer to input buffer
;   RDI = pointer to output buffer
;----------------------------------------------------------
interpolate:
    ; Preserve registers
    push rbx
    push r12
    push r13
    push r14
    push r15
    
    ; Get input dimensions
    mov r8, [input_width]     ; Input width
    mov r9, [input_height]    ; Input height
    
    ; Calculate output width
    mov r10, r8
    shl r10, 1                ; Output width = input width * 2
    
    ; Step 1: Copy known pixels
    xor r12, r12              ; y = 0
    
.loop_y1:
    cmp r12, r9               ; Compare y with height
    jge .step2                ; If y >= height, go to step 2
    
    xor r13, r13              ; x = 0
    
.loop_x1:
    cmp r13, r8               ; Compare x with width
    jge .next_y1              ; If x >= width, next row
    
    ; Calculate input offset: y * width + x
    mov rax, r12
    mul r8
    add rax, r13
    
    ; Get source pixel
    movzx rbx, byte [rsi + rax]
    
    ; Calculate output offset: (2*y) * out_width + (2*x)
    mov rax, r12
    shl rax, 1                ; 2*y
    mul r10                   ; * output_width
    mov rdx, r13
    shl rdx, 1                ; 2*x
    add rax, rdx
    
    ; Write to output
    mov byte [rdi + rax], bl
    
    inc r13                   ; x++
    jmp .loop_x1
    
.next_y1:
    inc r12                   ; y++
    jmp .loop_y1
    
    ; Step 2: Interpolate horizontal pixels with weighted average
.step2:
    xor r12, r12              ; y = 0
    
.loop_y2:
    cmp r12, r9               ; Compare y with height
    jge .step3                ; If y >= height, go to step 3
    
    xor r13, r13              ; x = 0
    
.loop_x2:
    cmp r13, r8 - 1           ; Compare x with width-1
    jge .next_y2              ; If x >= width-1, next row
    
    ; Calculate input offsets
    mov rax, r12
    mul r8
    add rax, r13              ; offset = y*width + x
    
    ; Get left and right pixels
    movzx r14, byte [rsi + rax]       ; left pixel
    inc rax
    movzx r15, byte [rsi + rax]       ; right pixel
    
    ; Apply weighted interpolation: left*2/3 + right*1/3
    mov rbx, r14              ; Copy left to rbx
    shl rbx, 1                ; left * 2
    add rbx, r15              ; left*2 + right
    mov rax, rbx
    xor rdx, rdx              ; Zero out rdx for division
    mov rbx, 3
    div rbx                   ; (left*2 + right) / 3 = left*2/3 + right*1/3
    
    ; Calculate output offset: (2*y) * out_width + (2*x + 1)
    push rax                  ; Save interpolated value
    
    mov rax, r12
    shl rax, 1                ; 2*y
    mul r10                   ; * output_width
    mov rdx, r13
    shl rdx, 1                ; 2*x
    inc rdx                   ; 2*x + 1
    add rax, rdx
    
    pop rdx                   ; Restore interpolated value to rdx
    
    ; Write interpolated pixel
    mov byte [rdi + rax], dl
    
    ; Get left and right pixels again for the second interpolation point
    mov rax, r12
    mul r8
    add rax, r13
    movzx r14, byte [rsi + rax]       ; left pixel
    inc rax
    movzx r15, byte [rsi + rax]       ; right pixel
    
    ; Apply weighted interpolation: left*1/3 + right*2/3
    mov rbx, r15              ; Copy right to rbx
    shl rbx, 1                ; right * 2
    add rbx, r14              ; right*2 + left
    mov rax, rbx
    xor rdx, rdx              ; Zero out rdx for division
    mov rbx, 3
    div rbx                   ; (right*2 + left) / 3 = right*2/3 + left*1/3
    
    ; Store interpolated value temporarily
    push rax
    
    ; Calculate output offset for second horizontal pixel: (2*y) * out_width + (2*x + 3)
    mov rax, r12
    shl rax, 1                ; 2*y
    mul r10                   ; * output_width
    mov rdx, r13
    shl rdx, 1                ; 2*x
    add rdx, 3                ; 2*x + 3
    add rax, rdx
    
    pop rdx                   ; Restore interpolated value
    
    ; Write second interpolated horizontal pixel
    mov byte [rdi + rax], dl
    
    inc r13                   ; x++
    jmp .loop_x2
    
.next_y2:
    inc r12                   ; y++
    jmp .loop_y2
    
    ; Step 3: Interpolate vertical pixels with weighted average
.step3:
    xor r12, r12              ; y = 0
    
.loop_y3:
    cmp r12, r9 - 1           ; Compare y with height-1
    jge .step4                ; If y >= height-1, go to step 4
    
    xor r13, r13              ; x = 0
    
.loop_x3:
    cmp r13, r8               ; Compare x with width
    jge .next_y3              ; If x >= width, next row
    
    ; Calculate offsets for top and bottom pixels
    mov rax, r12
    mul r8
    add rax, r13
    movzx r14, byte [rsi + rax]  ; top pixel
    
    mov rax, r12
    inc rax
    mul r8
    add rax, r13
    movzx r15, byte [rsi + rax]  ; bottom pixel
    
    ; Apply weighted interpolation: top*2/3 + bottom*1/3
    mov rbx, r14              ; Copy top to rbx
    shl rbx, 1                ; top * 2
    add rbx, r15              ; top*2 + bottom
    mov rax, rbx
    xor rdx, rdx              ; Zero out rdx for division
    mov rbx, 3
    div rbx                   ; (top*2 + bottom) / 3 = top*2/3 + bottom*1/3
    
    ; Store interpolated value temporarily
    push rax
    
    ; Calculate output offset: (2*y + 1) * out_width + (2*x)
    mov rax, r12
    shl rax, 1                ; 2*y
    inc rax                   ; 2*y + 1
    mul r10                   ; * output_width
    mov rdx, r13
    shl rdx, 1                ; 2*x
    add rax, rdx
    
    pop rdx                   ; Restore interpolated value
    
    ; Write interpolated pixel
    mov byte [rdi + rax], dl
    
    ; Get top and bottom pixels again for the second interpolation point
    mov rax, r12
    mul r8
    add rax, r13
    movzx r14, byte [rsi + rax]  ; top pixel
    
    mov rax, r12
    inc rax
    mul r8
    add rax, r13
    movzx r15, byte [rsi + rax]  ; bottom pixel
    
    ; Apply weighted interpolation: top*1/3 + bottom*2/3
    mov rbx, r15              ; Copy bottom to rbx
    shl rbx, 1                ; bottom * 2
    add rbx, r14              ; bottom*2 + top
    mov rax, rbx
    xor rdx, rdx              ; Zero out rdx for division
    mov rbx, 3
    div rbx                   ; (bottom*2 + top) / 3 = bottom*2/3 + top*1/3
    
    ; Store interpolated value temporarily
    push rax
    
    ; Calculate output offset for second vertical pixel: (2*y + 3) * out_width + (2*x)
    mov rax, r12
    shl rax, 1                ; 2*y
    add rax, 3                ; 2*y + 3
    mul r10                   ; * output_width
    mov rdx, r13
    shl rdx, 1                ; 2*x
    add rax, rdx
    
    pop rdx                   ; Restore interpolated value
    
    ; Write second interpolated vertical pixel
    mov byte [rdi + rax], dl
    
    inc r13                   ; x++
    jmp .loop_x3
    
.next_y3:
    inc r12                   ; y++
    jmp .loop_y3
    
    ; Step 4: Interpolate diagonal pixels using already interpolated horizontal and vertical pixels
.step4:
    xor r12, r12              ; y = 0
    
.loop_y4:
    cmp r12, r9 - 1           ; Compare y with height-1
    jge .done                 ; If y >= height-1, we're done
    
    xor r13, r13              ; x = 0
    
.loop_x4:
    cmp r13, r8 - 1           ; Compare x with width-1
    jge .next_y4              ; If x >= width-1, next row
    
    ; Get horizontal interpolated pixels
    mov rax, r12
    shl rax, 1                ; 2*y
    mul r10                   ; * output_width
    mov rdx, r13
    shl rdx, 1                ; 2*x
    inc rdx                   ; 2*x + 1
    add rax, rdx
    movzx r14, byte [rdi + rax]    ; top-horizontal
    
    ; Calculate offset for bottom-horizontal
    push r14                      ; Save top-horizontal value
    
    mov rax, r12
    shl rax, 1                    ; 2*y
    add rax, 2                    ; 2*y + 2
    mul r10                       ; * output_width
    mov rdx, r13
    shl rdx, 1                    ; 2*x
    inc rdx                       ; 2*x + 1
    add rax, rdx
    movzx r15, byte [rdi + rax]   ; bottom-horizontal
    
    pop r14                       ; Restore top-horizontal value
    
    ; Apply weighted interpolation for diagonal: top-horizontal*2/3 + bottom-horizontal*1/3
    mov rbx, r14              ; Copy top-horizontal to rbx
    shl rbx, 1                ; top-horizontal * 2
    add rbx, r15              ; top-horizontal*2 + bottom-horizontal
    mov rax, rbx
    xor rdx, rdx              ; Zero out rdx for division
    mov rbx, 3
    div rbx                   ; (top-horizontal*2 + bottom-horizontal) / 3
    
    ; Store interpolated value temporarily
    push rax
    
    ; Calculate output offset: (2*y + 1) * out_width + (2*x + 1)
    mov rax, r12
    shl rax, 1                ; 2*y
    inc rax                   ; 2*y + 1
    mul r10                   ; * output_width
    mov rdx, r13
    shl rdx, 1                ; 2*x
    inc rdx                   ; 2*x + 1
    add rax, rdx
    
    pop rdx                   ; Restore interpolated value
    
    ; Write diagonal pixel
    mov byte [rdi + rax], dl
    
    inc r13                   ; x++
    jmp .loop_x4
    
.next_y4:
    inc r12                   ; y++
    jmp .loop_y4
    
.done:
    ; Restore registers
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret