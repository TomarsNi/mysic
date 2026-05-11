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

class _ProgressBarState extends State<ProgressBar> {
  bool _isDragging = false;
  bool _isHovering = false;
  double _dragValue = 0.0;

  double get _progress {
    if (widget.duration == null || widget.duration!.inMilliseconds == 0) {
      return 0.0;
    }
    return widget.position.inMilliseconds / widget.duration!.inMilliseconds;
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
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 进度条 - 设计稿规范：轨道高度 8px，拇指 24px，带阴影和 hover scale
        // Slider 有内置的垂直 padding，通过 Transform.translate 压缩间距
        MouseRegion(
          onEnter: (_) => setState(() => _isHovering = true),
          onExit: (_) => setState(() => _isHovering = false),
          child: SliderTheme(
            data: SliderThemeData(
              activeTrackColor: AppColors.white,
              inactiveTrackColor: const Color(0xFF3F3F46),
              thumbColor: AppColors.white,
              overlayColor: AppColors.white.withValues(alpha: 0.2),
              trackHeight: 2,
              thumbShape: _GlowingThumbShape(
                enabledThumbRadius: 5,
                elevation: _isHovering ? 8 : 4,
                thumbScale: _isHovering ? 1.1 : 1.0,
              ),
              disabledActiveTrackColor: AppColors.muted,
              disabledInactiveTrackColor: const Color(0xFF3F3F46),
              disabledThumbColor: AppColors.muted,
            ),
            child: Slider(
              value: _isDragging ? _dragValue : _progress.clamp(0.0, 1.0),
              onChanged: widget.enabled
                  ? (value) {
                      setState(() {
                        _isDragging = true;
                        _dragValue = value;
                      });
                    }
                  : null,
              onChangeEnd: widget.enabled
                  ? (value) {
                      setState(() {
                        _isDragging = false;
                      });
                      widget.onSeek?.call(value);
                    }
                  : null,
            ),
          ),
        ),

        // 时间显示 - 通过负的 Transform.translate 向上移动，紧贴进度条
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
