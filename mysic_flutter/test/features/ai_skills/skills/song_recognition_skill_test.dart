// test/features/ai_skills/skills/song_recognition_skill_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mysic_flutter/features/ai_skills/core/llm_service.dart';
import 'package:mysic_flutter/features/ai_skills/core/skill_result.dart';
import 'package:mysic_flutter/features/ai_skills/skills/song_recognition/song_recognition_skill.dart';
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
  group('SongRecognitionSkill', () {
    late SongRecognitionSkill skill;
    late FakeLlmService fakeLlmService;
    late ApiConfig testConfig;

    setUp(() {
      fakeLlmService = FakeLlmService();
      skill = SongRecognitionSkill(llmService: fakeLlmService);
      testConfig = ApiConfig.defaultFor(ApiProvider.aliyun).copyWith(
        apiKey: 'test-api-key',
        isEnabled: true,
      );
    });

    group('properties', () {
      test('has correct id', () {
        expect(skill.id, 'song_recognition');
      });

      test('has correct displayName', () {
        expect(skill.displayName, '识别歌曲信息');
      });

      test('has correct description', () {
        expect(skill.description, '识别歌曲名称、艺术家、专辑');
      });
    });

    group('buildPrompt', () {
      test('builds correct prompt from input', () {
        final prompt = skill.buildPrompt(
          filePath: '/music/晴天.mp3',
          currentTitle: '未知歌曲',
          currentArtist: '未知艺术家',
          currentAlbum: '未知专辑',
        );

        // 文件名不含扩展名（使用 basenameWithoutExtension）
        expect(prompt, contains('晴天'));
        expect(prompt, contains('未知歌曲'));
        expect(prompt, contains('未知艺术家'));
        expect(prompt, contains('未知专辑'));
        expect(prompt, contains('JSON'));
      });

      test('handles null metadata in prompt', () {
        final prompt = skill.buildPrompt(
          filePath: '/music/test.mp3',
        );

        expect(prompt, contains('test'));
        expect(prompt, contains('未知'));
      });
    });

    group('parseResponse', () {
      test('parses AI response correctly', () {
        const aiResponse = '''
根据文件名和联网搜索，识别结果如下：
{
  "title": "晴天",
  "artist": "周杰伦",
  "album": "叶惠美",
  "confidence": "high",
  "source": "web_search",
  "reason": "文件名与歌曲名匹配，通过搜索确认"
}
''';

        final result = skill.parseResponse(aiResponse);
        expect(result.title, '晴天');
        expect(result.artist, '周杰伦');
        expect(result.album, '叶惠美');
        expect(result.confidence, 'high');
      });
    });

    group('execute', () {
      test('returns SkillFailure when filePath is missing', () async {
        final result = await skill.execute(
          config: testConfig,
          input: {},
        );

        expect(result, isA<SkillFailure>());
        expect((result as SkillFailure).message, '缺少文件路径');
      });

      test('returns SkillFailure when filePath is empty', () async {
        final result = await skill.execute(
          config: testConfig,
          input: {'filePath': ''},
        );

        expect(result, isA<SkillFailure>());
        expect((result as SkillFailure).message, '缺少文件路径');
      });

      test('returns SkillSuccess when info changes', () async {
        fakeLlmService.setResponse('''
{
  "title": "晴天",
  "artist": "周杰伦",
  "album": "叶惠美",
  "confidence": "high",
  "source": "web_search",
  "reason": "文件名匹配"
}
''');

        final result = await skill.execute(
          config: testConfig,
          input: {
            'filePath': '/music/晴天.mp3',
            'currentTitle': '未知歌曲',
            'currentArtist': '未知艺术家',
            'currentAlbum': '未知专辑',
          },
        );

        expect(result, isA<SkillSuccess>());
        final data = (result as SkillSuccess).data;
        expect(data['title'], '晴天');
        expect(data['artist'], '周杰伦');
        expect(data['album'], '叶惠美');
        expect(data['confidence'], 'high');
        expect(data['source'], 'web_search');
      });

      test('returns SkillNoChange when info matches', () async {
        fakeLlmService.setResponse('''
{
  "title": "晴天",
  "artist": "周杰伦",
  "album": "叶惠美",
  "confidence": "high",
  "source": "knowledge",
  "reason": "信息已正确"
}
''');

        final result = await skill.execute(
          config: testConfig,
          input: {
            'filePath': '/music/晴天.mp3',
            'currentTitle': '晴天',
            'currentArtist': '周杰伦',
            'currentAlbum': '叶惠美',
          },
        );

        expect(result, isA<SkillNoChange>());
        expect((result as SkillNoChange).message, '歌曲信息已验证正确');
      });

      test('returns SkillFailure on LlmServiceException', () async {
        fakeLlmService.setException(
          const LlmServiceException('API 请求超时'),
        );

        final result = await skill.execute(
          config: testConfig,
          input: {
            'filePath': '/music/test.mp3',
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
            'filePath': '/music/test.mp3',
          },
        );

        expect(result, isA<SkillFailure>());
        expect((result as SkillFailure).message, contains('解析'));
      });
    });
  });
}
