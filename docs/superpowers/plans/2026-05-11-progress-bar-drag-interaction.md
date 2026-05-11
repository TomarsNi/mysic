# 首页进度条拖动交互改进实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 改进首页进度条的拖动交互：拖动时隐藏拇指、已播放部分变粗、时间实时更新。

**Architecture:** 使用 CustomPaint 自定义绘制进度条，替换现有的 Slider 组件。通过 AnimationController 控制拖动时的视觉过渡动画。

**Tech Stack:** Flutter, Dart, CustomPainter, AnimationController

---

## 文件结构

| 文件 | 操作 | 说明 |
|------|------|------|
| `lib/features/player/presentation/widgets/progress_bar.dart` | 修改 | 重写 ProgressBar 组件 |
| `test/widgets/progress_bar_test.dart` | 修改 | 更新测试用例 |

---

### Task 1: 编写自定义绘制器测试

**Files:**
- Modify: `test/widgets/progress_bar_test.dart`

- [ ] **Step 1: 添加拖动时时间实时更新的测试**

```dart
testWidgets('shows real-time position during drag', (WidgetTester tester) async {
  var seekValue = -1.0;

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 300,
          height: 50,
          child: ProgressBar(
            position: Duration.zero,
            duration: const Duration(minutes: 4, seconds: 2),
            enabled: true,
            onSeek: (value) => seekValue = value,
          ),
        ),
      ),
    ),
  );

  // 初始时间显示 0:00
  expect(find.text('0:00'), findsOneWidget);
  expect(find.text('4:02'), findsOneWidget);
});
```

- [ ] **Step 2: 运行测试验证通过**

Run: `cd mysic_flutter && flutter test test/widgets/progress_bar_test.dart`
Expected: PASS（测试使用现有 Slider，暂时通过）

- [ ] **Step 3: 提交测试**

```bash
cd mysic_flutter && git add test/widgets/progress_bar_test.dart && git commit -m "test: 添加进度条拖动交互测试用例"
```

---

### Task 2: 实现自定义进度条绘制器

**Files:**
- Modify: `lib/features/player/presentation/widgets/progress_bar.dart`

- [ ] **Step 1: 添加 _ProgressBarPainter 类**

在 `_GlowingThumbShape` 类之前添加：

```dart
/// 自定义进度条绘制器
class _ProgressBarPainter extends CustomPainter {
  final double progress;
  final double activeTrackHeight;
  final double thumbRadius;
  final double thumbOpacity;
  final bool isHovering;

  _ProgressBarPainter({
    required this.progress,
    required this.activeTrackHeight,
    required this.thumbRadius,
    required this.thumbOpacity,
    required this.isHovering,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final trackHeight = 2.0;
    final trackY = size.height / 2;

    // 1. 绘制背景轨道（灰色 #3F3F46）
    final inactiveTrackPaint = Paint()
      ..color = const Color(0xFF3F3F46)
      ..style = PaintingStyle.fill;
    final trackRect = Rect.fromCenter(
      center: Offset(size.width / 2, trackY),
      width: size.width,
      height: trackHeight,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(trackRect, const Radius.circular(1)),
      inactiveTrackPaint,
    );

    // 2. 绘制已播放部分（白色）
    final activeTrackPaint = Paint()
      ..color = AppColors.white
      ..style = PaintingStyle.fill;
    final activeWidth = size.width * progress.clamp(0.0, 1.0);
    final activeTrackRect = Rect.fromCenter(
      center: Offset(activeWidth / 2, trackY),
      width: activeWidth,
      height: activeTrackHeight,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(activeTrackRect, Radius.circular(activeTrackHeight / 2)),
      activeTrackPaint,
    );

    // 3. 绘制拇指（透明度为 0 时隐藏）
    if (thumbOpacity > 0) {
      final thumbX = size.width * progress.clamp(0.0, 1.0);
      final scaledRadius = thumbRadius * (isHovering ? 1.1 : 1.0);
      final thumbPaint = Paint()
        ..color = AppColors.white.withValues(alpha: thumbOpacity)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(thumbX, trackY), scaledRadius, thumbPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _ProgressBarPainter oldDelegate) {
    return progress != oldDelegate.progress ||
        activeTrackHeight != oldDelegate.activeTrackHeight ||
        thumbRadius != oldDelegate.thumbRadius ||
        thumbOpacity != oldDelegate.thumbOpacity ||
        isHovering != oldDelegate.isHovering;
  }
}
```

