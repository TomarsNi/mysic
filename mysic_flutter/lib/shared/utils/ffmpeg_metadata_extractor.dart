import 'dart:io';
import 'package:ffmpeg_kit_flutter_audio/ffprobe_kit.dart';
import 'package:flutter/foundation.dart';

/// FFmpeg 元数据提取器
///
/// 使用 ffmpeg_kit_flutter 提取音频文件元数据
/// 支持 WAV、MP3、FLAC、M4A 等多种格式
class FFmpegMetadataExtractor {
  /// 提取音频文件元数据
  ///
  /// 返回包含元数据的 Map，如果提取失败返回 null
  static Future<Map<String, String>?> extract(String filePath) async {
    try {
      // 使用 FFprobeKit 获取媒体信息
      final session = await FFprobeKit.getMediaInformation(filePath);
      final info = session.getMediaInformation();

      if (info == null) return null;

      final result = <String, String>{};

      // 从 MediaInformation 直接获取标签
      final tags = info.getTags();
      if (tags != null) {
        _extractTags(tags, result);
      }

      // 提取流信息（第一个音频流）
      final streams = info.getStreams();
      if (streams.isNotEmpty) {
        final stream = streams.first;
        final streamTags = stream.getTags();
        _extractTags(streamTags, result);
      }

      return result.isEmpty ? null : result;
    } catch (e) {
      debugPrint('FFmpeg 元数据提取失败: $filePath, 错误: $e');
      return null;
    }
  }

  /// 从 FFmpeg 标签中提取元数据
  static void _extractTags(dynamic tags, Map<String, String> result) {
    // FFmpeg 标签名称映射
    final tagMapping = {
      'title': 'title',
      'artist': 'artist',
      'album': 'album',
      'album_artist': 'artist',
      'author': 'artist',
      'composer': 'artist',
      'date': 'date',
      'year': 'date',
      'genre': 'genre',
      'track': 'track',
    };

    try {
      // tags 可能是 Map 或其他类型
      if (tags is Map) {
        tags.forEach((key, value) {
          final keyStr = key.toString().toLowerCase();
          final fieldName = tagMapping[keyStr];
          if (fieldName != null && value != null) {
            final valueStr = value.toString().trim();
            if (valueStr.isNotEmpty && !result.containsKey(fieldName)) {
              result[fieldName] = valueStr;
            }
          }
        });
      }
    } catch (e) {
      debugPrint('解析 FFmpeg 标签失败: $e');
    }
  }

  /// 检查当前平台是否支持 FFmpeg
  static bool get isSupported {
    // ffmpeg_kit_flutter_min 只支持 Android、iOS、macOS
    return Platform.isAndroid || Platform.isIOS || Platform.isMacOS;
  }
}
