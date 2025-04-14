; Interpolación Bilineal 
; Compilar con: nasm -f elf64 bilinear_interpolation.asm -o bilinear_interpolation.o
; Enlazar con: ld bilinear_interpolation.o -o bilinear_interpolation

section .data
    ; Rutas de archivos
    input_file      db "input_quadrant.img", 0
    output_file     db "result.img", 0
    
    ; Números de llamadas al sistema
    SYS_OPEN        equ 2
    SYS_CLOSE       equ 3
    SYS_READ        equ 0
    SYS_WRITE       equ 1
    SYS_EXIT        equ 60
    
    ; Modos de archivo
    O_RDONLY        equ 0
    O_WRONLY        equ 1
    O_CREAT         equ 0100o
    S_IRUSR         equ 00400o
    S_IWUSR         equ 00200o
    
    ; Dimensiones de la imagen
    input_width     dq 180      ; Ancho del cuadrante de entrada
    input_height    dq 170      ; Alto del cuadrante de entrada
    
    ; Dimensiones de salida (calculadas como 2x entrada)
    output_width    dd 360      ; 2 * ancho_entrada (como 32-bit para encabezado)
    output_height   dd 340      ; 2 * alto_entrada (como 32-bit para encabezado)
    channels        dd 1        ; Imagen en escala de grises (1 canal)
    
section .bss
    input_fd        resq 1      ; Descriptor de archivo para entrada
    output_fd       resq 1      ; Descriptor de archivo para salida
    input_buffer    resb 31000  ; Buffer para imagen de entrada (180*170 = ~32000)
    output_buffer   resb 123000 ; Buffer para imagen de salida (360*340 = ~123000)
    header_buffer   resb 12     ; Buffer para encabezado (ancho, alto, canales)

section .text
    global _start

_start:
    ; Abrir archivo de entrada
    mov rax, SYS_OPEN
    mov rdi, input_file
    mov rsi, O_RDONLY
    xor rdx, rdx
    syscall
    mov [input_fd], rax
    
    ; Leer archivo de entrada
    mov rax, SYS_READ
    mov rdi, [input_fd]
    mov rsi, input_buffer
    mov rdx, 31000            ; Tamaño del buffer de entrada
    syscall
    
    ; Cerrar archivo de entrada
    mov rax, SYS_CLOSE
    mov rdi, [input_fd]
    syscall
    
    ; Aplicar interpolación bilineal
    mov rsi, input_buffer     ; Buffer origen
    mov rdi, output_buffer+12 ; Buffer destino (saltar encabezado)
    call interpolate
    
    ; Preparar encabezado para archivo de salida (12 bytes: ancho, alto, canales)
    mov eax, [output_width]
    mov [header_buffer], eax
    mov eax, [output_height]
    mov [header_buffer+4], eax
    mov eax, [channels]
    mov [header_buffer+8], eax
    
    ; Crear archivo de salida
    mov rax, SYS_OPEN
    mov rdi, output_file
    mov rsi, O_WRONLY | O_CREAT
    mov rdx, S_IRUSR | S_IWUSR
    syscall
    mov [output_fd], rax
    
    ; Escribir primero el encabezado
    mov rax, SYS_WRITE
    mov rdi, [output_fd]
    mov rsi, header_buffer
    mov rdx, 12               ; Tamaño del encabezado: 12 bytes
    syscall
    
    ; Escribir los datos de la imagen de salida
    mov rax, SYS_WRITE
    mov rdi, [output_fd]
    mov rsi, output_buffer+12
    mov rdx, 122400           ; Tamaño de imagen de salida (360*340)
    syscall
    
    ; Cerrar archivo de salida
    mov rax, SYS_CLOSE
    mov rdi, [output_fd]
    syscall
    
    ; Salir del programa
    mov rax, SYS_EXIT
    xor rdi, rdi
    syscall

