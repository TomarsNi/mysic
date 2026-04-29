import 'dart:convert';

/// 歌曲识别结果
class RecognitionResult {
  /// 识别的歌曲名
  final String title;

  /// 识别的艺术家
  final String artist;

  /// 识别的专辑
  final String album;

  /// 专辑封面图片URL（从联网搜索获取）
  final String? albumArtUrl;

  /// 专辑封面Base64数据（下载后转换）
  final String? albumArtBase64;

  /// 置信度（high/medium/low）
  final String confidence;

  /// 信息来源（knowledge/web_search）
  final String source;

  /// 判断依据
  final String reason;

  const RecognitionResult({
    required this.title,
    required this.artist,
    required this.album,
    this.albumArtUrl,
    this.albumArtBase64,
    required this.confidence,
    required this.source,
    required this.reason,
  });

  /// 从 JSON 解析
  factory RecognitionResult.fromJson(Map<String, dynamic> json) {
    return RecognitionResult(
      title: json['title'] as String? ?? '',
      artist: json['artist'] as String? ?? '',
      album: json['album'] as String? ?? '',
      albumArtUrl: json['albumArtUrl'] as String?,
      albumArtBase64: json['albumArtBase64'] as String?,
      confidence: json['confidence'] as String? ?? 'low',
      source: json['source'] as String? ?? 'knowledge',
      reason: json['reason'] as String? ?? '',
    );
  }

  /// 从 JSON 字符串解析
  factory RecognitionResult.fromJsonString(String jsonString) {
    // 尝试提取 JSON 块（处理 AI 可能返回的额外文本）
    final jsonMatch = RegExp(
      r'\{[\s\S]*\}',
    ).firstMatch(jsonString);
    if (jsonMatch == null) {
      throw FormatException('无法从响应中提取 JSON: $jsonString');
    }

    final json = jsonDecode(jsonMatch.group(0)!) as Map<String, dynamic>;
    return RecognitionResult.fromJson(json);
  }

  /// 转换为 JSON
  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'artist': artist,
      'album': album,
      'albumArtUrl': albumArtUrl,
      'albumArtBase64': albumArtBase64,
      'confidence': confidence,
      'source': source,
      'reason': reason,
    };
  }

  @override
  String toString() {
    return 'RecognitionResult(title: $title, artist: $artist, album: $album, albumArtUrl: $albumArtUrl, confidence: $confidence, source: $source)';
  }
}