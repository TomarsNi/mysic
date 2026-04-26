import 'dart:convert';

/// 歌词搜索结果
class LyricsResult {
  /// 是否找到歌词
  final bool found;

  /// LRC 格式歌词内容
  final String? lyrics;

  /// 歌词来源
  final String? source;

  /// 匹配的歌曲信息
  final MatchedSong? matchedSong;

  /// 未找到原因
  final String? reason;

  const LyricsResult({
    required this.found,
    this.lyrics,
    this.source,
    this.matchedSong,
    this.reason,
  });

  /// 从 JSON 解析
  factory LyricsResult.fromJson(Map<String, dynamic> json) {
    return LyricsResult(
      found: json['found'] as bool? ?? false,
      lyrics: json['lyrics'] as String?,
      source: json['source'] as String?,
      matchedSong: json['matchedSong'] != null
          ? MatchedSong.fromJson(json['matchedSong'] as Map<String, dynamic>)
          : null,
      reason: json['reason'] as String?,
    );
  }

  /// 从 JSON 字符串解析
  factory LyricsResult.fromJsonString(String jsonString) {
    // 尝试提取 JSON 块（处理 AI 可能返回的额外文本）
    final jsonMatch = RegExp(
      r'\{[\s\S]*\}',
    ).firstMatch(jsonString);
    if (jsonMatch == null) {
      throw FormatException('无法从响应中提取 JSON: $jsonString');
    }

    final json = jsonDecode(jsonMatch.group(0)!) as Map<String, dynamic>;
    return LyricsResult.fromJson(json);
  }

  /// 转换为 JSON
  Map<String, dynamic> toJson() {
    return {
      'found': found,
      'lyrics': lyrics,
      'source': source,
      'matchedSong': matchedSong?.toJson(),
      'reason': reason,
    };
  }

  @override
  String toString() {
    return 'LyricsResult(found: $found, source: $source, matchedSong: $matchedSong)';
  }
}

/// 匹配的歌曲信息
class MatchedSong {
  final String title;
  final String artist;

  const MatchedSong({
    required this.title,
    required this.artist,
  });

  factory MatchedSong.fromJson(Map<String, dynamic> json) {
    return MatchedSong(
      title: json['title'] as String? ?? '',
      artist: json['artist'] as String? ?? '',
    );
  }

  /// 转换为 JSON
  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'artist': artist,
    };
  }

  @override
  String toString() => 'MatchedSong(title: $title, artist: $artist)';
}
