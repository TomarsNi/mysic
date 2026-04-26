// lib/features/ai_skills/skills/song_recognition/song_recognition_skill.dart
import 'package:flutter/material.dart';
import 'package:mysic_flutter/features/ai_skills/core/ai_skill.dart';
import 'package:mysic_flutter/features/ai_skills/core/llm_service.dart';
import 'package:mysic_flutter/features/ai_skills/core/skill_result.dart';
import 'package:mysic_flutter/features/ai_skills/skills/song_recognition/recognition_result.dart';
import 'package:mysic_flutter/features/settings/data/models/api_config.dart';
import 'package:path/path.dart' as p;

/// 歌曲识别 Skill
/// 通过文件名和现有元数据，识别正确的歌曲名称、艺术家、专辑
class SongRecognitionSkill implements AiSkill {
  final LlmService _llmService;

  SongRecognitionSkill({LlmService? llmService})
    : _llmService = llmService ?? LlmService();

  @override
  String get id => 'song_recognition';

  @override
  String get displayName => '识别歌曲信息';

  @override
  String get description => '识别歌曲名称、艺术家、专辑';

  @override
  IconData get icon => Icons.music_note_rounded;

  @override
  Future<SkillResult> execute({
    required ApiConfig config,
    required Map<String, dynamic> input,
  }) async {
    final filePath = input['filePath'] as String?;
    if (filePath == null || filePath.isEmpty) {
      return const SkillFailure('缺少文件路径');
    }

    try {
      final prompt = buildPrompt(
        filePath: filePath,
        currentTitle: input['currentTitle'] as String?,
        currentArtist: input['currentArtist'] as String?,
        currentAlbum: input['currentAlbum'] as String?,
      );

      final response = await _llmService.chat(
        config: config,
        prompt: prompt,
        enableWebSearch: true,
      );

      final result = parseResponse(response);

      // 检查是否有变化
      final currentTitle = input['currentTitle'] as String? ?? '';
      final currentArtist = input['currentArtist'] as String? ?? '';
      final currentAlbum = input['currentAlbum'] as String? ?? '';

      if (result.title == currentTitle &&
          result.artist == currentArtist &&
          result.album == currentAlbum) {
        return SkillNoChange('歌曲信息已验证正确');
      }

      return SkillSuccess({
        'title': result.title,
        'artist': result.artist,
        'album': result.album,
        'confidence': result.confidence,
        'source': result.source,
        'reason': result.reason,
      });
    } on LlmServiceException catch (e) {
      return SkillFailure(e.message, error: e);
    } on FormatException catch (e) {
      return SkillFailure('解析 AI 响应失败: ${e.message}', error: e);
    } catch (e) {
      return SkillFailure('识别失败: $e', error: e);
    }
  }

  /// 构建 Prompt
  String buildPrompt({
    required String filePath,
    String? currentTitle,
    String? currentArtist,
    String? currentAlbum,
  }) {
    final fileName = p.basenameWithoutExtension(filePath);

    return '''
请根据以下歌曲信息，识别正确的歌曲名称、艺术家和专辑名称。
如果信息可能不正确，请通过联网搜索验证。

当前信息：
- 文件名：$fileName
- 歌曲名：${currentTitle ?? '未知'}
- 艺术家：${currentArtist ?? '未知'}
- 专辑：${currentAlbum ?? '未知'}

请以 JSON 格式返回结果：
{
  "title": "正确的歌曲名",
  "artist": "正确的艺术家",
  "album": "正确的专辑",
  "confidence": "high/medium/low",
  "source": "knowledge/web_search",
  "reason": "简要说明判断依据"
}
''';
  }

  /// 解析 AI 响应
  RecognitionResult parseResponse(String response) {
    return RecognitionResult.fromJsonString(response);
  }
}