;----------------------------------------------------------
; Función: interpolate
; Implementación de interpolación bilineal según los requisitos académicos
;
; Entrada:
;   RSI = puntero al buffer de entrada
;   RDI = puntero al buffer de salida
;----------------------------------------------------------
interpolate:
    ; Preservar registros que usaremos
    push rbx
    push r12
    push r13
    push r14
    push r15
    
    ; Obtener dimensiones de entrada
    mov r8, [input_width]     ; Ancho de entrada
    mov r9, [input_height]    ; Alto de entrada
    
    ; Calcular ancho de salida
    mov r10, r8
    shl r10, 1                ; Ancho de salida = ancho de entrada * 2
    
    ; Paso 1: Copiar píxeles conocidos (los originales)
    ; Estos son los puntos de referencia para nuestra interpolación
    xor r12, r12              ; y = 0 (iniciamos desde la esquina superior izquierda)
    
.loop_y1:
    cmp r12, r9               ; Comparamos y con la altura
    jge .step2                ; Si y >= altura, vamos al paso 2
    
    xor r13, r13              ; x = 0 (inicio de cada fila)
    
.loop_x1:
    cmp r13, r8               ; Comparamos x con el ancho
    jge .next_y1              ; Si x >= ancho, pasamos a la siguiente fila
    
    ; Calcular offset de entrada: y * ancho + x
    mov rax, r12
    mul r8
    add rax, r13
    
    ; Obtener píxel origen
    movzx rbx, byte [rsi + rax]
    
    ; Calcular offset de salida: (2*y) * ancho_salida + (2*x)
    ; Esto coloca el píxel original en su posición correspondiente en la imagen ampliada
    mov rax, r12
    shl rax, 1                ; 2*y
    mul r10                   ; * ancho_salida
    mov rdx, r13
    shl rdx, 1                ; 2*x
    add rax, rdx
    
    ; Escribir en la salida
    mov byte [rdi + rax], bl
    
    inc r13                   ; x++ (siguiente columna)
    jmp .loop_x1
    
.next_y1:
    inc r12                   ; y++ (siguiente fila)
    jmp .loop_y1
    
    ; Paso 2: Interpolar píxeles horizontales con promedio ponderado
    ; Aquí calculamos los píxeles que están entre dos píxeles originales en dirección horizontal
.step2:
    xor r12, r12              ; y = 0
    
.loop_y2:
    cmp r12, r9               ; Comparamos y con la altura
    jge .step3                ; Si y >= altura, vamos al paso 3
    
    xor r13, r13              ; x = 0
    
.loop_x2:
    cmp r13, r8 - 1           ; Comparamos x con ancho-1
    jge .next_y2              ; Si x >= ancho-1, pasamos a la siguiente fila
    
    ; Calcular offsets de entrada
    mov rax, r12
    mul r8
    add rax, r13              ; offset = y*ancho + x
    
    ; Obtener píxeles izquierdo y derecho
    movzx r14, byte [rsi + rax]       ; píxel izquierdo
    inc rax
    movzx r15, byte [rsi + rax]       ; píxel derecho
    
    ; Aplicar interpolación ponderada: izquierdo*2/3 + derecho*1/3
    ; Damos más peso al píxel más cercano (como indica la especificación)
    mov rbx, r14              ; Copiar izquierdo a rbx
    shl rbx, 1                ; izquierdo * 2
    add rbx, r15              ; izquierdo*2 + derecho
    mov rax, rbx
    xor rdx, rdx              ; Limpiamos rdx para la división
    mov rbx, 3
    div rbx                   ; (izquierdo*2 + derecho) / 3 = izquierdo*2/3 + derecho*1/3
    
    ; Guardar valor interpolado temporalmente
    push rax
    
    ; Calcular offset de salida: (2*y) * ancho_salida + (2*x + 1)
    ; Esta posición corresponde al punto medio entre dos píxeles originales
    mov rax, r12
    shl rax, 1                ; 2*y
    mul r10                   ; * ancho_salida
    mov rdx, r13
    shl rdx, 1                ; 2*x
    inc rdx                   ; 2*x + 1
    add rax, rdx
    
    pop rdx                   ; Restaurar valor interpolado a rdx
    
    ; Escribir píxel interpolado
    mov byte [rdi + rax], dl
    
    ; Obtener píxeles izquierdo y derecho nuevamente para el segundo punto de interpolación
    mov rax, r12
    mul r8
    add rax, r13
    movzx r14, byte [rsi + rax]       ; píxel izquierdo
    inc rax
    movzx r15, byte [rsi + rax]       ; píxel derecho
    
    ; Aplicar interpolación ponderada: izquierdo*1/3 + derecho*2/3
    ; Para el segundo punto horizontal usamos ponderación inversa
    mov rbx, r15              ; Copiar derecho a rbx
    shl rbx, 1                ; derecho * 2
    add rbx, r14              ; derecho*2 + izquierdo
    mov rax, rbx
    xor rdx, rdx              ; Limpiamos rdx para la división
    mov rbx, 3
    div rbx                   ; (derecho*2 + izquierdo) / 3 = derecho*2/3 + izquierdo*1/3
    
    ; Guardar valor interpolado temporalmente
    push rax
    
    ; Calcular offset para el segundo píxel horizontal: (2*y) * ancho_salida + (2*x + 3)
    mov rax, r12
    shl rax, 1                ; 2*y
    mul r10                   ; * ancho_salida
    mov rdx, r13
    shl rdx, 1                ; 2*x
    add rdx, 3                ; 2*x + 3
    add rax, rdx
    
    pop rdx                   ; Restaurar valor interpolado
    
    ; Escribir segundo píxel interpolado horizontal
    mov byte [rdi + rax], dl
    
    inc r13                   ; x++ (siguiente columna)
    jmp .loop_x2
    
