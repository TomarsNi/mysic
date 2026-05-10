#!/usr/bin/env python3
"""
Mysic Splash Screen Icon Generator
生成 Android 启动页图标
"""

import os
import math
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter

PROJECT_ROOT = Path(__file__).parent.parent.parent

# Android drawable 尺寸
DRAWABLE_SIZES = {
    "mdpi": 48,
    "hdpi": 72,
    "xhdpi": 96,
    "xxhdpi": 144,
    "xxxhdpi": 192,
}


def create_splash_icon(size: int) -> Image.Image:
    """创建启动页图标 - 更简洁的版本，适合居中显示"""
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    s = size / 1024
    center = size // 2

    # 主圆形 - 专辑封面风格
    circle_radius = int(320 * s)

    # 外发光效果
    for i in range(8):
        glow_radius = circle_radius + int(i * 6 * s)
        alpha = int(25 * (8 - i) / 8)
        draw.ellipse(
            [center - glow_radius, center - glow_radius,
             center + glow_radius, center + glow_radius],
            fill=(16, 185, 129, alpha)
        )

    # 主圆形渐变
    inner_color = (16, 185, 129)
    outer_color = (5, 150, 105)

    for i in range(50, 0, -1):
        ratio = i / 50
        r = int(circle_radius * ratio)
        color = tuple(int(inner_color[j] + (outer_color[j] - inner_color[j]) * (1 - ratio)) for j in range(3))
        draw.ellipse(
            [center - r, center - r, center + r, center + r],
            fill=(*color, 255)
        )

    # 内圈高光
    inner_radius = int(300 * s)
    draw.ellipse(
        [center - inner_radius, center - inner_radius,
         center + inner_radius, center + inner_radius],
        outline=(255, 255, 255, 40),
        width=max(1, int(2 * s))
    )

    # 播放按钮
    play_width = int(180 * s)
    play_height = int(280 * s)
    play_offset_x = int(-30 * s)

    p1 = (center + play_offset_x, center - play_height // 2)
    p2 = (center + play_offset_x, center + play_height // 2)
    p3 = (center + play_offset_x + play_width, center)

    # 阴影
    shadow_offset = int(6 * s)
    draw.polygon([
        (p1[0] + shadow_offset, p1[1] + shadow_offset),
        (p2[0] + shadow_offset, p2[1] + shadow_offset),
        (p3[0] + shadow_offset, p3[1] + shadow_offset)
    ], fill=(0, 0, 0, 50))

    # 播放按钮
    draw.polygon([p1, p2, p3], fill=(255, 255, 255, 255))

    return img


def generate_splash_icons():
    """生成各分辨率的启动页图标"""
    android_res = PROJECT_ROOT / "mysic_flutter" / "android" / "app" / "src" / "main" / "res"

    for folder, size in DRAWABLE_SIZES.items():
        output_path = android_res / f"drawable-{folder}" / "splash_icon.png"
        output_path.parent.mkdir(parents=True, exist_ok=True)

        icon = create_splash_icon(size)
        icon.save(output_path, 'PNG')
        print(f"[OK] Generated: {output_path}")

    # 也生成一个通用 drawable 文件夹的版本
    output_path = android_res / "drawable" / "splash_icon.png"
    icon = create_splash_icon(192)
    icon.save(output_path, 'PNG')
    print(f"[OK] Generated: {output_path}")

    print(f"\nSplash icons generated!")


if __name__ == "__main__":
    generate_splash_icons()