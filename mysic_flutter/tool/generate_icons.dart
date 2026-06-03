import 'dart:io';
import 'dart:math';
import 'package:image/image.dart';

void main() async {
  // === 设计规范 ===
  const surfaceColor = ConstColorRgba8(0x18, 0x18, 0x1b, 0xff); // #18181b
  const accentColor = ConstColorRgba8(0x10, 0xb9, 0x81, 0xff); // #10b981
  const cardColor = ConstColorRgba8(0x27, 0x27, 0x2a, 0xff); // #27272a

  // === 1. 生成应用图标 ===
  print('Generating app icons...');

  // Android mipmap sizes
  const androidSizes = {
    'mipmap-mdpi': 48,
    'mipmap-hdpi': 72,
    'mipmap-xhdpi': 96,
    'mipmap-xxhdpi': 144,
    'mipmap-xxxhdpi': 192,
  };

  for (final entry in androidSizes.entries) {
    final img = createAppIcon(entry.value, surfaceColor, accentColor, cardColor);
    final dir = 'android/app/src/main/res/${entry.key}';
    await Directory(dir).create(recursive: true);
    File('$dir/ic_launcher.png').writeAsBytesSync(encodePng(img));
    print('  Created: $dir/ic_launcher.png (${entry.value}x${entry.value})');
  }

  // iOS AppIcon sizes
  const iosSizes = <String, int>{
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
  };

  final iosDir = 'ios/Runner/Assets.xcassets/AppIcon.appiconset';
  for (final entry in iosSizes.entries) {
    final img = createAppIcon(entry.value, surfaceColor, accentColor, cardColor);
    File('$iosDir/${entry.key}.png').writeAsBytesSync(encodePng(img));
    print('  Created: $iosDir/${entry.key}.png (${entry.value}x${entry.value})');
  }

  // Windows icon - generate large PNG then note about ico conversion
  final windowsIcon = createAppIcon(256, surfaceColor, accentColor, cardColor);
  final windowsDir = 'windows/runner/resources';
  await Directory(windowsDir).create(recursive: true);
  File('$windowsDir/app_icon_large.png').writeAsBytesSync(encodePng(windowsIcon));
  print('  Created: $windowsDir/app_icon_large.png (256x256)');

  // === 2. 生成启动图片 ===
  print('\nGenerating splash images...');

  // Android splash_icon sizes
  const splashSizes = {
    'drawable-mdpi': 144,
    'drawable-hdpi': 216,
    'drawable-xhdpi': 288,
    'drawable-xxhdpi': 432,
    'drawable-xxxhdpi': 576,
    'drawable': 288,
  };

  for (final entry in splashSizes.entries) {
    final img = createSplashIcon(entry.value, surfaceColor, accentColor, cardColor);
    final dir = 'android/app/src/main/res/${entry.key}';
    await Directory(dir).create(recursive: true);
    File('$dir/splash_icon.png').writeAsBytesSync(encodePng(img));
    print('  Created: $dir/splash_icon.png (${entry.value}x${entry.value})');
  }

  // iOS LaunchImage sizes
  const launchSizes = <String, int>{
    'LaunchImage': 168,
    'LaunchImage@2x': 336,
    'LaunchImage@3x': 504,
  };

  final launchDir = 'ios/Runner/Assets.xcassets/LaunchImage.imageset';
  for (final entry in launchSizes.entries) {
    final img = createSplashIcon(entry.value, surfaceColor, accentColor, cardColor);
    File('$launchDir/${entry.key}.png').writeAsBytesSync(encodePng(img));
    print('  Created: $launchDir/${entry.key}.png (${entry.value}x${entry.value})');
  }

  // Update iOS LaunchScreen.storyboard background color
  final storyboard = File('ios/Runner/Base.lproj/LaunchScreen.storyboard');
  if (storyboard.existsSync()) {
    var content = storyboard.readAsStringSync();
    content = content.replaceAll(
      'red="1" green="1" blue="1" alpha="1"',
      'red="0.094" green="0.094" blue="0.106" alpha="1"',
    );
    storyboard.writeAsStringSync(content);
    print('  Updated: LaunchScreen.storyboard background to #18181b');
  }

  print('\nAll icons and splash images generated successfully!');
}

