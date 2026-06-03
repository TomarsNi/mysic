#!/usr/bin/env python3
"""
Mysic App Icon & Splash Image Generator

Design System:
- Surface: #18181b (dark background)
- Card: #27272a
- Accent: #10b981 (emerald green)
- Typography: Inter

Icon Design:
- Vinyl disc with concentric grooves
- Accent green center hole (like a record label)
- Sound wave arcs emanating from disc
- Rounded corners for iOS/Android adaptive icon style
"""

import os
from PIL import Image, ImageDraw

# Design colors
SURFACE = (0x18, 0x18, 0x1b)
CARD = (0x27, 0x27, 0x2a)
ACCENT = (0x10, 0xb9, 0x81)
ACCENT_LIGHT = (0x34, 0xd3, 0x99)
GROOVE = (0x3f, 0x3f, 0x46)


def create_app_icon(size: int) -> Image.Image:
    """
    Create app icon with vinyl disc design.

    Design elements:
    - Dark rounded background
    - Vinyl disc with grooves
    - Accent green center hole
    - Sound wave arcs
    """
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    center = size / 2
    r = size

    # Rounded rectangle background
    border_radius = int(size * 0.22)
    draw.rounded_rectangle(
        [(0, 0), (size, size)],
        radius=border_radius,
        fill=(*SURFACE, 255)
    )

    # Disc parameters
    disc_radius = r * 0.38
    disc_center = center

    # Disc outer ring (card color)
    draw.ellipse(
        [center - disc_radius * 1.05, center - disc_radius * 1.05,
         center + disc_radius * 1.05, center + disc_radius * 1.05],
        fill=(*CARD, 255)
    )

    # Disc body with gradient effect (from outer to inner)
    for i in range(int(disc_radius), 0, -1):
        t = i / disc_radius
        shade = (
            int(0x18 + (0x27 - 0x18) * t),
            int(0x18 + (0x27 - 0x18) * t),
            int(0x1b + (0x2a - 0x1b) * t),
        )
        draw.ellipse(
            [center - i, center - i, center + i, center + i],
            fill=(*shade, 255)
        )

    # Vinyl grooves (concentric circles)
    for ratio in [0.3, 0.38, 0.46, 0.54, 0.62, 0.70, 0.78, 0.86, 0.94]:
        groove_radius = disc_radius * ratio
        draw.ellipse(
            [center - groove_radius, center - groove_radius,
             center + groove_radius, center + groove_radius],
            outline=(*GROOVE, 64),
            width=max(1, int(size * 0.005))
        )

    # Accent glow around center
    glow_radius = disc_radius * 0.35
    for i in range(int(glow_radius), 0, -1):
        t = i / glow_radius
        alpha = int(0x30 * (1 - t))
        # Draw glow as semi-transparent circles
        draw.ellipse(
            [center - i, center - i, center + i, center + i],
            fill=(*ACCENT, alpha)
        )

    # Center hole (accent green)
    hole_radius = disc_radius * 0.18
    draw.ellipse(
        [center - hole_radius, center - hole_radius,
         center + hole_radius, center + hole_radius],
        fill=(*ACCENT, 255)
    )

    # Inner hole (lighter accent)
    inner_hole_radius = hole_radius * 0.5
    draw.ellipse(
        [center - inner_hole_radius, center - inner_hole_radius,
         center + inner_hole_radius, center + inner_hole_radius],
        fill=(*ACCENT_LIGHT, 255)
    )

    # Sound wave arcs (right side)
    wave_start_x = center + disc_radius * 0.85
    wave_start_y = center - disc_radius * 0.3
    for w in range(3):
        wave_radius = disc_radius * (0.25 + w * 0.15)
        alpha = max(0x30, 0xff - w * 0x50)
        draw.arc(
            [wave_start_x - wave_radius, wave_start_y - wave_radius,
             wave_start_x + wave_radius, wave_start_y + wave_radius],
            start=200, end=320,
            fill=(*ACCENT, alpha),
            width=max(2, int(size * 0.02))
        )

    return img


