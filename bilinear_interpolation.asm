section .data
    input_img db 'selected_quadrant.img', 0
    output_img db 'output_image.img', 0
    msg_result_saved db 'Result saved to output_image.img', 10, 0

section .bss
    img_width resd 1
    img_height resd 1
    img_channels resd 1
    buffer resb 10000  ; Ajustar el tamaño según sea necesario para tu imagen
    new_buffer resb 10000  ; Tamaño similar al buffer original para la nueva imagen interpolada

section .text
global _start

_start:
    ; Abrir el archivo de imagen de entrada
    mov rax, 2          ; syscall: sys_open
    lea rdi, [input_img]
    xor rsi, rsi        ; flags: O_RDONLY
    syscall

    ; Comprobar si el archivo se abrió correctamente
    cmp rax, 0
    js _exit

    ; Guardar el descriptor de archivo
    mov rdi, rax

    ; Leer el encabezado de la imagen (ancho, alto, canales)
    mov rax, 0          ; syscall: sys_read
    mov rsi, buffer
    mov rdx, 12         ; Leer 12 bytes (3 * 4 bytes)
    syscall

    ; Extraer ancho, alto y canales del buffer
    mov rax, [buffer]
    mov [img_width], rax
    mov rax, [buffer + 4]
    mov [img_height], rax
    mov rax, [buffer + 8]
    mov [img_channels], rax

    ; Leer los datos de la imagen
    ; Calcular el tamaño de los datos de la imagen
    mov rax, [img_width]
    mov rbx, [img_height]
    mul rbx
    mov rcx, [img_channels]
    mul rcx
    mov rdx, rax

    ; Leer los datos de la imagen en el buffer
    mov rax, 0          ; syscall: sys_read
    mov rsi, buffer
    syscall

    ; Aplicar la interpolación bilineal
    ; (Implementaremos la interpolación bilineal aquí)

    ; Guardar la imagen resultante en un nuevo archivo
    ; Abrir el archivo de salida
    mov rax, 2          ; syscall: sys_open
    lea rdi, [output_img]
    mov rsi, 66         ; flags: O_CREAT | O_WRONLY
    mov rdx, 438        ; mode: 0666 en octal
    syscall

    ; Comprobar si el archivo se abrió correctamente
    cmp rax, 0
    js _exit

    ; Guardar el descriptor de archivo
    mov rdi, rax

    ; Escribir el encabezado (ancho, alto, canales)
    mov rax, 1          ; syscall: sys_write
    mov rsi, buffer
    mov rdx, 12         ; Escribir 12 bytes (3 * 4 bytes)
    syscall

    ; Escribir los datos de la nueva imagen
    mov rax, 1          ; syscall: sys_write
    mov rsi, new_buffer
    ; rdx ya contiene el tamaño de los datos de la imagen
    syscall

    ; Mostrar mensaje de éxito
    lea rdi, [msg_result_saved]
    call print_string

_exit:
    mov rax, 60         ; syscall: sys_exit
    xor rdi, rdi        ; status: 0
    syscall

print_string:
    ; Imprimir una cadena de caracteres
    mov rax, 1          ; syscall: sys_write
    mov rdi, 1          ; file descriptor: stdout
    mov rsi, rdi
    mov rdx, 100        ; longitud máxima (ajustar según sea necesario)
    syscall
    ret