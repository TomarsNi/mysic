// lib/features/ai_skills/skills/song_recognition/song_recognition_skill.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:mysic_flutter/core/utils/app_logger.dart';
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
  final http.Client _httpClient;

  SongRecognitionSkill({LlmService? llmService, http.Client? httpClient})
    : _llmService = llmService ?? LlmService(),
      _httpClient = httpClient ?? http.Client();

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

      // 下载并转换封面图片
      String? albumArtBase64;
      if (result.albumArtUrl != null && result.albumArtUrl!.isNotEmpty) {
        albumArtBase64 = await _downloadAndConvertToBase64(result.albumArtUrl!);
      }

      // 检查是否有变化
      final currentTitle = input['currentTitle'] as String? ?? '';
      final currentArtist = input['currentArtist'] as String? ?? '';
      final currentAlbum = input['currentAlbum'] as String? ?? '';

      if (result.title == currentTitle &&
          result.artist == currentArtist &&
          result.album == currentAlbum &&
          albumArtBase64 == null) {
        return SkillNoChange('歌曲信息已验证正确');
      }

      return SkillSuccess({
        'title': result.title,
        'artist': result.artist,
        'album': result.album,
        'albumArtUrl': result.albumArtUrl,
        'albumArtBase64': albumArtBase64,
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

  /// 下载图片并转换为 Base64（带压缩）
  Future<String?> _downloadAndConvertToBase64(String imageUrl) async {
    try {
      final response = await _httpClient
          .get(Uri.parse(imageUrl))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) return null;

      final bytes = response.bodyBytes;
      if (bytes.isEmpty) return null;

      // 解码图片
      final image = img.decodeImage(bytes);
      if (image == null) return null;

      // 压缩：限制最大尺寸为 500x500
      const maxSize = 500;
      var processedImage = image;
      if (image.width > maxSize || image.height > maxSize) {
        processedImage = img.copyResize(
          image,
          width: maxSize,
          height: maxSize,
          maintainAspect: true,
        );
      }

      // 编码为 JPEG（质量 85%）
      final compressedBytes = img.encodeJpg(processedImage, quality: 85);
      return base64Encode(compressedBytes);
    } catch (e) {
      AppLogger.w('SongRecognitionSkill#_downloadAndConvertToBase64', '封面下载失败: $e');
      return null;
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
  "albumArtUrl": "专辑封面图片URL",
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
