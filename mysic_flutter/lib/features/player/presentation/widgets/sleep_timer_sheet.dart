import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../providers/player_provider.dart';
import '../providers/sleep_timer_provider.dart';
import '../../data/services/sleep_timer_service.dart';

/// 睡眠倒计时设置面板
class SleepTimerSheet extends StatefulWidget {
  const SleepTimerSheet({super.key});

  @override
  State<SleepTimerSheet> createState() => _SleepTimerSheetState();
}

class _SleepTimerSheetState extends State<SleepTimerSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _timeController = TextEditingController();
  final TextEditingController _songCountController = TextEditingController();

  /// 时间预设选项（分钟）
  static const List<int> _timePresets = [5, 10, 15, 30, 60];

  /// 歌曲数预设选项
  static const List<int> _songCountPresets = [1, 3, 5, 10];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) {
      _timeController.clear();
      _songCountController.clear();
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _timeController.dispose();
    _songCountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<SleepTimerProvider, PlayerProvider>(
      builder: (context, sleepTimerProvider, playerProvider, _) {
        final state = sleepTimerProvider.state;

        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              _buildDragHandle(),
              const SizedBox(height: 20),
              _buildHeader(),
              const SizedBox(height: 20),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                switchInCurve: Curves.easeInOut,
                switchOutCurve: Curves.easeInOut,
                transitionBuilder: (child, animation) =>
                    FadeTransition(opacity: animation, child: child),
                child: state.isActive
                    ? _buildActiveView(
                        sleepTimerProvider,
                        key: const ValueKey('active'),
                      )
                    : _buildSettingView(
                        sleepTimerProvider,
                        playerProvider.currentIndex,
                        key: const ValueKey('setting'),
                      ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDragHandle() {
    return Container(
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: AppColors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        const Icon(
          Icons.timer_outlined,
          color: AppColors.accent,
        ),
        const SizedBox(width: 12),
        const Text(
          '睡眠倒计时',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.white,
          ),
        ),
        const Spacer(),
        IconButton(
          icon: const Icon(Icons.close_rounded, color: AppColors.muted),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  // ── 设置态 ──

  Widget _buildSettingView(
    SleepTimerProvider provider,
    int currentIndex, {
    Key? key,
  }) {
    return Column(
      key: key,
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildTabBar(),
        const SizedBox(height: 16),
        SizedBox(
          height: 200,
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildTimeTab(provider),
              _buildSongCountTab(provider, currentIndex),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTabBar() {
    return TabBar(
      controller: _tabController,
      indicator: UnderlineTabIndicator(
        borderSide: BorderSide(
          color: AppColors.accent,
          width: 2,
        ),
      ),
      indicatorSize: TabBarIndicatorSize.label,
      dividerColor: Colors.transparent,
      labelColor: AppColors.white,
      unselectedLabelColor: AppColors.muted,
      labelStyle: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
      unselectedLabelStyle: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      tabs: const [
        Tab(text: '按时间'),
        Tab(text: '按歌曲数'),
      ],
    );
  }

  Widget _buildTimeTab(SleepTimerProvider provider) {
    return Column(
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: _timePresets.map((minutes) {
            return _buildPresetButton(
              label: '$minutes',
              subtitle: '分钟',
              onTap: () => _setTimeTimer(provider, minutes),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        _buildCustomInput(
          controller: _timeController,
          hint: '自定义分钟数',
          onSubmitted: (value) {
            final minutes = int.tryParse(value);
            if (minutes != null && minutes > 0 && minutes <= 999) {
              _setTimeTimer(provider, minutes);
            }
          },
        ),
      ],
    );
  }

  Widget _buildSongCountTab(
    SleepTimerProvider provider,
    int currentIndex,
  ) {
    return Column(
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: _songCountPresets.map((count) {
            return _buildPresetButton(
              label: '$count',
              subtitle: '首',
              onTap: () =>
                  _setSongCountTimer(provider, count, currentIndex),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        _buildCustomInput(
          controller: _songCountController,
          hint: '自定义歌曲数',
          onSubmitted: (value) {
            final count = int.tryParse(value);
            if (count != null && count > 0 && count <= 999) {
              _setSongCountTimer(provider, count, currentIndex);
            }
          },
        ),
      ],
    );
  }

  Widget _buildPresetButton({
    required String label,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          constraints: const BoxConstraints(minWidth: 56),
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.white,
                  height: 1.0,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.muted,
                  height: 1.0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCustomInput({
    required TextEditingController controller,
    required String hint,
    required void Function(String) onSubmitted,
  }) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      textInputAction: TextInputAction.done,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(3),
      ],
      onSubmitted: onSubmitted,
      style: const TextStyle(
        color: AppColors.white,
        fontSize: 14,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.muted),
        filled: true,
        fillColor: AppColors.surface,
        suffixIcon: IconButton(
          icon: const Icon(
            Icons.check_rounded,
            color: AppColors.accent,
            size: 20,
          ),
          onPressed: () {
            if (controller.text.isNotEmpty) {
              onSubmitted(controller.text);
            }
          },
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
      ),
    );
  }

  // ── 激活态 ──

  Widget _buildActiveView(
    SleepTimerProvider provider, {
    Key? key,
  }) {
    final state = provider.state;
    final progress = _computeProgress(state);
    final countdownText = _formatCountdown(state);
    final modeLabel =
        state.mode == SleepTimerMode.time ? '按时间' : '按歌曲数';
    final targetLabel = state.mode == SleepTimerMode.time
        ? '${state.targetValue}分钟'
        : '${state.targetValue}首';
    final subtitleText = state.mode == SleepTimerMode.time
        ? '剩余时间'
        : '剩余歌曲';

    return Column(
      key: key,
      mainAxisSize: MainAxisSize.min,
      children: [
        // 进度环 + 倒计时
        SizedBox(
          width: 120,
          height: 120,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                painter: _SheetProgressPainter(
                  progress: progress,
                  ringColor: AppColors.accent,
                  trackColor: AppColors.accent.withValues(alpha: 0.15),
                  strokeWidth: 4.0,
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    countdownText,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: AppColors.white,
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitleText,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.muted,
                      height: 1.0,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // 模式标签
        Text(
          '$modeLabel · $targetLabel',
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.muted,
          ),
        ),
        const SizedBox(height: 20),
        // 取消按钮
        SizedBox(
          width: double.infinity,
          height: 44,
          child: TextButton(
            onPressed: () {
              provider.cancel();
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(
              backgroundColor: AppColors.card,
              foregroundColor: AppColors.accent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              '取消倒计时',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ],
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

  // ── 操作 ──

  void _setTimeTimer(SleepTimerProvider provider, int minutes) {
    provider.startTimeTimer(minutes);
    Navigator.pop(context);
  }

  void _setSongCountTimer(
    SleepTimerProvider provider,
    int count,
    int currentIndex,
  ) {
    provider.startSongCountTimer(count, currentIndex);
    Navigator.pop(context);
  }
}

/// 面板内大号进度环画笔
class _SheetProgressPainter extends CustomPainter {
  final double progress;
  final Color ringColor;
  final Color trackColor;
  final double strokeWidth;

  _SheetProgressPainter({
    required this.progress,
    required this.ringColor,
    required this.trackColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius, trackPaint);

    if (progress > 0) {
      final sweepAngle = 2 * pi * progress;
      final progressPaint = Paint()
        ..color = ringColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

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
  bool shouldRepaint(_SheetProgressPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.ringColor != ringColor ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
