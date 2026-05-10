#!/usr/bin/env python3
"""
Mysic App Icon Generator - Enhanced Version
使用 Pillow 绘制更精美的图标
"""

import os
import math
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter, ImageFont

# 项目路径
PROJECT_ROOT = Path(__file__).parent.parent.parent

# Android mipmap 尺寸
ANDROID_SIZES = {
    "mipmap-mdpi": 48,
    "mipmap-hdpi": 72,
    "mipmap-xhdpi": 96,
    "mipmap-xxhdpi": 144,
    "mipmap-xxxhdpi": 192,
}

# iOS AppIcon 尺寸
IOS_SIZES = [
    (20, 1), (20, 2), (20, 3),
    (29, 1), (29, 2), (29, 3),
    (40, 1), (40, 2), (40, 3),
    (60, 2), (60, 3),
    (76, 1), (76, 2),
    (83.5, 2),
    (1024, 1),
]

# Windows ICO 尺寸
WINDOWS_SIZES = [16, 32, 48, 64, 128, 256]


def create_gradient_circle(draw, center, radius, inner_color, outer_color, steps=50):
    """绘制渐变圆形"""
    cx, cy = center
    for i in range(steps, 0, -1):
        ratio = i / steps
        r = int(radius * ratio)
        # 线性插值颜色
        color = tuple(int(inner_color[j] + (outer_color[j] - inner_color[j]) * (1 - ratio)) for j in range(3))
        draw.ellipse(
            [cx - r, cy - r, cx + r, cy + r],
            fill=(*color, 255)
        )


