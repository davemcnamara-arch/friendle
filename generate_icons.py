#!/usr/bin/env python3
"""
Generate PWA icons for Friendle app with a modern design.
Creates icons with a stylized 'F' inside a circle with purple gradient.
"""

from PIL import Image, ImageDraw, ImageFont
import math

# Theme colors from Friendle
PRIMARY_COLOR = "#5b4fc7"  # Main purple
GRADIENT_START = "#5b4fc7"
GRADIENT_END = "#6d3a9f"

def hex_to_rgb(hex_color):
    """Convert hex color to RGB tuple"""
    hex_color = hex_color.lstrip('#')
    return tuple(int(hex_color[i:i+2], 16) for i in (0, 2, 4))

def create_gradient(width, height, start_color, end_color):
    """Create a gradient background"""
    base = Image.new('RGB', (width, height), start_color)
    top = Image.new('RGB', (width, height), end_color)
    mask = Image.new('L', (width, height))
    mask_data = []
    for y in range(height):
        for x in range(width):
            # Diagonal gradient
            distance = math.sqrt((x/width)**2 + (y/height)**2)
            mask_data.append(int(distance * 255 / math.sqrt(2)))
    mask.putdata(mask_data)
    base.paste(top, (0, 0), mask)
    return base

def draw_rounded_rectangle(draw, xy, radius, fill):
    """Draw a rounded rectangle"""
    x1, y1, x2, y2 = xy
    draw.rectangle([x1 + radius, y1, x2 - radius, y2], fill=fill)
    draw.rectangle([x1, y1 + radius, x2, y2 - radius], fill=fill)
    draw.pieslice([x1, y1, x1 + radius * 2, y1 + radius * 2], 180, 270, fill=fill)
    draw.pieslice([x2 - radius * 2, y1, x2, y1 + radius * 2], 270, 360, fill=fill)
    draw.pieslice([x1, y2 - radius * 2, x1 + radius * 2, y2], 90, 180, fill=fill)
    draw.pieslice([x2 - radius * 2, y2 - radius * 2, x2, y2], 0, 90, fill=fill)

def create_icon(size, maskable=False):
    """Create a Friendle icon with F logo inside a circle"""
    # Create transparent base
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img, 'RGBA')

    # Calculate safe zone for maskable icons
    # Android masks to a circle in the center 80% of the icon
    safe_zone_padding = int(size * 0.1) if maskable else int(size * 0.05)
    effective_size = size - (2 * safe_zone_padding)
    offset = safe_zone_padding

    # Design parameters (scaled to effective size)
    scale = effective_size / 512
    center_x = size / 2
    center_y = size / 2
    circle_radius = effective_size / 2

    # Create gradient circle background
    # We'll draw the gradient onto the circle
    start_rgb = hex_to_rgb(GRADIENT_START)
    end_rgb = hex_to_rgb(GRADIENT_END)

    # Draw gradient circle
    for r in range(int(circle_radius), 0, -1):
        # Calculate gradient color based on radius
        ratio = (circle_radius - r) / circle_radius
        color = tuple(int(start_rgb[i] + (end_rgb[i] - start_rgb[i]) * ratio) for i in range(3))
        draw.ellipse([
            center_x - r,
            center_y - r,
            center_x + r,
            center_y + r
        ], fill=color)

    # Draw main "F" logo with modern styling
    # The F is constructed using rectangles to be clean and geometric
    white = (255, 255, 255, 255)

    # F parameters - slightly smaller to fit nicely in circle
    f_width = int(160 * scale)
    f_height = int(280 * scale)
    f_thickness = int(45 * scale)
    f_x = int(center_x - f_width / 2)
    f_y = int(center_y - f_height / 2)

    # Vertical stem of F
    draw_rounded_rectangle(
        draw,
        [f_x, f_y, f_x + f_thickness, f_y + f_height],
        int(f_thickness * 0.3),
        white
    )

    # Top horizontal bar of F
    draw_rounded_rectangle(
        draw,
        [f_x, f_y, f_x + f_width, f_y + f_thickness],
        int(f_thickness * 0.3),
        white
    )

    # Middle horizontal bar of F (shorter)
    mid_bar_width = int(f_width * 0.75)
    mid_bar_y = f_y + int(f_height * 0.45)
    draw_rounded_rectangle(
        draw,
        [f_x, mid_bar_y, f_x + mid_bar_width, mid_bar_y + f_thickness],
        int(f_thickness * 0.3),
        white
    )

    return img

def main():
    """Generate all required icon sizes"""
    print("Generating Friendle PWA icons with F in circle design...")

    # Generate standard icons
    print("Creating 512x512 icon...")
    icon_512 = create_icon(512, maskable=False)
    icon_512.save('icon-512.png', 'PNG', optimize=True)

    print("Creating 192x192 icon...")
    icon_192 = create_icon(192, maskable=False)
    icon_192.save('icon-192.png', 'PNG', optimize=True)

    # Generate maskable icons (with safe zone for Android adaptive icons)
    print("Creating 512x512 maskable icon...")
    maskable_512 = create_icon(512, maskable=True)
    maskable_512.save('icon-512-maskable.png', 'PNG', optimize=True)

    print("Creating 192x192 maskable icon...")
    maskable_192 = create_icon(192, maskable=True)
    maskable_192.save('icon-192-maskable.png', 'PNG', optimize=True)

    # Also generate additional common sizes
    print("Creating 384x384 icon...")
    icon_384 = create_icon(384, maskable=False)
    icon_384.save('icon-384.png', 'PNG', optimize=True)

    print("Creating 384x384 maskable icon...")
    maskable_384 = create_icon(384, maskable=True)
    maskable_384.save('icon-384-maskable.png', 'PNG', optimize=True)

    # Generate Apple Touch Icon (doesn't need maskable)
    print("Creating 180x180 Apple Touch Icon...")
    icon_180 = create_icon(180, maskable=False)
    icon_180.save('apple-touch-icon.png', 'PNG', optimize=True)

    print("\nAll icons generated successfully!")
    print("Generated files:")
    print("  - icon-192.png (standard)")
    print("  - icon-384.png (standard)")
    print("  - icon-512.png (standard)")
    print("  - icon-192-maskable.png (Android adaptive)")
    print("  - icon-384-maskable.png (Android adaptive)")
    print("  - icon-512-maskable.png (Android adaptive)")
    print("  - apple-touch-icon.png (iOS)")

if __name__ == '__main__':
    main()
