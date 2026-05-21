import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../providers/sleep_timer_provider.dart';
import '../../data/services/sleep_timer_service.dart';
import 'sleep_timer_sheet.dart';

/// 睡眠倒计时按钮
/// 显示在播放控制区域左侧
/// 未激活：timer 图标，hover 时 accent 色
/// 激活：圆形进度环 + 倒计时文字
class SleepTimerButton extends StatefulWidget {
  const SleepTimerButton({super.key});

  @override
  State<SleepTimerButton> createState() => _SleepTimerButtonState();
}

class _SleepTimerButtonState extends State<SleepTimerButton> {
  bool _isHovering = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return Consumer<SleepTimerProvider>(
      builder: (context, provider, _) {
        final state = provider.state;
        final isActive = state.isActive;

        return MouseRegion(
          onEnter: (_) => setState(() => _isHovering = true),
          onExit: (_) => setState(() => _isHovering = false),
          child: Tooltip(
            message: isActive ? '睡眠倒计时' : '设置睡眠倒计时',
            child: AnimatedScale(
              duration: const Duration(milliseconds: 100),
              scale: _isPressed ? 0.95 : 1.0,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isActive
                      ? AppColors.accent.withValues(alpha: 0.15)
                      : (_isHovering
                          ? Colors.white.withValues(alpha: 0.1)
                          : Colors.transparent),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _showSleepTimerSheet(context),
                    onTapDown: (_) => setState(() => _isPressed = true),
                    onTapUp: (_) => setState(() => _isPressed = false),
                    onTapCancel: () => setState(() => _isPressed = false),
                    borderRadius: BorderRadius.circular(24),
                    child: Center(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        switchInCurve: Curves.easeInOut,
                        switchOutCurve: Curves.easeInOut,
                        transitionBuilder: (child, animation) =>
                            FadeTransition(opacity: animation, child: child),
                        child: isActive
                            ? _buildActiveContent(state,
                                key: const ValueKey('active'))
                            : _buildInactiveContent(
                                key: const ValueKey('inactive')),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildInactiveContent({Key? key}) {
    return Icon(
      key: key,
      Icons.timer_outlined,
      size: 24,
      color: _isHovering ? AppColors.accent : AppColors.muted,
    );
  }

  Widget _buildActiveContent(SleepTimerState state, {Key? key}) {
    final progress = _computeProgress(state);
    final text = _formatCountdown(state);
    final isTimeMode = state.mode == SleepTimerMode.time;

    return SizedBox(
      key: key,
      width: 40,
      height: 40,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size(40, 40),
            painter: _TimerProgressPainter(
              progress: progress,
              ringColor: AppColors.accent,
              trackColor: AppColors.accent.withValues(alpha: 0.2),
              strokeWidth: 3.0,
            ),
          ),
          Text(
            text,
            style: TextStyle(
              fontSize: isTimeMode ? 11 : 13,
              fontWeight: FontWeight.w700,
              color: AppColors.white,
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }

  double _computeProgress(SleepTimerState state) {
    if (state.mode == SleepTimerMode.time) {
      final totalSeconds = state.targetValue * 60;
      if (totalSeconds <= 0) return 0.0;
      return (state.remainingValue / totalSeconds).clamp(0.0, 1.0);
    } else {
      if (state.targetValue <= 0) return 0.0;
      return (state.remainingValue / state.targetValue).clamp(0.0, 1.0);
    }
  }

  String _formatCountdown(SleepTimerState state) {
    if (state.mode == SleepTimerMode.time) {
      final remaining = state.remainingValue;
      if (remaining >= 3600) {
        // >= 1h: 显示 "H:MM:SS"
        final hours = remaining ~/ 3600;
        final minutes = (remaining % 3600) ~/ 60;
        final seconds = remaining % 60;
        return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
      }
      final minutes = remaining ~/ 60;
      final seconds = remaining % 60;
      return '$minutes:${seconds.toString().padLeft(2, '0')}';
    } else {
      return '${state.remainingValue}首';
    }
  }

  void _showSleepTimerSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => const SleepTimerSheet(),
    );
  }
}

/// 圆形进度环画笔
/// 绘制背景环和进度弧，从 12 点方向顺时针
class _TimerProgressPainter extends CustomPainter {
  final double progress;
  final Color ringColor;
  final Color trackColor;
  final double strokeWidth;

  _TimerProgressPainter({
    required this.progress,
    required this.ringColor,
    required this.trackColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // 背景环
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius, trackPaint);

    // 进度弧
    if (progress > 0) {
      final sweepAngle = 2 * pi * progress;
      final progressPaint = Paint()
        ..color = ringColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      // 从 12 点方向（-pi/2）顺时针
      const startAngle = -pi / 2;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_TimerProgressPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.ringColor != ringColor ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
