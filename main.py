import numpy as np
import matplotlib.pyplot as plt
from PIL import Image
import subprocess
import os
import struct
import time

def bilinear_framework(input_image_path, quadrant_number=1):
    """
    Framework completo para el procesamiento bilinear:
    1. Cargar imagen
    2. Seleccionar cuadrante
    3. Ejecutar interpolación bilineal en ensamblador
    4. Convertir resultado a PNG
    5. Mostrar resultados
    
    Args:
        input_image_path (str): Ruta de la imagen de entrada
        quadrant_number (int): Número de cuadrante (1-16)
    
    Returns:
        tuple: (ruta_imagen_original, ruta_imagen_cuadrante, ruta_imagen_interpolada)
    """
    print(f"=== Iniciando procesamiento bilineal para el cuadrante {quadrant_number} ===")
    
    # 1. Cargar la imagen de entrada
    try:
        original_img = Image.open(input_image_path).convert('L')  # Convertir a escala de grises
        img_array = np.array(original_img)
        height, width = img_array.shape
        
        print(f"Imagen cargada: {width}x{height} píxeles")
        
        # Verificar que la imagen cumple con el requisito mínimo de 390x390
        if width < 390 or height < 390:
            print(f"ADVERTENCIA: La imagen es menor que 390x390 ({width}x{height})")
    
    except Exception as e:
        print(f"Error al cargar la imagen: {e}")
        return None, None, None
    
    # 2. Seleccionar el cuadrante
    if not 1 <= quadrant_number <= 16:
        print(f"Error: El número de cuadrante debe estar entre 1 y 16. Se recibió: {quadrant_number}")
        return None, None, None
    
    # Calcular las dimensiones de cada cuadrante
    quad_width = width // 4
    quad_height = height // 4
    
    # Calcular la posición del cuadrante
    row = (quadrant_number - 1) // 4
    col = (quadrant_number - 1) % 4
    
    # Extraer el cuadrante
    y_start = row * quad_height
    y_end = (row + 1) * quad_height
    x_start = col * quad_width
    x_end = (col + 1) * quad_width
    
    quadrant = img_array[y_start:y_end, x_start:x_end]
    
    print(f"Cuadrante seleccionado: {quadrant.shape[1]}x{quadrant.shape[0]} píxeles")
    print(f"Posición: fila {row+1}, columna {col+1}")
    
    # Guardar el cuadrante como archivo PNG (NUEVO)
    quadrant_png = "original_quadrant.png"
    Image.fromarray(quadrant).save(quadrant_png)
    print(f"Cuadrante guardado como {quadrant_png}")
    
    # Guardar el cuadrante como archivo .img con encabezado
    quadrant_file = "input_quadrant.img"
    
    with open(quadrant_file, 'wb') as f:
        # No necesitamos escribir un encabezado aquí, solo los datos crudos
        # ya que nuestro código ASM no espera un encabezado en la entrada
        f.write(quadrant.tobytes())
    
    print(f"Cuadrante guardado como {quadrant_file}")
    
    # 3. Ejecutar el programa de ensamblador
    try:
        print("Ejecutando el programa de interpolación bilineal en ensamblador...")
        
        # Verificar si el ejecutable existe, si no, compilarlo
        if not os.path.exists("bilinear_interpolation"):
            print("Compilando el programa de ensamblador...")
            subprocess.run(["nasm", "-f", "elf64", "bilinear_interpolation.asm", "-o", "bilinear_interpolation.o"], check=True)
            subprocess.run(["ld", "bilinear_interpolation.o", "-o", "bilinear_interpolation"], check=True)
        
        # Ejecutar el programa
        result = subprocess.run(["./bilinear_interpolation"], check=True)
        
        if result.returncode == 0:
            print("Interpolación bilineal completada exitosamente")
        else:
            print(f"Error al ejecutar la interpolación bilineal: código de salida {result.returncode}")
            return None, None, None
            
    except Exception as e:
        print(f"Error al ejecutar el programa de ensamblador: {e}")
        return None, None, None
    
    # 4. Convertir el resultado a PNG
    try:
        print("Convirtiendo resultado a PNG...")
        output_img_path = "converted_image.png"
        
        # Leer el archivo .img con encabezado generado por el ensamblador
        with open("result.img", 'rb') as f:
            # Leer encabezado (ancho, alto, canales)
            header_data = f.read(12)
            if len(header_data) != 12:
                raise ValueError("No se pudo leer el encabezado completo")
            
            width, height, num_channels = struct.unpack('III', header_data)
            print(f"Dimensiones detectadas: {width}x{height}, {num_channels} canales")
            
            # Verificar dimensiones
            if width <= 0 or width > 10000 or height <= 0 or height > 10000 or num_channels <= 0 or num_channels > 4:
                raise ValueError(f"Dimensiones inválidas: {width}x{height}x{num_channels}")
            
            # Leer datos de píxeles
            expected_size = width * height * num_channels
            pixel_data = np.fromfile(f, dtype=np.uint8, count=expected_size)
            
            # Crear imagen
            if num_channels == 1:
                pixel_data = pixel_data.reshape((height, width))
                img = Image.fromarray(pixel_data, mode='L')
            else:
                pixel_data = pixel_data.reshape((height, width, num_channels))
                img = Image.fromarray(pixel_data, mode='RGB' if num_channels == 3 else 'RGBA')
            
            # Guardar como PNG
            img.save(output_img_path)
            print(f"Imagen convertida exitosamente a {output_img_path}")
    
    except Exception as e:
        print(f"Error al convertir el resultado a PNG: {e}")
        print("Intentando recuperación...")
        
        try:
            # Intento de recuperación: leer como datos crudos
            with open("result.img", 'rb') as f:
                # Intentamos saltar los primeros 12 bytes (encabezado)
                f.seek(12)
                # Asumimos dimensiones basadas en el cuadrante original x 2
                width = quadrant.shape[1] * 2
                height = quadrant.shape[0] * 2
                
                pixel_data = np.fromfile(f, dtype=np.uint8)
                
                if len(pixel_data) >= width * height:
                    pixel_data = pixel_data[:width * height]
                    pixel_data = pixel_data.reshape((height, width))
                    img = Image.fromarray(pixel_data, mode='L')
                    output_img_path = "recovered_image.png"
                    img.save(output_img_path)
                    print(f"Recuperación exitosa. Imagen guardada como {output_img_path}")
                else:
                    print(f"No hay suficientes datos. Se necesitan {width*height} bytes, pero hay {len(pixel_data)}")
                    return None, None, None
        
        except Exception as recovery_error:
            print(f"Error en recuperación: {recovery_error}")
            return None, None, None
    
    # 5. Mostrar los resultados
    fig, axs = plt.subplots(1, 3, figsize=(15, 5))
    
    # Imagen original con cuadrante marcado
    axs[0].imshow(np.array(original_img), cmap='gray')
    axs[0].set_title("Imagen Original")
    
    # Dibujar rectángulo alrededor del cuadrante seleccionado
    rect = plt.Rectangle((x_start, y_start), quad_width, quad_height, 
                        linewidth=2, edgecolor='r', facecolor='none')
    axs[0].add_patch(rect)
    
    # Mostrar el cuadrante seleccionado
    axs[1].imshow(quadrant, cmap='gray')
    axs[1].set_title(f"Cuadrante #{quadrant_number}")
    
    # Mostrar el resultado interpolado
    result_img = Image.open(output_img_path)
    axs[2].imshow(np.array(result_img), cmap='gray')
    axs[2].set_title("Resultado Interpolado")
    
    for ax in axs:
        ax.axis('off')
    
    plt.tight_layout()
    fig.savefig("bilinear_results.png")
    plt.show()
    
    print("=== Procesamiento completado ===")
    
    # Actualizar el valor de retorno para incluir la ruta del PNG del cuadrante
    return input_image_path, quadrant_png, output_img_path

def main():
    # Ruta de la imagen de entrada
    input_image = input("Ingrese la ruta de la imagen de entrada (o presione Enter para usar 'input_image.png'): ").strip()
    if not input_image:
        input_image = "input_image.png"
    
    # Verificar que el archivo existe
    if not os.path.exists(input_image):
        print(f"Error: El archivo '{input_image}' no existe.")
        return
    
    # Seleccionar cuadrante
    try:
        quadrant = int(input("Seleccione el cuadrante (1-16): "))
        if not 1 <= quadrant <= 16:
            print("Error: El cuadrante debe estar entre 1 y 16.")
            return
    except ValueError:
        print("Error: Debe ingresar un número válido.")
        return
    
    # Ejecutar el framework
    bilinear_framework(input_image, quadrant)

# Ejecutar el script
if __name__ == "__main__":
    main()