def create_splash_icon(size: int) -> Image.Image:
    """
    Create splash screen icon - larger, more detailed version.

    Design elements:
    - Transparent background (splash bg handled by native)
    - Larger vinyl disc
    - Sound waves on both sides
    - More pronounced glow effect
    """
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    center = size / 2
    r = size

    # Disc parameters - larger than app icon
    disc_radius = r * 0.35
    disc_center_y = center - r * 0.05  # Slightly above center

    # Disc outer ring
    draw.ellipse(
        [center - disc_radius * 1.08, disc_center_y - disc_radius * 1.08,
         center + disc_radius * 1.08, disc_center_y + disc_radius * 1.08],
        fill=(*CARD, 255)
    )

    # Disc body with gradient
    for i in range(int(disc_radius), 0, -1):
        t = i / disc_radius
        shade = (
            int(0x18 + (0x27 - 0x18) * t),
            int(0x18 + (0x27 - 0x18) * t),
            int(0x1b + (0x2a - 0x1b) * t),
        )
        draw.ellipse(
            [center - i, disc_center_y - i, center + i, disc_center_y + i],
            fill=(*shade, 255)
        )

    # Vinyl grooves
    for ratio in [0.28, 0.35, 0.42, 0.49, 0.56, 0.63, 0.70, 0.77, 0.84, 0.91]:
        groove_radius = disc_radius * ratio
        draw.ellipse(
            [center - groove_radius, disc_center_y - groove_radius,
             center + groove_radius, disc_center_y + groove_radius],
            outline=(*GROOVE, 53),
            width=max(1, int(size * 0.004))
        )

    # Accent glow
    glow_radius = disc_radius * 0.4
    for i in range(int(glow_radius), 0, -1):
        t = i / glow_radius
        alpha = int(0x25 * (1 - t))
        draw.ellipse(
            [center - i, disc_center_y - i, center + i, disc_center_y + i],
            fill=(*ACCENT, alpha)
        )

    # Center hole
    hole_radius = disc_radius * 0.18
    draw.ellipse(
        [center - hole_radius, disc_center_y - hole_radius,
         center + hole_radius, disc_center_y + hole_radius],
        fill=(*ACCENT, 255)
    )

    # Inner hole
    inner_hole_radius = hole_radius * 0.5
    draw.ellipse(
        [center - inner_hole_radius, disc_center_y - inner_hole_radius,
         center + inner_hole_radius, disc_center_y + inner_hole_radius],
        fill=(*ACCENT_LIGHT, 255)
    )

    # Sound wave arcs - right side
    wave_start_x = center + disc_radius * 0.8
    wave_start_y = disc_center_y - disc_radius * 0.35
    for w in range(3):
        wave_radius = disc_radius * (0.22 + w * 0.14)
        alpha = max(0x25, 0xff - w * 0x55)
        draw.arc(
            [wave_start_x - wave_radius, wave_start_y - wave_radius,
             wave_start_x + wave_radius, wave_start_y + wave_radius],
            start=200, end=320,
            fill=(*ACCENT, alpha),
            width=max(2, int(size * 0.018))
        )

    # Sound wave arcs - left side (fainter)
    wave_start_x2 = center - disc_radius * 0.8
    for w in range(2):
        wave_radius = disc_radius * (0.22 + w * 0.14)
        alpha = max(0x15, 0x80 - w * 0x30)
        draw.arc(
            [wave_start_x2 - wave_radius, wave_start_y - wave_radius,
             wave_start_x2 + wave_radius, wave_start_y + wave_radius],
            start=40, end=160,
            fill=(*ACCENT, alpha),
            width=max(2, int(size * 0.018))
        )

    return img


