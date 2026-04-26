// lib/features/ai_skills/presentation/widgets/skill_selection_sheet.dart
import 'package:flutter/material.dart';
import 'package:mysic_flutter/core/theme/app_colors.dart';
import 'package:mysic_flutter/features/ai_skills/core/ai_skill.dart';

/// Skill 选择菜单
/// 显示可用的 Skill 列表，用户选择后开始执行
class SkillSelectionSheet extends StatelessWidget {
  /// 可用的 Skill 列表
  final List<AiSkill> skills;

  /// Skill 选择回调
  final void Function(AiSkill skill) onSkillSelected;

  const SkillSelectionSheet({
    super.key,
    required this.skills,
    required this.onSkillSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 拖拽指示条
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.muted,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),

          // 标题
          const Text(
            '选择 AI 功能',
            style: TextStyle(
              color: AppColors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 24),

          // Skill 列表
          ...skills.map((skill) => _SkillCard(
                skill: skill,
                onTap: () => onSkillSelected(skill),
              )),
        ],
      ),
    );
  }
}

/// Skill 卡片
class _SkillCard extends StatelessWidget {
  final AiSkill skill;
  final VoidCallback onTap;

  const _SkillCard({
    required this.skill,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.muted.withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            children: [
              // 图标
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: AppColors.accentGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  skill.icon,
                  color: AppColors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),

              // 名称和描述
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      skill.displayName,
                      style: const TextStyle(
                        color: AppColors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      skill.description,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),

              // 箭头
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.muted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}