.next_y2:
    inc r12                   ; y++ (siguiente fila)
    jmp .loop_y2
    
    ; Paso 3: Interpolar píxeles verticales con promedio ponderado
    ; Calculamos los píxeles intermedios en dirección vertical
.step3:
    xor r12, r12              ; y = 0
    
.loop_y3:
    cmp r12, r9 - 1           ; Comparamos y con altura-1
    jge .step4                ; Si y >= altura-1, vamos al paso 4
    
    xor r13, r13              ; x = 0
    
.loop_x3:
    cmp r13, r8               ; Comparamos x con ancho
    jge .next_y3              ; Si x >= ancho, siguiente fila
    
    ; Calcular offsets para píxeles superior e inferior
    mov rax, r12
    mul r8
    add rax, r13
    movzx r14, byte [rsi + rax]  ; píxel superior
    
    mov rax, r12
    inc rax
    mul r8
    add rax, r13
    movzx r15, byte [rsi + rax]  ; píxel inferior
    
    ; Aplicar interpolación ponderada: superior*2/3 + inferior*1/3
    ; Similar a la interpolación horizontal, pero en dirección vertical
    mov rbx, r14              ; Copiar superior a rbx
    shl rbx, 1                ; superior * 2
    add rbx, r15              ; superior*2 + inferior
    mov rax, rbx
    xor rdx, rdx              ; Limpiamos rdx para la división
    mov rbx, 3
    div rbx                   ; (superior*2 + inferior) / 3 = superior*2/3 + inferior*1/3
    
    ; Guardar valor interpolado temporalmente
    push rax
    
    ; Calcular offset de salida: (2*y + 1) * ancho_salida + (2*x)
    mov rax, r12
    shl rax, 1                ; 2*y
    inc rax                   ; 2*y + 1
    mul r10                   ; * ancho_salida
    mov rdx, r13
    shl rdx, 1                ; 2*x
    add rax, rdx
    
    pop rdx                   ; Restaurar valor interpolado
    
    ; Escribir píxel interpolado
    mov byte [rdi + rax], dl
    
    ; Obtener píxeles superior e inferior nuevamente para el segundo punto de interpolación
    mov rax, r12
    mul r8
    add rax, r13
    movzx r14, byte [rsi + rax]  ; píxel superior
    
    mov rax, r12
    inc rax
    mul r8
    add rax, r13
    movzx r15, byte [rsi + rax]  ; píxel inferior
    
    ; Aplicar interpolación ponderada: superior*1/3 + inferior*2/3
    ; Para el segundo punto vertical usamos ponderación inversa
    mov rbx, r15              ; Copiar inferior a rbx
    shl rbx, 1                ; inferior * 2
    add rbx, r14              ; inferior*2 + superior
    mov rax, rbx
    xor rdx, rdx              ; Limpiamos rdx para la división
    mov rbx, 3
    div rbx                   ; (inferior*2 + superior) / 3 = inferior*2/3 + superior*1/3
    
    ; Guardar valor interpolado temporalmente
    push rax
    
    ; Calcular offset para segundo píxel vertical: (2*y + 3) * ancho_salida + (2*x)
    mov rax, r12
    shl rax, 1                ; 2*y
    add rax, 3                ; 2*y + 3
    mul r10                   ; * ancho_salida
    mov rdx, r13
    shl rdx, 1                ; 2*x
    add rax, rdx
    
    pop rdx                   ; Restaurar valor interpolado
    
    ; Escribir segundo píxel interpolado vertical
    mov byte [rdi + rax], dl
    
    inc r13                   ; x++ (siguiente columna)
    jmp .loop_x3
    