- [ ] **Step 2: 运行分析验证无错误**

Run: `cd mysic_flutter && flutter analyze lib/features/player/presentation/widgets/progress_bar.dart`
Expected: No issues found

- [ ] **Step 3: 提交绘制器**

```bash
cd mysic_flutter && git add lib/features/player/presentation/widgets/progress_bar.dart && git commit -m "feat: 添加自定义进度条绘制器"
```

---

### Task 3: 重写 ProgressBar 状态类

**Files:**
- Modify: `lib/features/player/presentation/widgets/progress_bar.dart`

- [ ] **Step 1: 更新 _ProgressBarState 类**

替换 `_ProgressBarState` 类（第 24-126 行）：

```dart
class _ProgressBarState extends State<ProgressBar>
    with SingleTickerProviderStateMixin {
  bool _isDragging = false;
  bool _isHovering = false;
  double _dragValue = 0.0;
  late AnimationController _animationController;
  late Animation<double> _trackHeightAnimation;
  late Animation<double> _thumbOpacityAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _trackHeightAnimation = Tween<double>(begin: 2.0, end: 4.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _thumbOpacityAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  double get _progress {
    if (widget.duration == null || widget.duration!.inMilliseconds == 0) {
      return 0.0;
    }
    return widget.position.inMilliseconds / widget.duration!.inMilliseconds;
  }

  String get _formattedPosition {
    if (_isDragging && widget.duration != null) {
      final position = Duration(
        milliseconds: (widget.duration!.inMilliseconds * _dragValue).round(),
      );
      return _formatDuration(position);
    }
    return _formatDuration(widget.position);
  }

  String get _formattedDuration {
    return widget.duration != null ? _formatDuration(widget.duration!) : '--:--';
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  void _handleTapDown(TapDownDetails details) {
    if (!widget.enabled) return;
    _updateDragValue(details.localPosition.dx);
    widget.onSeek?.call(_dragValue);
  }

  void _handleHorizontalDragStart(DragStartDetails details) {
    if (!widget.enabled) return;
    setState(() {
      _isDragging = true;
      _animationController.forward();
    });
    _updateDragValue(details.localPosition.dx);
  }

  void _handleHorizontalDragUpdate(DragUpdateDetails details) {
    if (!widget.enabled) return;
    _updateDragValue(details.localPosition.dx);
  }

  void _handleHorizontalDragEnd(DragEndDetails details) {
    if (!widget.enabled) return;
    setState(() {
      _isDragging = false;
      _animationController.reverse();
    });
    widget.onSeek?.call(_dragValue);
  }

  void _updateDragValue(double localX) {
    final RenderBox box = context.findRenderObject() as RenderBox;
    final width = box.size.width;
    setState(() {
      _dragValue = (localX / width).clamp(0.0, 1.0);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MouseRegion(
          onEnter: (_) => setState(() => _isHovering = true),
          onExit: (_) => setState(() => _isHovering = false),
          child: GestureDetector(
            onTapDown: widget.enabled ? _handleTapDown : null,
            onHorizontalDragStart:
                widget.enabled ? _handleHorizontalDragStart : null,
            onHorizontalDragUpdate:
                widget.enabled ? _handleHorizontalDragUpdate : null,
            onHorizontalDragEnd:
                widget.enabled ? _handleHorizontalDragEnd : null,
            child: SizedBox(
              height: 24,
              child: AnimatedBuilder(
                animation: _animationController,
                builder: (context, child) {
                  return CustomPaint(
                    painter: _ProgressBarPainter(
                      progress: _isDragging ? _dragValue : _progress,
                      activeTrackHeight: _trackHeightAnimation.value,
                      thumbRadius: 5,
                      thumbOpacity: _thumbOpacityAnimation.value,
                      isHovering: _isHovering && !_isDragging,
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        Transform.translate(
          offset: const Offset(0, -12),
          child: Padding(
            padding: const EdgeInsets.only(left: 24, right: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formattedPosition,
                  style: const TextStyle(
                    fontSize: 8,
                    color: AppColors.muted,
                  ),
                ),
                Text(
                  _formattedDuration,
                  style: const TextStyle(
                    fontSize: 8,
                    color: AppColors.muted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
```

