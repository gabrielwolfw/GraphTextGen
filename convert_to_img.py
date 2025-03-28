from PIL import Image
import numpy as np
import struct

def convert_image_to_img(input_image_path, output_img_path):
    # Open the image file
    with Image.open(input_image_path) as img:
        # Convert the image to grayscale
        img = img.convert('L')
        
        # Get image dimensions
        width, height = img.size
        
        # Get image data as a numpy array
        pixel_data = np.array(img)
        
        # Create the .img file
        with open(output_img_path, 'wb') as f:
            # Write the header (width and height)
            f.write(struct.pack('II', width, height))
            
            # Write the pixel data
            pixel_data.tofile(f)

if __name__ == "__main__":
    # Example usage
    input_image_path = "input_image.png"  # Replace with your input image path
    output_img_path = "output_image.img"  # Replace with your desired output .img file path
    
    convert_image_to_img(input_image_path, output_img_path)
    print(f"Image converted to {output_img_path}")