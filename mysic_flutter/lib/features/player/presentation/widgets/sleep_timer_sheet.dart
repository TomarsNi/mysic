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
  final TextEditingController _customController = TextEditingController();

  /// 时间预设选项（分钟）
  static const List<int> _timePresets = [5, 10, 15, 30, 60];

  /// 歌曲数预设选项
  static const List<int> _songCountPresets = [1, 3, 5, 10];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _customController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SleepTimerProvider>(
      builder: (context, provider, _) {
        final state = provider.state;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              // 拖动指示器
              _buildDragHandle(),
              const SizedBox(height: 20),
              // 标题
              _buildHeader(state),
              const SizedBox(height: 16),
              // 选项卡
              _buildTabBar(),
              const SizedBox(height: 16),
              // 内容区域
              SizedBox(
                height: 200,
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildTimeTab(provider),
                    _buildSongCountTab(provider),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // 当前状态和取消按钮
              if (state.isActive) _buildActiveState(provider, state),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  /// 拖动指示器
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

  /// 标题
  Widget _buildHeader(SleepTimerState state) {
    return Row(
      children: [
        Icon(
          Icons.timer_outlined,
          color: state.isActive ? AppColors.accent : AppColors.muted,
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
      ],
    );
  }

  /// 选项卡栏
  Widget _buildTabBar() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(12),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: AppColors.white,
        unselectedLabelColor: AppColors.muted,
        labelStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        tabs: const [
          Tab(text: '按时间'),
          Tab(text: '按歌曲数'),
        ],
      ),
    );
  }

  /// 时间选项卡
  Widget _buildTimeTab(SleepTimerProvider provider) {
    return Column(
      children: [
        // 预设按钮
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: _timePresets.map((minutes) {
            return _buildPresetButton(
              label: '$minutes 分钟',
              onTap: () => _setTimeTimer(provider, minutes),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        // 自定义输入
        _buildCustomInput(
          hint: '自定义分钟数',
          onSubmitted: (value) {
            final minutes = int.tryParse(value);
            if (minutes != null && minutes > 0) {
              _setTimeTimer(provider, minutes);
            }
          },
        ),
      ],
    );
  }

  /// 歌曲数选项卡
  Widget _buildSongCountTab(SleepTimerProvider provider) {
    // 获取当前歌曲索引
    final playerProvider = context.read<PlayerProvider>();
    final currentIndex = playerProvider.currentIndex;

    return Column(
      children: [
        // 预设按钮
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: _songCountPresets.map((count) {
            return _buildPresetButton(
              label: '$count 首',
              onTap: () => _setSongCountTimer(provider, count, currentIndex),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        // 自定义输入
        _buildCustomInput(
          hint: '自定义歌曲数',
          onSubmitted: (value) {
            final count = int.tryParse(value);
            if (count != null && count > 0) {
              _setSongCountTimer(provider, count, currentIndex);
            }
          },
        ),
      ],
    );
  }

  /// 预设按钮
  Widget _buildPresetButton({
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.card),
          ),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.white,
            ),
          ),
        ),
      ),
    );
  }

  /// 自定义输入框
  Widget _buildCustomInput({
    required String hint,
    required void Function(String) onSubmitted,
  }) {
    return TextField(
      controller: _customController,
      keyboardType: TextInputType.number,
      textInputAction: TextInputAction.done,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      onSubmitted: onSubmitted,
      style: const TextStyle(color: AppColors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.muted),
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  /// 激活状态显示
  Widget _buildActiveState(SleepTimerProvider provider, SleepTimerState state) {
    final modeText = state.mode == SleepTimerMode.time ? '时间' : '歌曲数';
    final valueText = state.mode == SleepTimerMode.time
        ? _formatTime(state.remainingValue)
        : '${state.remainingValue} 首';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.timer_outlined,
            color: AppColors.accent,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '当前：$modeText模式',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.muted,
                  ),
                ),
                Text(
                  '剩余 $valueText',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.white,
                  ),
                ),
              ],
            ),
          ),
          // 取消按钮
          TextButton(
            onPressed: () {
              provider.cancel();
            },
            style: TextButton.styleFrom(
              foregroundColor: AppColors.accent,
            ),
            child: const Text('取消'),
          ),
        ],
      ),
    );
  }

  /// 设置时间倒计时
  void _setTimeTimer(SleepTimerProvider provider, int minutes) {
    provider.startTimeTimer(minutes);
    Navigator.pop(context);
    _showSnackBar('已设置 $minutes 分钟后暂停');
  }

  /// 设置歌曲数倒计时
  void _setSongCountTimer(SleepTimerProvider provider, int count, int currentIndex) {
    provider.startSongCountTimer(count, currentIndex);
    Navigator.pop(context);
    _showSnackBar('已设置 $count 首后暂停');
  }

  /// 显示提示
  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.accent,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// 格式化时间
  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '$minutes:${secs.toString().padLeft(2, '0')}';
  }
}