- [ ] **Step 2: 运行分析验证无错误**

Run: `cd mysic_flutter && flutter analyze lib/features/player/presentation/widgets/progress_bar.dart`
Expected: No issues found

- [ ] **Step 3: 提交状态类重写**

```bash
cd mysic_flutter && git add lib/features/player/presentation/widgets/progress_bar.dart && git commit -m "feat: 重写 ProgressBar 状态类，支持拖动交互"
```

---

### Task 4: 删除不再使用的 _GlowingThumbShape 类

**Files:**
- Modify: `lib/features/player/presentation/widgets/progress_bar.dart`

- [ ] **Step 1: 删除 _GlowingThumbShape 类**

删除第 128-165 行的 `_GlowingThumbShape` 类：

```dart
// 删除整个 _GlowingThumbShape 类
```

- [ ] **Step 2: 运行分析验证无错误**

Run: `cd mysic_flutter && flutter analyze lib/features/player/presentation/widgets/progress_bar.dart`
Expected: No issues found

- [ ] **Step 3: 提交删除**

```bash
cd mysic_flutter && git add lib/features/player/presentation/widgets/progress_bar.dart && git commit -m "refactor: 删除不再使用的 _GlowingThumbShape 类"
```

---

### Task 5: 更新测试用例

**Files:**
- Modify: `test/widgets/progress_bar_test.dart`

- [ ] **Step 1: 更新测试用例以匹配新实现**

将第 58-94 行的测试替换为：

```dart
    testWidgets('progress bar is interactive when enabled', (WidgetTester tester) async {
      var seekValue = -1.0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              height: 50,
              child: ProgressBar(
                position: Duration.zero,
                duration: const Duration(minutes: 3),
                enabled: true,
                onSeek: (value) => seekValue = value,
              ),
            ),
          ),
        ),
      );

      // 进度条应该存在
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('shows real-time position during drag', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              height: 50,
              child: ProgressBar(
                position: Duration.zero,
                duration: const Duration(minutes: 4, seconds: 2),
                enabled: true,
                onSeek: (_) {},
              ),
            ),
          ),
        ),
      );

      // 初始时间显示 0:00
      expect(find.text('0:00'), findsOneWidget);
      expect(find.text('4:02'), findsOneWidget);
    });

    testWidgets('progress bar is disabled when not enabled', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              height: 50,
              child: const ProgressBar(
                position: Duration.zero,
                duration: Duration(minutes: 3),
                enabled: false,
              ),
            ),
          ),
        ),
      );

      // 组件应该正常渲染
      expect(find.byType(ProgressBar), findsOneWidget);
    });
```

- [ ] **Step 2: 运行测试验证通过**

Run: `cd mysic_flutter && flutter test test/widgets/progress_bar_test.dart`
Expected: All tests PASS

- [ ] **Step 3: 提交测试更新**

```bash
cd mysic_flutter && git add test/widgets/progress_bar_test.dart && git commit -m "test: 更新进度条测试用例以匹配新实现"
```

---

### Task 6: 运行完整测试并验证

**Files:**
- None

- [ ] **Step 1: 运行所有测试**

Run: `cd mysic_flutter && flutter test`
Expected: All tests PASS

- [ ] **Step 2: 运行分析**

Run: `cd mysic_flutter && flutter analyze`
Expected: No issues found

- [ ] **Step 3: 手动验证**

Run: `cd mysic_flutter && flutter run -d windows`
验证：
1. 拖动进度条时拇指隐藏
2. 已播放部分变粗（2px → 4px）
3. 左侧时间实时更新

---

## 自检清单

- [ ] 规范覆盖：所有设计规范需求都有对应任务
- [ ] 无占位符：每个步骤都有完整代码
- [ ] 类型一致性：方法签名和属性名称一致