def main():
    base_path = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

    print("Generating Mysic app icons...")

    # === Android mipmap icons ===
    android_sizes = {
        'mipmap-mdpi': 48,
        'mipmap-hdpi': 72,
        'mipmap-xhdpi': 96,
        'mipmap-xxhdpi': 144,
        'mipmap-xxxhdpi': 192,
    }

    for folder, size in android_sizes.items():
        img = create_app_icon(size)
        dir_path = os.path.join(base_path, 'android', 'app', 'src', 'main', 'res', folder)
        os.makedirs(dir_path, exist_ok=True)
        img.save(os.path.join(dir_path, 'ic_launcher.png'))
        print(f"  Created: {folder}/ic_launcher.png ({size}x{size})")

    # === iOS AppIcon ===
    ios_sizes = {
        'Icon-App-20x20@1x': 20,
        'Icon-App-20x20@2x': 40,
        'Icon-App-20x20@3x': 60,
        'Icon-App-29x29@1x': 29,
        'Icon-App-29x29@2x': 58,
        'Icon-App-29x29@3x': 87,
        'Icon-App-40x40@1x': 40,
        'Icon-App-40x40@2x': 80,
        'Icon-App-40x40@3x': 120,
        'Icon-App-60x60@2x': 120,
        'Icon-App-60x60@3x': 180,
        'Icon-App-76x76@1x': 76,
        'Icon-App-76x76@2x': 152,
        'Icon-App-83.5x83.5@2x': 167,
        'Icon-App-1024x1024@1x': 1024,
    }

    ios_dir = os.path.join(base_path, 'ios', 'Runner', 'Assets.xcassets', 'AppIcon.appiconset')
    os.makedirs(ios_dir, exist_ok=True)

    for filename, size in ios_sizes.items():
        img = create_app_icon(size)
        img.save(os.path.join(ios_dir, f'{filename}.png'))
        print(f"  Created: AppIcon.appiconset/{filename}.png ({size}x{size})")

    # === Windows icon (large PNG for ico conversion) ===
    windows_dir = os.path.join(base_path, 'windows', 'runner', 'resources')
    os.makedirs(windows_dir, exist_ok=True)
    windows_img = create_app_icon(256)
    windows_img.save(os.path.join(windows_dir, 'app_icon_large.png'))
    print(f"  Created: windows/runner/resources/app_icon_large.png (256x256)")

    print("\nGenerating Mysic splash images...")

    # === Android splash icons ===
    splash_sizes = {
        'drawable-mdpi': 144,
        'drawable-hdpi': 216,
        'drawable-xhdpi': 288,
        'drawable-xxhdpi': 432,
        'drawable-xxxhdpi': 576,
        'drawable': 288,
    }

    for folder, size in splash_sizes.items():
        img = create_splash_icon(size)
        dir_path = os.path.join(base_path, 'android', 'app', 'src', 'main', 'res', folder)
        os.makedirs(dir_path, exist_ok=True)
        img.save(os.path.join(dir_path, 'splash_icon.png'))
        print(f"  Created: {folder}/splash_icon.png ({size}x{size})")

    # === iOS LaunchImage ===
    launch_sizes = {
        'LaunchImage': 168,
        'LaunchImage@2x': 336,
        'LaunchImage@3x': 504,
    }

    launch_dir = os.path.join(base_path, 'ios', 'Runner', 'Assets.xcassets', 'LaunchImage.imageset')
    os.makedirs(launch_dir, exist_ok=True)

    for filename, size in launch_sizes.items():
        img = create_splash_icon(size)
        img.save(os.path.join(launch_dir, f'{filename}.png'))
        print(f"  Created: LaunchImage.imageset/{filename}.png ({size}x{size})")

    # Update iOS LaunchScreen.storyboard background color
    storyboard_path = os.path.join(base_path, 'ios', 'Runner', 'Base.lproj', 'LaunchScreen.storyboard')
    if os.path.exists(storyboard_path):
        with open(storyboard_path, 'r', encoding='utf-8') as f:
            content = f.read()
        # Replace white background with dark surface
        content = content.replace(
            'red="1" green="1" blue="1" alpha="1"',
            'red="0.094" green="0.094" blue="0.106" alpha="1"'
        )
        with open(storyboard_path, 'w', encoding='utf-8') as f:
            f.write(content)
        print("  Updated: LaunchScreen.storyboard background to #18181b")

    print("\nAll icons and splash images generated successfully!")
    print("\nNote: For Windows, convert app_icon_large.png to .ico using:")
    print("  - Online tool: https://icoconvert.com/")
    print("  - Or ImageMagick: convert app_icon_large.png app_icon.ico")


if __name__ == '__main__':
    main()