.next_y3:
    inc r12                   ; y++ (siguiente fila)
    jmp .loop_y3
    
    ; Paso 4: Interpolar píxeles diagonales usando los píxeles horizontales y verticales ya interpolados
    ; Esta es la parte más compleja: rellenamos los "huecos" centrales entre 4 píxeles originales
.step4:
    xor r12, r12              ; y = 0
    
.loop_y4:
    cmp r12, r9 - 1           ; Comparamos y con altura-1
    jge .done                 ; Si y >= altura-1, hemos terminado
    
    xor r13, r13              ; x = 0
    
.loop_x4:
    cmp r13, r8 - 1           ; Comparamos x con ancho-1
    jge .next_y4              ; Si x >= ancho-1, siguiente fila
    
    ; Obtener píxeles horizontales interpolados
    mov rax, r12
    shl rax, 1                ; 2*y
    mul r10                   ; * ancho_salida
    mov rdx, r13
    shl rdx, 1                ; 2*x
    inc rdx                   ; 2*x + 1
    add rax, rdx
    movzx r14, byte [rdi + rax]    ; superior-horizontal
    
    ; Calcular offset para inferior-horizontal
    push r14                      ; Guardar valor superior-horizontal
    
    mov rax, r12
    shl rax, 1                    ; 2*y
    add rax, 2                    ; 2*y + 2
    mul r10                       ; * ancho_salida
    mov rdx, r13
    shl rdx, 1                    ; 2*x
    inc rdx                       ; 2*x + 1
    add rax, rdx
    movzx r15, byte [rdi + rax]   ; inferior-horizontal
    
    pop r14                       ; Restaurar valor superior-horizontal
    
    ; Aplicar interpolación ponderada para diagonal: superior-horizontal*2/3 + inferior-horizontal*1/3
    ; Similar a las interpolaciones anteriores pero usando valores ya interpolados
    mov rbx, r14              ; Copiar superior-horizontal a rbx
    shl rbx, 1                ; superior-horizontal * 2
    add rbx, r15              ; superior-horizontal*2 + inferior-horizontal
    mov rax, rbx
    xor rdx, rdx              ; Limpiamos rdx para la división
    mov rbx, 3
    div rbx                   ; (superior-horizontal*2 + inferior-horizontal) / 3
    
    ; Guardar valor interpolado temporalmente
    push rax
    
    ; Calcular offset de salida: (2*y + 1) * ancho_salida + (2*x + 1)
    ; Esta posición corresponde al centro de un cuadrado de 2x2 en la imagen original
    mov rax, r12
    shl rax, 1                ; 2*y
    inc rax                   ; 2*y + 1
    mul r10                   ; * ancho_salida
    mov rdx, r13
    shl rdx, 1                ; 2*x
    inc rdx                   ; 2*x + 1
    add rax, rdx
    
    pop rdx                   ; Restaurar valor interpolado
    
    ; Escribir píxel diagonal (centro del cuadrado)
    mov byte [rdi + rax], dl
    
    inc r13                   ; x++ (siguiente columna)
    jmp .loop_x4
    
.next_y4:
    inc r12                   ; y++ (siguiente fila)
    jmp .loop_y4
    
.done:
    ; Restaurar registros
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret