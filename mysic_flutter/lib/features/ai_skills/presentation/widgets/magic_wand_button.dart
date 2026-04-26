// lib/features/ai_skills/presentation/widgets/magic_wand_button.dart
import 'package:flutter/material.dart';
import 'package:mysic_flutter/core/theme/app_colors.dart';

/// 魔法棒按钮
/// 显示在首页右上角，点击后弹出 Skill 选择菜单
class MagicWandButton extends StatelessWidget {
  /// 点击回调
  final VoidCallback? onTap;

  /// 是否显示
  final bool visible;

  const MagicWandButton({
    super.key,
    this.onTap,
    this.visible = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!visible) {
      return const SizedBox.shrink();
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
      ),
      child: IconButton(
        icon: const Icon(
          Icons.auto_fix_high_rounded,
          color: AppColors.accent,
        ),
        onPressed: onTap,
        padding: const EdgeInsets.all(12),
        tooltip: 'AI 功能',
      ),
    );
  }
}
