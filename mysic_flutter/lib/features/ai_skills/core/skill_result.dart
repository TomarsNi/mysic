// lib/features/ai_skills/core/skill_result.dart
/// Skill 执行结果基类
sealed class SkillResult {
  const SkillResult();
}

/// 成功结果
final class SkillSuccess extends SkillResult {
  const SkillSuccess(this.data);
  final Map<String, dynamic> data;
}

/// 失败结果
final class SkillFailure extends SkillResult {
  const SkillFailure(this.message, {this.error});
  final String message;
  final Object? error;
}

/// 无需修正（信息已正确）
final class SkillNoChange extends SkillResult {
  const SkillNoChange(this.message);
  final String message;
}