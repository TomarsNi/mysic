// lib/features/ai_skills/presentation/widgets/magic_wand_button.dart
import 'package:flutter/material.dart';
import 'package:mysic_flutter/core/theme/app_colors.dart';

/// 魔法棒按钮
/// 显示在首页右上角，点击后弹出 Skill 选择菜单
/// 简约风格：无背景，只保留图标，hover 时图标 accent 色
class MagicWandButton extends StatefulWidget {
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
  State<MagicWandButton> createState() => _MagicWandButtonState();
}

class _MagicWandButtonState extends State<MagicWandButton> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    if (!widget.visible) {
      return const SizedBox.shrink();
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: IconButton(
        icon: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 150),
          style: TextStyle(
            color: _isHovering ? AppColors.accent : AppColors.muted,
          ),
          child: const Icon(Icons.auto_fix_high_rounded),
        ),
        onPressed: widget.onTap,
        padding: const EdgeInsets.all(12),
        tooltip: 'AI 功能',
      ),
    );
  }
}
