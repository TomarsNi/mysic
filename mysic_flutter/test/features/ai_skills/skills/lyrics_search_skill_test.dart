// test/features/ai_skills/skills/lyrics_search_skill_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mysic_flutter/features/ai_skills/core/llm_service.dart';
import 'package:mysic_flutter/features/ai_skills/core/skill_result.dart';
import 'package:mysic_flutter/features/ai_skills/skills/lyrics_search/lyrics_search_skill.dart';
import 'package:mysic_flutter/features/settings/data/models/api_config.dart';

/// Fake LlmService for testing
class FakeLlmService implements LlmService {
  String? _response;
  Exception? _exception;

  void setResponse(String response) => _response = response;
  void setException(Exception exception) => _exception = exception;

  @override
  Future<String> chat({
    required ApiConfig config,
    required String prompt,
    bool enableWebSearch = false,
  }) async {
    if (_exception != null) throw _exception!;
    if (_response == null) throw StateError('No response set');
    return _response!;
  }

  @override
  String buildUrl(ApiConfig config) => '';

  @override
  Map<String, dynamic> buildRequestBody({
    required ApiConfig config,
    required String prompt,
    required bool enableWebSearch,
  }) => {};

  @override
  String parseResponse({
    required ApiConfig config,
    required Map<String, dynamic> response,
  }) => '';

  @override
  void dispose() {}
}

void main() {
  group('LyricsSearchSkill', () {
    late LyricsSearchSkill skill;
    late FakeLlmService fakeLlmService;
    late ApiConfig testConfig;

    setUp(() {
      fakeLlmService = FakeLlmService();
      skill = LyricsSearchSkill(llmService: fakeLlmService);
      testConfig = ApiConfig.defaultFor(ApiProvider.aliyun).copyWith(
        apiKey: 'test-api-key',
        isEnabled: true,
      );
    });

    group('properties', () {
      test('has correct id', () {
        expect(skill.id, 'lyrics_search');
      });

      test('has correct displayName', () {
        expect(skill.displayName, '搜索歌词');
      });

      test('has correct description', () {
        expect(skill.description, '根据歌曲信息搜索匹配歌词');
      });
    });

    group('buildPrompt', () {
      test('builds correct prompt from input', () {
        final prompt = skill.buildPrompt(
          title: '晴天',
          artist: '周杰伦',
          album: '叶惠美',
        );

        expect(prompt, contains('晴天'));
        expect(prompt, contains('周杰伦'));
        expect(prompt, contains('叶惠美'));
        expect(prompt, contains('LRC'));
      });

      test('handles missing album in prompt', () {
        final prompt = skill.buildPrompt(
          title: '晴天',
          artist: '周杰伦',
        );

        expect(prompt, contains('晴天'));
        expect(prompt, contains('周杰伦'));
        expect(prompt, contains('未知'));
      });
    });

    group('parseResponse', () {
      test('parses found lyrics response correctly', () {
        const aiResponse = '''
{
  "found": true,
  "lyrics": "[00:00.00]故事的小黄花\\n[00:05.00]从出生那年就飘着",
  "source": "网易云音乐",
  "matchedSong": {
    "title": "晴天",
    "artist": "周杰伦"
  }
}
''';

        final result = skill.parseResponse(aiResponse);
        expect(result.found, true);
        expect(result.lyrics, contains('故事的小黄花'));
        expect(result.source, '网易云音乐');
        expect(result.matchedSong?.title, '晴天');
      });

      test('parses not found response correctly', () {
        const aiResponse = '''
{
  "found": false,
  "reason": "未找到匹配歌词"
}
''';

        final result = skill.parseResponse(aiResponse);
        expect(result.found, false);
        expect(result.reason, '未找到匹配歌词');
      });
    });

    group('execute', () {
      test('returns SkillFailure when title is missing', () async {
        final result = await skill.execute(
          config: testConfig,
          input: {},
        );

        expect(result, isA<SkillFailure>());
        expect((result as SkillFailure).message, '缺少歌曲名称');
      });

      test('returns SkillFailure when title is empty', () async {
        final result = await skill.execute(
          config: testConfig,
          input: {'title': ''},
        );

        expect(result, isA<SkillFailure>());
        expect((result as SkillFailure).message, '缺少歌曲名称');
      });

      test('returns SkillSuccess when lyrics found', () async {
        fakeLlmService.setResponse('''
{
  "found": true,
  "lyrics": "[00:00.00]故事的小黄花",
  "source": "网易云音乐",
  "matchedSong": {
    "title": "晴天",
    "artist": "周杰伦"
  }
}
''');

        final result = await skill.execute(
          config: testConfig,
          input: {
            'title': '晴天',
            'artist': '周杰伦',
            'album': '叶惠美',
          },
        );

        expect(result, isA<SkillSuccess>());
        final data = (result as SkillSuccess).data;
        expect(data['lyrics'], contains('故事的小黄花'));
        expect(data['source'], '网易云音乐');
      });

      test('returns SkillFailure when lyrics not found', () async {
        fakeLlmService.setResponse('''
{
  "found": false,
  "reason": "未找到匹配歌词"
}
''');

        final result = await skill.execute(
          config: testConfig,
          input: {
            'title': '未知歌曲',
            'artist': '未知艺术家',
          },
        );

        expect(result, isA<SkillFailure>());
        expect((result as SkillFailure).message, '未找到匹配歌词');
      });

      test('returns SkillFailure on LlmServiceException', () async {
        fakeLlmService.setException(
          const LlmServiceException('API 请求超时'),
        );

        final result = await skill.execute(
          config: testConfig,
          input: {
            'title': '晴天',
          },
        );

        expect(result, isA<SkillFailure>());
        expect((result as SkillFailure).message, 'API 请求超时');
      });

      test('returns SkillFailure on FormatException', () async {
        fakeLlmService.setResponse('Invalid response without JSON');

        final result = await skill.execute(
          config: testConfig,
          input: {
            'title': '晴天',
          },
        );

        expect(result, isA<SkillFailure>());
        expect((result as SkillFailure).message, contains('解析'));
      });
    });
  });
}
