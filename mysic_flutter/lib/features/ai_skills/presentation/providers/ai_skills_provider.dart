// lib/features/ai_skills/presentation/providers/ai_skills_provider.dart
import 'package:flutter/material.dart';
import 'package:mysic_flutter/features/ai_skills/core/ai_skill.dart';
import 'package:mysic_flutter/features/ai_skills/core/skill_result.dart';
import 'package:mysic_flutter/features/ai_skills/skills/lyrics_search/lyrics_search_skill.dart';
import 'package:mysic_flutter/features/ai_skills/skills/song_recognition/song_recognition_skill.dart';
import 'package:mysic_flutter/features/settings/data/models/api_config.dart';

/// Skill 执行状态
enum SkillExecutionStatus {
  idle, // 空闲
  loading, // 执行中
  success, // 成功
  noChange, // 无需修改
  failure, // 失败
}

/// AI Skills 状态管理
class AiSkillsProvider extends ChangeNotifier {
  /// 所有可用的 Skill
  final List<AiSkill> _skills;

  /// 当前执行的 Skill
  AiSkill? _currentSkill;

  /// 执行状态
  SkillExecutionStatus _status = SkillExecutionStatus.idle;

  /// 执行结果
  SkillResult? _result;

  /// 错误信息
  String? _errorMessage;

  AiSkillsProvider({List<AiSkill>? skills})
      : _skills = skills ??
            [
              SongRecognitionSkill(),
              LyricsSearchSkill(),
            ];

  /// 所有可用的 Skill（只读）
  List<AiSkill> get skills => List.unmodifiable(_skills);

  /// 当前执行的 Skill
  AiSkill? get currentSkill => _currentSkill;

  /// 执行状态
  SkillExecutionStatus get status => _status;

  /// 执行结果
  SkillResult? get result => _result;

  /// 错误信息
  String? get errorMessage => _errorMessage;

  /// 是否正在执行
  bool get isExecuting => _status == SkillExecutionStatus.loading;

  /// 执行指定 Skill
  Future<void> executeSkill({
    required AiSkill skill,
    required ApiConfig config,
    required Map<String, dynamic> input,
  }) async {
    _currentSkill = skill;
    _status = SkillExecutionStatus.loading;
    _result = null;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await skill.execute(config: config, input: input);
      _result = result;

      _status = switch (result) {
        SkillSuccess() => SkillExecutionStatus.success,
        SkillNoChange() => SkillExecutionStatus.noChange,
        SkillFailure() => SkillExecutionStatus.failure,
      };

      if (result is SkillFailure) {
        _errorMessage = result.message;
      }
    } catch (e) {
      _status = SkillExecutionStatus.failure;
      _errorMessage = e.toString();
      _result = SkillFailure(e.toString(), error: e);
    }

    notifyListeners();
  }

  /// 重置状态
  void reset() {
    _currentSkill = null;
    _status = SkillExecutionStatus.idle;
    _result = null;
    _errorMessage = null;
    notifyListeners();
  }
}
