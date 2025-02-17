# simple_icon_generator.py
# -----------------------------------------------------
# A Minimal Modern Approach with Just PIL
# -----------------------------------------------------
# This script creates a clean icon with a gradient background,
# some simple geometry, and optional text—no "funky chaos."
# Usage:
#   1) pip install Pillow
#   2) python simple_icon_generator.py
#   3) Look for SystemSentinel.ico in the same folder.

import os
from PIL import Image, ImageDraw, ImageFont

def create_icon(icon_size=256, background_start=(100, 100, 200), background_end=(180, 180, 255)):
    """
    Creates a 256x256 (default) RGBA image with:
      - A vertical gradient background
      - A central shape
      - An optional text overlay
    Returns the PIL Image.
    """
    # 1. Create blank canvas
    img = Image.new("RGBA", (icon_size, icon_size), (255, 255, 255, 0))
    draw = ImageDraw.Draw(img, "RGBA")

    # 2. Draw background gradient
    for y in range(icon_size):
        # Interpolate between background_start and background_end
        ratio = y / float(icon_size - 1) if icon_size > 1 else 0
        r = int(background_start[0] + (background_end[0] - background_start[0]) * ratio)
        g = int(background_start[1] + (background_end[1] - background_start[1]) * ratio)
        b = int(background_start[2] + (background_end[2] - background_start[2]) * ratio)
        draw.line([(0, y), (icon_size, y)], fill=(r, g, b, 255))

    # 3. Draw a simple shape (e.g., circle) in the center
    padding = icon_size // 6
    shape_box = [padding, padding, icon_size - padding, icon_size - padding]
    shape_color = (0, 120, 220, 180)
    draw.ellipse(shape_box, fill=shape_color)

    # 4. Optional text overlay
    try:
        font = ImageFont.truetype("arial.ttf", icon_size // 5)
    except OSError:
        # Fallback if arial.ttf isn't available
        font = ImageFont.load_default()

    text = "S"  # "S" for Sentinel
    bbox = draw.textbbox((0, 0), text, font=font)
    text_w, text_h = bbox[2] - bbox[0], bbox[3] - bbox[1]
    text_pos = ((icon_size - text_w) // 2, (icon_size - text_h) // 2)
    draw.text(text_pos, text, font=font, fill=(255, 255, 255, 255))

    return img

def save_as_ico(img, filename="SystemSentinel.ico"):
    """
    Saves the image as .ico with typical sizes.
    (16, 24, 32, 48, 64, 128, 256)
    """
    sizes = [(size, size) for size in [16, 24, 32, 48, 64, 128, 256] if size <= img.size[0]]
    # If your base image is 256 or higher, Pillow will downscale accordingly.
    img.save(filename, format="ICO", sizes=sizes)

if __name__ == "__main__":
    # 1. Create a simple icon
    icon_image = create_icon(icon_size=256)

    # 2. Save it as an .ico file in the script's folder
    script_dir = os.path.dirname(os.path.abspath(__file__))
    output_path = os.path.join(script_dir, "SystemSentinel.ico")
    save_as_ico(icon_image, output_path)

    print(f"Icon saved to: {output_path}")
