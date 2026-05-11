# 首页进度条拖动交互改进设计

## 概述

改进首页进度条的拖动交互体验：当用户手动调整进度时，隐藏进度拇指，已播放部分变粗，时间实时更新。

## 需求

1. **隐藏拇指**：拖动时完全隐藏进度圆圈（拇指）
2. **已播放部分变粗**：从 2px 变成 4px（变粗 2px）
3. **时间实时更新**：左侧时间随拖动位置实时变化

## 组件结构

```
ProgressBar (StatefulWidget)
├── GestureDetector (处理拖动手势)
│   └── CustomPaint (绘制进度条)
│       ├── 背景轨道 (inactiveTrack)
│       ├── 已播放部分 (activeTrack) - 拖动时变粗
│       └── 拇指 (thumb) - 拖动时隐藏
└── 时间显示 (实时更新)
```

## 状态管理

```dart
class _ProgressBarState extends State<ProgressBar> with SingleTickerProviderStateMixin {
  bool _isDragging = false;
  double _dragValue = 0.0;
  late AnimationController _animationController;
  late Animation<double> _trackHeightAnimation;
  late Animation<double> _thumbOpacityAnimation;
}
```

## 视觉效果

| 状态 | 已播放高度 | 拇指显示 | 时间更新 |
|------|-----------|---------|---------|
| 默认 | 2px | 显示 | 跟随播放进度 |
| Hover | 2px | 显示 + scale 1.1 | 跟随播放进度 |
| 拖动中 | 4px | 隐藏 | 实时更新到拖动位置 |
| 拖动结束 | 2px（动画过渡） | 显示（动画过渡） | 跳转到目标位置 |

## 动画参数

- 已播放高度变化：150ms ease-out
- 拇指显示/隐藏：150ms ease-out
- 缓动曲线：`Curves.easeOut`

## 时间显示逻辑

```dart
String get _formattedPosition {
  if (_isDragging && widget.duration != null) {
    // 拖动时：根据 dragValue 计算时间
    final position = Duration(
      milliseconds: (widget.duration!.inMilliseconds * _dragValue).round(),
    );
    return _formatDuration(position);
  }
  // 默认：使用实际播放位置
  return _formatDuration(widget.position);
}
```

## 自定义绘制器

```dart
class _ProgressBarPainter extends CustomPainter {
  final double progress;
  final bool isDragging;
  final double activeTrackHeight;
  final double thumbRadius;
  final double thumbOpacity;

  @override
  void paint(Canvas canvas, Size size) {
    // 1. 绘制背景轨道（始终 2px，灰色 #3F3F46）
    // 2. 绘制已播放部分（白色，高度由 activeTrackHeight 控制）
    // 3. 绘制拇指（白色圆形，半径 5px，透明度由 thumbOpacity 控制）
  }
}
```

## 颜色规范

| 元素 | 颜色 |
|------|------|
| 背景轨道 | #3F3F46 |
| 已播放部分 | #FFFFFF (白色) |
| 拇指 | #FFFFFF (白色) |
| 时间文字 | #71717A (muted) |

## 尺寸规范

| 元素 | 默认尺寸 | 拖动时尺寸 |
|------|---------|-----------|
| 背景轨道高度 | 2px | 2px |
| 已播放部分高度 | 2px | 4px |
| 拇指半径 | 5px | 隐藏 |
| 时间文字 | 8px | 8px |

## 手势处理

```dart
void _handleDragStart(DragStartDetails details) {
  setState(() {
    _isDragging = true;
    _animationController.forward(); // 启动动画
  });
  _updateDragValue(details.localPosition.dx);
}

void _handleDragUpdate(DragUpdateDetails details) {
  _updateDragValue(details.localPosition.dx);
}

void _handleDragEnd(DragEndDetails details) {
  setState(() {
    _isDragging = false;
    _animationController.reverse(); // 恢复动画
  });
  widget.onSeek?.call(_dragValue);
}

void _updateDragValue(double localX) {
  final width = context.size!.width;
  setState(() {
    _dragValue = (localX / width).clamp(0.0, 1.0);
  });
}
```

## 实现文件

- `mysic_flutter/lib/features/player/presentation/widgets/progress_bar.dart`

## 测试要点

1. 拖动时拇指正确隐藏
2. 已播放部分高度正确变化（2px → 4px）
3. 时间实时更新到拖动位置
4. 动画过渡平滑
5. 拖动结束后正确触发 onSeek 回调
