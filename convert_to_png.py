from PIL import Image
import numpy as np
import struct

def convert_img_to_png(input_img_path, output_image_path):
    # Read the .img file
    with open(input_img_path, 'rb') as f:
        # Read the header (width, height, and number of channels)
        width, height, num_channels = struct.unpack('III', f.read(12))
        
        # Read the pixel data
        pixel_data = np.fromfile(f, dtype=np.uint8, count=width*height*num_channels).reshape((height, width, num_channels))
        
        # Create an image from the pixel data
        img = Image.fromarray(pixel_data, 'RGB')
        
        # Save the image as a .png file
        img.save(output_image_path)

if __name__ == "__main__":
    input_img_path = "output_image.img"  # Replace with your input .img file path
    output_image_path = "converted_image.png"  # Replace with your desired output .png file path
    
    convert_img_to_png(input_img_path, output_image_path)
    print(f"Image converted to {output_image_path}")