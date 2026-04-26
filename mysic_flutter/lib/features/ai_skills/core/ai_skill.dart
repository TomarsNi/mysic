// lib/features/ai_skills/core/ai_skill.dart
import 'package:flutter/material.dart';
import 'package:mysic_flutter/features/ai_skills/core/skill_result.dart';
import 'package:mysic_flutter/features/settings/data/models/api_config.dart';

/// AI Skill 抽象接口
/// 所有 AI 功能必须实现此接口
abstract interface class AiSkill {
  /// Skill 唯一标识
  String get id;

  /// Skill 显示名称
  String get displayName;

  /// Skill 描述
  String get description;

  /// Skill 图标
  IconData get icon;

  /// 执行 Skill
  /// 返回 SkillResult 或抛出异常
  Future<SkillResult> execute({
    required ApiConfig config,
    required Map<String, dynamic> input,
  });
}