def create_icon(size: int) -> Image.Image:
    """创建指定尺寸的图标"""
    # 创建带 alpha 通道的图像
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # 缩放因子
    s = size / 1024

    # ===== 背景 =====
    # 深色圆角矩形背景
    corner_radius = int(180 * s)

    # 背景主体 (#18181b)
    draw.rounded_rectangle(
        [0, 0, size, size],
        radius=corner_radius,
        fill=(24, 24, 27, 255)
    )

    # 添加微妙的渐变效果
    for i in range(20):
        alpha = int(8 * (20 - i) / 20)
        offset = int(i * 3 * s)
        if corner_radius - offset > 0:
            draw.rounded_rectangle(
                [offset, offset, size - offset, size - offset],
                radius=max(1, corner_radius - offset),
                fill=(39, 39, 42, alpha)
            )

    # ===== 主圆形 (专辑封面风格) =====
    center = size // 2
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

    # 主圆形渐变 (从 #10b981 到 #059669)
    inner_color = (16, 185, 129)  # #10b981
    outer_color = (5, 150, 105)   # #059669

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

    # 第二圈高光
    inner_radius2 = int(260 * s)
    draw.ellipse(
        [center - inner_radius2, center - inner_radius2,
         center + inner_radius2, center + inner_radius2],
        outline=(255, 255, 255, 20),
        width=max(1, int(1 * s))
    )

    # ===== 播放按钮 =====
    # 白色播放三角形
    play_width = int(180 * s)
    play_height = int(280 * s)
    play_offset_x = int(-30 * s)  # 视觉居中偏移

    # 三角形顶点
    p1 = (center + play_offset_x, center - play_height // 2)
    p2 = (center + play_offset_x, center + play_height // 2)
    p3 = (center + play_offset_x + play_width, center)

    # 绘制播放按钮阴影
    shadow_offset = int(6 * s)
    draw.polygon([
        (p1[0] + shadow_offset, p1[1] + shadow_offset),
        (p2[0] + shadow_offset, p2[1] + shadow_offset),
        (p3[0] + shadow_offset, p3[1] + shadow_offset)
    ], fill=(0, 0, 0, 50))

    # 绘制播放按钮
    draw.polygon([p1, p2, p3], fill=(255, 255, 255, 255))

    # ===== 音符装饰 =====
    # 左上角音符
    note_scale = s
    note_x = int(260 * s)
    note_y = int(260 * s)

    # 音符头 (椭圆)
    note_head_w = int(40 * s)
    note_head_h = int(30 * s)
    draw.ellipse(
        [note_x, note_y + note_head_h,
         note_x + note_head_w, note_y + note_head_h + note_head_h],
        fill=(255, 255, 255, 180)
    )

    # 音符杆
    stem_width = max(1, int(10 * s))
    stem_height = int(120 * s)
    draw.rounded_rectangle(
        [note_x + note_head_w - stem_width, note_y,
         note_x + note_head_w, note_y + stem_height],
        radius=max(1, int(5 * s)),
        fill=(255, 255, 255, 180)
    )

    # 音符旗
    flag_points = [
        (note_x + note_head_w - stem_width, note_y),
        (note_x + note_head_w + int(30 * s), note_y + int(20 * s)),
        (note_x + note_head_w + int(25 * s), note_y + int(50 * s)),
        (note_x + note_head_w - stem_width, note_y + int(35 * s)),
    ]
    draw.polygon(flag_points, fill=(255, 255, 255, 180))

    # 右下角小音符
    note2_x = int(700 * s)
    note2_y = int(680 * s)
    note2_size = int(25 * s)

    draw.ellipse(
        [note2_x, note2_y + note2_size,
         note2_x + note2_size, note2_y + note2_size * 2],
        fill=(255, 255, 255, 100)
    )
    draw.rounded_rectangle(
        [note2_x + note2_size - max(1, int(6 * s)), note2_y,
         note2_x + note2_size, note2_y + int(80 * s)],
        radius=max(1, int(3 * s)),
        fill=(255, 255, 255, 100)
    )

    return img


def generate_android_icons():
    """生成 Android mipmap 图标"""
    android_res = PROJECT_ROOT / "mysic_flutter" / "android" / "app" / "src" / "main" / "res"

    for folder, size in ANDROID_SIZES.items():
        output_path = android_res / folder / "ic_launcher.png"
        output_path.parent.mkdir(parents=True, exist_ok=True)

        icon = create_icon(size)
        icon.save(output_path, 'PNG')
        print(f"[OK] Generated: {output_path}")

    print(f"\nAndroid icons generated in: {android_res}")


def generate_ios_icons():
    """生成 iOS AppIcon"""
    ios_assets = PROJECT_ROOT / "mysic_flutter" / "ios" / "Runner" / "Assets.xcassets" / "AppIcon.appiconset"
    ios_assets.mkdir(parents=True, exist_ok=True)

    for base_size, scale in IOS_SIZES:
        actual_size = int(base_size * scale)
        filename = f"Icon-App-{int(base_size)}x{int(base_size)}@{scale}x.png"
        output_path = ios_assets / filename

        icon = create_icon(actual_size)
        icon.save(output_path, 'PNG')
        print(f"[OK] Generated: {output_path}")

    print(f"\niOS icons generated in: {ios_assets}")


def generate_windows_icon():
    """生成 Windows ICO 图标"""
    windows_res = PROJECT_ROOT / "mysic_flutter" / "windows" / "runner" / "resources"
    windows_res.mkdir(parents=True, exist_ok=True)

    # 生成各尺寸图像
    images = []
    for size in WINDOWS_SIZES:
        icon = create_icon(size)
        images.append(icon)
        print(f"[OK] Created {size}x{size} image")

    # 保存为 ICO
    ico_path = windows_res / "app_icon.ico"
    images[0].save(
        ico_path,
        format='ICO',
        sizes=[(img.width, img.height) for img in images],
        append_images=images[1:]
    )
    print(f"[OK] Generated: {ico_path}")

    print(f"\nWindows icon generated in: {windows_res}")


def main():
    print("=" * 50)
    print("Mysic App Icon Generator")
    print("=" * 50)

    print("\nGenerating icons for all platforms...")
    print("-" * 50)

    generate_android_icons()
    print()
    generate_ios_icons()
    print()
    generate_windows_icon()

    print("-" * 50)
    print("\n[OK] All icons generated successfully!")


if __name__ == "__main__":
    main()