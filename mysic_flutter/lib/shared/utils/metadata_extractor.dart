import 'package:audiotags/audiotags.dart';
import 'package:flutter/foundation.dart';
import 'wav_metadata_parser.dart';

/// 音频元数据
class AudioMetadata {
  AudioMetadata({
    required this.filePath,
    this.title,
    this.artist,
    this.album,
    this.duration,
  });

  final String filePath;
  final String? title;
  final String? artist;
  final String? album;
  final int? duration; // 秒

  /// 歌词文件路径（可选）
  String? lyricsPath;

  /// 是否有有效的元数据
  bool get hasMetadata =>
      title != null || artist != null || album != null || duration != null;
}

/// 统一元数据提取器
///
/// 根据平台和文件格式选择最佳的元数据提取方案：
/// - WAV 文件：纯 Dart RIFF INFO 解析（所有平台）
/// - 其他格式：audiotags
class MetadataExtractor {
  /// 提取音频文件元数据
  ///
  /// [filePath] 音频文件路径
  /// 返回元数据对象，如果提取失败返回 null
  static Future<AudioMetadata?> extract(String filePath) async {
    final extension = filePath.toLowerCase();

    // WAV 文件特殊处理：使用纯 Dart RIFF INFO 解析
    if (extension.endsWith('.wav')) {
      return _extractWavMetadata(filePath);
    }

    // 其他格式使用 audiotags
    return _extractWithAudiotags(filePath);
  }

  /// 提取 WAV 文件元数据（纯 Dart RIFF INFO 解析）
  static Future<AudioMetadata?> _extractWavMetadata(String filePath) async {
    final riffMetadata = await WavMetadataParser.parse(filePath);
    if (riffMetadata != null) {
      return AudioMetadata(
        filePath: filePath,
        title: riffMetadata['title'],
        artist: riffMetadata['artist'],
        album: riffMetadata['album'],
        duration: null, // RIFF INFO 通常不包含时长
      );
    }

    // RIFF INFO 解析失败，尝试 audiotags（可能会失败）
    return _extractWithAudiotags(filePath);
  }

  /// 使用 audiotags 提取元数据
  static Future<AudioMetadata?> _extractWithAudiotags(String filePath) async {
    try {
      final tag = await AudioTags.read(filePath);
      if (tag != null) {
        return AudioMetadata(
          filePath: filePath,
          title: tag.title,
          artist: tag.trackArtist,
          album: tag.album,
          duration: tag.duration,
        );
      }
    } catch (e) {
      // audiotags 失败时返回 null，让调用方回退到文件名
      debugPrint('audiotags 读取失败: $filePath, 错误: $e');
    }
    return null;
  }

  /// 从文件名智能提取标题（移除序号等前缀）
  static String cleanTitleFromFileName(String fileName) {
    // 移除扩展名
    var title = fileName.replaceAll(RegExp(r'\.[^.]+$'), '');
    // 移除开头的数字序号 (01. 或 01- 或 01 或 1. 或 1- 等)
    title = title.replaceFirst(RegExp(r'^\d+[\s.\-_]*'), '');
    return title.trim();
  }
}
