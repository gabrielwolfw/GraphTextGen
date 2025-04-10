from PIL import Image
import numpy as np
import struct

def convert_img_to_png(input_img_path, output_image_path):
    with open(input_img_path, 'rb') as f:
        # Leer el encabezado (ancho, alto y canales)
        width, height, num_channels = struct.unpack('III', f.read(12))
        
        # Leer los datos de píxeles
        pixel_data = np.fromfile(f, dtype=np.uint8, count=width * height * num_channels)
        
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

if __name__ == "__main__":
    input_img_path = "input_quadrant.img"
    output_image_path = "converted_image.png"
    convert_img_to_png(input_img_path, output_image_path)
    print(f"Imagen convertida a {output_image_path}")
