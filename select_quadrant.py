from PIL import Image
import numpy as np
import struct

def divide_image_into_quadrants(img):
    width, height = img.size
    quadrant_width = width // 4
    quadrant_height = height // 4

    quadrants = []
    for i in range(4):
        for j in range(4):
            left = j * quadrant_width
            upper = i * quadrant_height
            right = left + quadrant_width
            lower = upper + quadrant_height
            quadrant = img.crop((left, upper, right, lower))
            quadrants.append(quadrant)

    return quadrants

def select_quadrant_from_console():
    print("Select a quadrant (1-16):")
    for i in range(16):
        print(f"{i+1}. Quadrant {i+1}")
    
    selection = int(input("Enter the quadrant number: ")) - 1
    if selection < 0 or selection >= 16:
        print("Invalid selection. Please select a number between 1 and 16.")
        return select_quadrant_from_console()
    
    return selection

def convert_quadrant_to_img(quadrant, output_img_path):
    width, height = quadrant.size
    pixel_data = np.array(quadrant)
    
    with open(output_img_path, 'wb') as f:
        f.write(struct.pack('III', width, height, 3))
        pixel_data.tofile(f)

if __name__ == "__main__":
    input_image_path = "input_image.png"
    output_img_path = "selected_quadrant.img"
    
    with Image.open(input_image_path) as img:
        img = img.convert('RGB')
        quadrants = divide_image_into_quadrants(img)
        selected_quadrant_index = select_quadrant_from_console()
        selected_quadrant = quadrants[selected_quadrant_index]
        convert_quadrant_to_img(selected_quadrant, output_img_path)
        print(f"Selected quadrant saved to {output_img_path}")