/// 创建应用图标 - 圆形唱片 + 音符设计
///
/// 设计理念：
/// - 深色背景 (#18181b) 带圆角
/// - 中心圆形唱片元素，模拟黑胶唱片纹理
/// - accent 绿色 (#10b981) 音符/声波元素
/// - 整体风格与 app 内播放器 UI 一致
Image createAppIcon(int size, Color surface, Color accent, Color card) {
  final img = Image(width: size, height: size);
  final center = size / 2;
  final r = size.toDouble();

  // 填充深色背景
  fill(img, color: surface);

  // 绘制圆角矩形背景（iOS 风格自动裁剪，Android 需要）
  final borderRadius = (size * 0.22).round();
  _fillRoundedRect(img, 0, 0, size, size, borderRadius, surface);

  // 中心唱片圆 - 外圈
  final discRadius = r * 0.38;
  final discCenter = center;

  // 唱片外圈 - 深色环
  fillCircle(img, x: discCenter.toInt(), y: discCenter.toInt(), radius: (discRadius * 1.05).round(), color: card);

  // 唱片主体 - 渐变效果（从外到内变深）
  for (var i = discRadius.round(); i > 0; i--) {
    final t = i / discRadius;
    final shade = ColorRgba8(
      (0x18 + (0x27 - 0x18) * t).round(),
      (0x18 + (0x27 - 0x18) * t).round(),
      (0x1b + (0x2a - 0x1b) * t).round(),
      0xff,
    );
    fillCircle(img, x: discCenter.toInt(), y: discCenter.toInt(), radius: i, color: shade);
  }

  // 唱片纹路 - 同心圆细线
  for (var ratio = 0.3; ratio <= 0.95; ratio += 0.08) {
    final grooveRadius = (discRadius * ratio).round();
    drawCircle(
      img,
      x: discCenter.toInt(),
      y: discCenter.toInt(),
      radius: grooveRadius,
      color: ColorRgba8(0x3f, 0x3f, 0x46, 0x40),
    );
  }

  // 中心孔 - accent 绿色
  final holeRadius = discRadius * 0.18;
  fillCircle(img, x: discCenter.toInt(), y: discCenter.toInt(), radius: holeRadius.round(), color: accent);

  // 中心孔内圈 - 更亮的绿色
  final innerHoleRadius = holeRadius * 0.5;
  fillCircle(
    img,
    x: discCenter.toInt(),
    y: discCenter.toInt(),
    radius: innerHoleRadius.round(),
    color: ColorRgba8(0x34, 0xd3, 0x99, 0xff), // lighter green
  );

  // 声波弧线 - 从唱片右侧发出
  final waveStartX = discCenter + discRadius * 0.85;
  final waveStartY = discCenter - discRadius * 0.3;
  for (var w = 0; w < 3; w++) {
    final waveRadius = (discRadius * (0.25 + w * 0.15)).round();
    final alpha = (0xff - w * 0x50).clamp(0x30, 0xff);
    drawCircle(
      img,
      x: waveStartX.round(),
      y: waveStartY.round(),
      radius: waveRadius,
      color: ColorRgba8(accent.r.toInt(), accent.g.toInt(), accent.b.toInt(), alpha),
    );
  }

  // accent 绿色光晕效果 - 唱片中心
  final glowRadius = (discRadius * 0.35).round();
  for (var i = glowRadius; i > 0; i--) {
    final t = i / glowRadius;
    final alpha = (0x30 * (1 - t)).round().clamp(0, 255);
    fillCircle(
      img,
      x: discCenter.toInt(),
      y: discCenter.toInt(),
      radius: i,
      color: ColorRgba8(accent.r.toInt(), accent.g.toInt(), accent.b.toInt(), alpha),
    );
  }

  // 重新绘制中心孔（在光晕之上）
  fillCircle(img, x: discCenter.toInt(), y: discCenter.toInt(), radius: holeRadius.round(), color: accent);
  fillCircle(
    img,
    x: discCenter.toInt(),
    y: discCenter.toInt(),
    radius: innerHoleRadius.round(),
    color: ColorRgba8(0x34, 0xd3, 0x99, 0xff),
  );

  return img;
}

