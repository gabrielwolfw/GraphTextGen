from PIL import Image
import numpy as np
import struct

def convert_img_to_png(input_img_path, output_image_path):
    try:
        with open(input_img_path, 'rb') as f:
            # Leer el encabezado (ancho, alto y canales)
            header_data = f.read(12)
            if len(header_data) != 12:
                raise ValueError("No se pudo leer el encabezado completo")
                
            width, height, num_channels = struct.unpack('III', header_data)
            print(f"Dimensiones detectadas: {width}x{height}, {num_channels} canales")
            
            # Verificar que las dimensiones sean razonables
            if width <= 0 or width > 10000 or height <= 0 or height > 10000 or num_channels <= 0 or num_channels > 4:
                raise ValueError(f"Dimensiones inválidas: {width}x{height}x{num_channels}")
            
            # Calcular el tamaño esperado de datos
            expected_size = width * height * num_channels
            print(f"Tamaño esperado de datos: {expected_size} bytes")
            
            # Leer los datos de píxeles
            pixel_data = np.fromfile(f, dtype=np.uint8, count=expected_size)
            
            # Verificar que se leyeron todos los datos esperados
            if len(pixel_data) != expected_size:
                print(f"Advertencia: Se esperaban {expected_size} bytes, pero se leyeron {len(pixel_data)} bytes")
            
            if num_channels == 1:
                # Imagen en escala de grises
                pixel_data = pixel_data.reshape((height, width))
                img = Image.fromarray(pixel_data, mode='L')
            elif num_channels == 3:
                # Imagen RGB
                pixel_data = pixel_data.reshape((height, width, 3))
                img = Image.fromarray(pixel_data, mode='RGB')
            else:
                raise ValueError(f"Número de canales no soportado: {num_channels}")
            
            # Guardar como .png
            img.save(output_image_path)
            print(f"Imagen convertida exitosamente a {output_image_path}")
            
    except Exception as e:
        print(f"Error al procesar la imagen: {e}")
        
        # Intento de recuperación: intentar leer como datos crudos sin encabezado
        try:
            print("Intentando leer como datos crudos sin encabezado...")
            with open(input_img_path, 'rb') as f:
                # Asumimos que es una imagen en escala de grises de 360x354
                width, height = 360, 354
                pixel_data = np.fromfile(f, dtype=np.uint8)
                
                # Verificar si hay suficientes datos para la imagen
                if len(pixel_data) >= width * height:
                    pixel_data = pixel_data[:width * height]  # Tomar solo los datos necesarios
                    pixel_data = pixel_data.reshape((height, width))
                    img = Image.fromarray(pixel_data, mode='L')
                    recovery_path = output_image_path.replace('.png', '_recovery.png')
                    img.save(recovery_path)
                    print(f"Recuperación exitosa. Imagen guardada como {recovery_path}")
                else:
                    print(f"No hay suficientes datos en el archivo. Se necesitan {width*height} bytes, pero solo hay {len(pixel_data)}.")
        except Exception as recovery_error:
            print(f"Error en intento de recuperación: {recovery_error}")

if __name__ == "__main__":
    input_img_path = "result.img"
    output_image_path = "converted_image.png"
    convert_img_to_png(input_img_path, output_image_path)