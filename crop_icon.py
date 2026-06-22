import os
from PIL import Image

def crop_and_center_logo(img_path, save_path, target_size=1024, crop_factor=0.82, padding_ratio=0.18):
    try:
        img = Image.open(img_path)
        if img.mode != 'RGB':
            img = img.convert('RGB')
            
        width, height = img.size
        
        # 1. First, crop the central core logo to remove any raw edges or frames
        new_width = int(width * crop_factor)
        new_height = int(height * crop_factor)
        
        left = (width - new_width) // 2
        top = (height - new_height) // 2
        right = (width + new_width) // 2
        bottom = (height + new_height) // 2
        
        cropped_logo = img.crop((left, top, right, bottom))
        
        # 2. Resize the logo so it fits comfortably inside the adaptive icon safe-zone (typically 65% of the total size)
        target_logo_size = int(target_size * (1.0 - 2.0 * padding_ratio)) # ~655x655
        
        # Scale preserving aspect ratio
        c_width, c_height = cropped_logo.size
        scale_ratio = min(target_logo_size / c_width, target_logo_size / c_height)
        resized_logo_width = int(c_width * scale_ratio)
        resized_logo_height = int(c_height * scale_ratio)
        
        resized_logo = cropped_logo.resize((resized_logo_width, resized_logo_height), Image.LANCZOS)
        
        # 3. Create a background canvas matching Nexsync's theme.
        # We will use Slate-950/Obsidian Dark (#090D16) for a premium tech vibe.
        background_color = (9, 13, 22)
        background = Image.new('RGB', (target_size, target_size), background_color)
        
        # 4. Paste the logo in the center
        offset_x = (target_size - resized_logo_width) // 2
        offset_y = (target_size - resized_logo_height) // 2
        background.paste(resized_logo, (offset_x, offset_y))
        
        # 5. Save the output
        background.save(save_path, 'PNG')
        print(f"Successfully generated a perfectly cropped and padded logo at {save_path}")
        
    except Exception as e:
        print(f"Error cropping icon: {e}")

# Use the generated image path
input_path = r"C:\Users\MALIK\.gemini\antigravity-ide\brain\39ee0b4a-7891-4e86-aa37-2461e159439e\icon_nexsync_refined_1781051269626.png"
output_path = r"d:\Ai models\IRIS\assets\nexsync_logo.png"

crop_and_center_logo(input_path, output_path)