/// 创建启动页图标 - 更大更精致的版本
///
/// 设计理念：
/// - 与应用图标相同的唱片元素，但更大更精致
/// - 底部添加 "Mysic" 文字标识
/// - accent 绿色声波动画暗示
Image createSplashIcon(int size, Color surface, Color accent, Color card) {
  final img = Image(width: size, height: size, numChannels: 4);
  // 透明背景（启动页背景由 XML/Storyboard 控制）
  fill(img, color: ColorRgba8(0, 0, 0, 0));

  final center = size / 2;
  final r = size.toDouble();

  // 唱片圆 - 比图标版本更大
  final discRadius = r * 0.35;
  final discCenterY = center - r * 0.05; // 稍微偏上，给文字留空间

  // 唱片外圈
  fillCircle(img, x: center.toInt(), y: discCenterY.toInt(), radius: (discRadius * 1.08).round(), color: card);

  // 唱片主体 - 渐变
  for (var i = discRadius.round(); i > 0; i--) {
    final t = i / discRadius;
    final shade = ColorRgba8(
      (0x18 + (0x27 - 0x18) * t).round(),
      (0x18 + (0x27 - 0x18) * t).round(),
      (0x1b + (0x2a - 0x1b) * t).round(),
      0xff,
    );
    fillCircle(img, x: center.toInt(), y: discCenterY.toInt(), radius: i, color: shade);
  }

  // 唱片纹路
  for (var ratio = 0.3; ratio <= 0.95; ratio += 0.07) {
    final grooveRadius = (discRadius * ratio).round();
    drawCircle(
      img,
      x: center.toInt(),
      y: discCenterY.toInt(),
      radius: grooveRadius,
      color: ColorRgba8(0x3f, 0x3f, 0x46, 0x35),
    );
  }

  // accent 光晕
  final glowRadius = (discRadius * 0.4).round();
  for (var i = glowRadius; i > 0; i--) {
    final t = i / glowRadius;
    final alpha = (0x25 * (1 - t)).round().clamp(0, 255);
    fillCircle(
      img,
      x: center.toInt(),
      y: discCenterY.toInt(),
      radius: i,
      color: ColorRgba8(accent.r.toInt(), accent.g.toInt(), accent.b.toInt(), alpha),
    );
  }

  // 中心孔
  final holeRadius = discRadius * 0.18;
  fillCircle(img, x: center.toInt(), y: discCenterY.toInt(), radius: holeRadius.round(), color: accent);
  fillCircle(
    img,
    x: center.toInt(),
    y: discCenterY.toInt(),
    radius: (holeRadius * 0.5).round(),
    color: ColorRgba8(0x34, 0xd3, 0x99, 0xff),
  );

  // 声波弧线 - 右侧
  final waveStartX = center + discRadius * 0.8;
  final waveStartY = discCenterY - discRadius * 0.35;
  for (var w = 0; w < 3; w++) {
    final waveRadius = (discRadius * (0.22 + w * 0.14)).round();
    final alpha = (0xff - w * 0x55).clamp(0x25, 0xff);
    drawCircle(
      img,
      x: waveStartX.round(),
      y: waveStartY.round(),
      radius: waveRadius,
      color: ColorRgba8(accent.r.toInt(), accent.g.toInt(), accent.b.toInt(), alpha),
    );
  }

  // 声波弧线 - 左侧（对称但更淡）
  final waveStartX2 = center - discRadius * 0.8;
  for (var w = 0; w < 2; w++) {
    final waveRadius = (discRadius * (0.22 + w * 0.14)).round();
    final alpha = (0x80 - w * 0x30).clamp(0x15, 0xff);
    drawCircle(
      img,
      x: waveStartX2.round(),
      y: waveStartY.round(),
      radius: waveRadius,
      color: ColorRgba8(accent.r.toInt(), accent.g.toInt(), accent.b.toInt(), alpha),
    );
  }

  return img;
}

/// 绘制圆角矩形
void _fillRoundedRect(Image img, int x1, int y1, int x2, int y2, int radius, Color color) {
  for (var y = y1; y < y2; y++) {
    for (var x = x1; x < x2; x++) {
      // 检查是否在圆角内
      var inRect = true;
      // 左上角
      if (x < x1 + radius && y < y1 + radius) {
        final dx = x1 + radius - x;
        final dy = y1 + radius - y;
        if (dx * dx + dy * dy > radius * radius) inRect = false;
      }
      // 右上角
      if (x > x2 - radius - 1 && y < y1 + radius) {
        final dx = x - (x2 - radius - 1);
        final dy = y1 + radius - y;
        if (dx * dx + dy * dy > radius * radius) inRect = false;
      }
      // 左下角
      if (x < x1 + radius && y > y2 - radius - 1) {
        final dx = x1 + radius - x;
        final dy = y - (y2 - radius - 1);
        if (dx * dx + dy * dy > radius * radius) inRect = false;
      }
      // 右下角
      if (x > x2 - radius - 1 && y > y2 - radius - 1) {
        final dx = x - (x2 - radius - 1);
        final dy = y - (y2 - radius - 1);
        if (dx * dx + dy * dy > radius * radius) inRect = false;
      }
      if (inRect) {
        img.setPixelRgba(x, y, color.r, color.g, color.b, color.a);
      }
    }
  }
}
