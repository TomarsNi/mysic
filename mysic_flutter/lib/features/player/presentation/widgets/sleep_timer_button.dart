import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../providers/sleep_timer_provider.dart';
import '../../data/services/sleep_timer_service.dart';
import 'sleep_timer_sheet.dart';

/// 睡眠倒计时按钮
/// 显示在播放控制区域左侧
class SleepTimerButton extends StatefulWidget {
  const SleepTimerButton({super.key});

  @override
  State<SleepTimerButton> createState() => _SleepTimerButtonState();
}

class _SleepTimerButtonState extends State<SleepTimerButton> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    return Consumer<SleepTimerProvider>(
      builder: (context, provider, _) {
        final state = provider.state;
        final isActive = state.isActive;

        return MouseRegion(
          onEnter: (_) => setState(() => _isHovering = true),
          onExit: (_) => setState(() => _isHovering = false),
          child: GestureDetector(
            onTap: () => _showSleepTimerSheet(context),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isActive
                    ? AppColors.accent
                    : (_isHovering ? Colors.white.withValues(alpha: 0.1) : Colors.transparent),
              ),
              child: Center(
                child: isActive
                    ? _buildActiveContent(state)
                    : Icon(
                        Icons.timer_outlined,
                        size: 24,
                        color: AppColors.muted,
                      ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// 构建激活状态内容
  Widget _buildActiveContent(SleepTimerState state) {
    final text = state.mode == SleepTimerMode.time
        ? _formatTime(state.remainingValue)
        : '${state.remainingValue}首';

    return Text(
      text,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      ),
    );
  }

  /// 格式化时间（秒转为 mm:ss）
  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '$minutes:${secs.toString().padLeft(2, '0')}';
  }

  /// 显示设置面板
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
