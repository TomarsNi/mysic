// test/features/ai_skills/core/skill_result_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mysic_flutter/features/ai_skills/core/skill_result.dart';

void main() {
  group('SkillResult', () {
    test('SkillSuccess contains data', () {
      const result = SkillSuccess({'title': '晴天', 'artist': '周杰伦'});
      expect(result.data['title'], '晴天');
      expect(result.data['artist'], '周杰伦');
    });

    test('SkillFailure contains message and optional error', () {
      const result = SkillFailure('网络错误', error: 'timeout');
      expect(result.message, '网络错误');
      expect(result.error, 'timeout');
    });

    test('SkillNoChange contains message', () {
      const result = SkillNoChange('信息已正确');
      expect(result.message, '信息已正确');
    });

    test('SkillResult is sealed class', () {
      // 验证可以使用 switch 进行穷尽匹配
      SkillResult result = const SkillSuccess({'test': 'data'});
      final output = switch (result) {
        SkillSuccess(:final data) => 'success: $data',
        SkillFailure(:final message) => 'failure: $message',
        SkillNoChange(:final message) => 'nochange: $message',
      };
      expect(output, contains('success'));
    });
  });
}