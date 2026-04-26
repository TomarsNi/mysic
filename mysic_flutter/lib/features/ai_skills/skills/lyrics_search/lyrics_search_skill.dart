// lib/features/ai_skills/skills/lyrics_search/lyrics_search_skill.dart
import 'package:flutter/material.dart';
import 'package:mysic_flutter/features/ai_skills/core/ai_skill.dart';
import 'package:mysic_flutter/features/ai_skills/core/llm_service.dart';
import 'package:mysic_flutter/features/ai_skills/core/skill_result.dart';
import 'package:mysic_flutter/features/ai_skills/skills/lyrics_search/lyrics_result.dart';
import 'package:mysic_flutter/features/settings/data/models/api_config.dart';

/// 歌词搜索 Skill
/// 根据歌曲信息搜索匹配的 LRC 格式歌词
class LyricsSearchSkill implements AiSkill {
  final LlmService _llmService;

  LyricsSearchSkill({LlmService? llmService})
      : _llmService = llmService ?? LlmService();

  @override
  String get id => 'lyrics_search';

  @override
  String get displayName => '搜索歌词';

  @override
  String get description => '根据歌曲信息搜索匹配歌词';

  @override
  IconData get icon => Icons.lyrics_rounded;

  @override
  Future<SkillResult> execute({
    required ApiConfig config,
    required Map<String, dynamic> input,
  }) async {
    final title = input['title'] as String?;

    if (title == null || title.isEmpty) {
      return const SkillFailure('缺少歌曲名称');
    }

    try {
      final prompt = buildPrompt(
        title: title,
        artist: input['artist'] as String?,
        album: input['album'] as String?,
      );

      final response = await _llmService.chat(
        config: config,
        prompt: prompt,
        enableWebSearch: true,
      );

      final result = parseResponse(response);

      if (!result.found) {
        return SkillFailure(result.reason ?? '未找到匹配歌词');
      }

      return SkillSuccess({
        'lyrics': result.lyrics,
        'source': result.source,
        'matchedSong': result.matchedSong != null
            ? {
                'title': result.matchedSong!.title,
                'artist': result.matchedSong!.artist,
              }
            : null,
      });
    } on LlmServiceException catch (e) {
      return SkillFailure(e.message, error: e);
    } on FormatException catch (e) {
      return SkillFailure('解析 AI 响应失败: ${e.message}', error: e);
    } catch (e) {
      return SkillFailure('搜索失败: $e', error: e);
    }
  }

  /// 构建 Prompt
  String buildPrompt({
    required String title,
    String? artist,
    String? album,
  }) {
    return '''
请搜索以下歌曲的 LRC 格式歌词（带时间轴）：
- 歌曲名：$title
- 艺术家：${artist ?? '未知'}
- 专辑：${album ?? '未知'}

请通过联网搜索找到准确的歌词，并以 LRC 格式返回：
[00:00.00]第一行歌词
[00:05.00]第二行歌词
...

如果找不到歌词，请返回：
{
  "found": false,
  "reason": "未找到匹配歌词"
}

如果找到歌词，请返回：
{
  "found": true,
  "lyrics": "完整的LRC歌词内容",
  "source": "歌词来源网站",
  "matchedSong": {
    "title": "实际匹配的歌曲名",
    "artist": "实际匹配的艺术家"
  }
}
''';
  }

  /// 解析 AI 响应
  LyricsResult parseResponse(String response) {
    return LyricsResult.fromJsonString(response);
  }
}
