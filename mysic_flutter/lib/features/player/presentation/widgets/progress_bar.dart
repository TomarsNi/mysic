import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

/// 进度条组件
/// 可拖动的进度条，显示当前播放时间和总时长
class ProgressBar extends StatefulWidget {
  final Duration position;
  final Duration? duration;
  final ValueChanged<double>? onSeek;
  final bool enabled;

  const ProgressBar({
    super.key,
    required this.position,
    this.duration,
    this.onSeek,
    this.enabled = true,
  });

  @override
  State<ProgressBar> createState() => _ProgressBarState();
}

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
    const trackHeight = 2.0;
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
      RRect.fromRectAndRadius(
        activeTrackRect,
        Radius.circular(activeTrackHeight / 2),
      ),
      activeTrackPaint,
    );

    // 3. 绘拇指（透明度为 0 时隐藏）
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

/// 自定义拇指形状 - 无光晕效果
class _GlowingThumbShape extends RoundSliderThumbShape {
  final double thumbScale;

  const _GlowingThumbShape({
    required super.enabledThumbRadius,
    super.elevation,
    this.thumbScale = 1.0,
  });

  @override
  void paint(
    PaintingContext context,
    Offset center,
    {required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required Animation<double> activationAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required TextDirection textDirection,
    required double textScaleFactor,
    required Size sizeWithOverflow,
    required double value,
  }) {
    final Canvas canvas = context.canvas;

    // 应用 scale 变换
    final scaledRadius = enabledThumbRadius * thumbScale;

    // 绘制拇指（无光晕）
    final Paint thumbPaint = Paint()
      ..color = sliderTheme.thumbColor ?? AppColors.white
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, scaledRadius, thumbPaint);
  }
}

/// 简单进度条（不可拖动）
class SimpleProgressBar extends StatelessWidget {
  final Duration position;
  final Duration? duration;
  final double height;

  const SimpleProgressBar({
    super.key,
    required this.position,
    this.duration,
    this.height = 2,
  });

  double get _progress {
    if (duration == null || duration!.inMilliseconds == 0) {
      return 0.0;
    }
    return position.inMilliseconds / duration!.inMilliseconds;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFF3F3F46),
        borderRadius: BorderRadius.circular(height / 2),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: _progress.clamp(0.0, 1.0),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.accent,
            borderRadius: BorderRadius.circular(height / 2),
          ),
        ),
      ),
    );
  }
}

/// 带缓冲进度的进度条
class BufferedProgressBar extends StatefulWidget {
  final Duration position;
  final Duration? duration;
  final Duration bufferedPosition;
  final ValueChanged<double>? onSeek;
  final bool enabled;

  const BufferedProgressBar({
    super.key,
    required this.position,
    this.duration,
    this.bufferedPosition = Duration.zero,
    this.onSeek,
    this.enabled = true,
  });

  @override
  State<BufferedProgressBar> createState() => _BufferedProgressBarState();
}

class _BufferedProgressBarState extends State<BufferedProgressBar> {
  bool _isDragging = false;
  double _dragValue = 0.0;

  double get _progress {
    if (widget.duration == null || widget.duration!.inMilliseconds == 0) {
      return 0.0;
    }
    return widget.position.inMilliseconds / widget.duration!.inMilliseconds;
  }

  double get _bufferedProgress {
    if (widget.duration == null || widget.duration!.inMilliseconds == 0) {
      return 0.0;
    }
    return widget.bufferedPosition.inMilliseconds /
        widget.duration!.inMilliseconds;
  }

  String get _formattedPosition => _formatDuration(widget.position);

  String get _formattedDuration {
    return widget.duration != null ? _formatDuration(widget.duration!) : '--:--';
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 自定义进度条
        GestureDetector(
          onTap: widget.enabled
              ? () {
                  // 点击跳转
                  final RenderBox box = context.findRenderObject() as RenderBox;
                  final localPosition =
                      box.globalToLocal(box.localToGlobal(Offset.zero));
                  // 简化处理，实际需要计算点击位置
                }
              : null,
          onHorizontalDragUpdate: widget.enabled
              ? (details) {
                  setState(() {
                    _isDragging = true;
                    // 简化处理
                  });
                }
              : null,
          child: Container(
            height: 20, // 增加点击区域
            alignment: Alignment.center,
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                // 背景轨道
                Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFF3F3F46),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // 缓冲进度
                FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: _bufferedProgress.clamp(0.0, 1.0),
                  child: Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.muted.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                // 播放进度
                FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor:
                      (_isDragging ? _dragValue : _progress).clamp(0.0, 1.0),
                  child: Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                // 拖动滑块
                if (widget.enabled)
                  Positioned(
                    left: (_isDragging ? _dragValue : _progress).clamp(0.0, 1.0) *
                            (MediaQuery.of(context).size.width - 48) -
                        8,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: AppColors.accent,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.accent.withValues(alpha: 0.3),
                            blurRadius: 8,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),

        // 时间显示
        Padding(
          padding: const EdgeInsets.only(top: 4, left: 4, right: 4),
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
      ],
    );
  }
}
