#!/usr/bin/env python3
"""
Remove white backgrounds from PNG images in lib/imgs/
Converts white pixels to transparent while preserving the icon/image content.
"""

from PIL import Image
import os

# List of images to process
images = [
    'lib/imgs/binyag.png',
    'lib/imgs/kasal.png',
    'lib/imgs/kumpil.png',
    'lib/imgs/misasayumao.png',
    'lib/imgs/pagpapahatidsamaysakit.png',
    'lib/imgs/basbassabahay.png',
    'lib/imgs/intensyonsamisa.png',
]

def remove_white_background(image_path):
    """Remove white background and make it transparent."""
    if not os.path.exists(image_path):
        print(f"❌ File not found: {image_path}")
        return False
    
    try:
        # Open image
        img = Image.open(image_path).convert('RGBA')
        
        # Get image data
        data = img.getdata()
        
        # Convert white (#FFFFFF or close to white) to transparent
        new_data = []
        for item in data:
            # If pixel is white or very close to white (R, G, B all > 240)
            if item[0] > 240 and item[1] > 240 and item[2] > 240:
                # Make transparent
                new_data.append((255, 255, 255, 0))
            else:
                new_data.append(item)
        
        # Update image
        img.putdata(new_data)
        
        # Save back
        img.save(image_path, 'PNG')
        print(f"✅ Processed: {image_path}")
        return True
        
    except Exception as e:
        print(f"❌ Error processing {image_path}: {e}")
        return False

if __name__ == '__main__':
    print("🎨 Removing white backgrounds from sacrament icons...\n")
    
    success_count = 0
    for image in images:
        if remove_white_background(image):
            success_count += 1
    
    print(f"\n✅ Complete! Processed {success_count}/{len(images)} images.")
