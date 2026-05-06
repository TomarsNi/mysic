import 'dart:core';

/// 歌曲数据模型
class Song {
  final int? id;
  final String title;
  final String? artist;
  final String? album;
  final int? duration; // 秒（audiotags 返回的单位）
  final String filePath;
  final String? albumArtPath;
  final String? albumArtBase64;
  final String? lyricsPath;
  final int? dateAdded;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Song({
    this.id,
    required this.title,
    this.artist,
    this.album,
    this.duration,
    required this.filePath,
    this.albumArtPath,
    this.albumArtBase64,
    this.lyricsPath,
    this.dateAdded,
    required this.createdAt,
    required this.updatedAt,
  });

  /// 从数据库 Map 创建 Song 对象
  factory Song.fromMap(Map<String, dynamic> map) {
    // 支持毫秒时间戳或 ISO8601 字符串
    DateTime parseTimestamp(dynamic value) {
      if (value == null) return DateTime.now();
      if (value is int) {
        return DateTime.fromMillisecondsSinceEpoch(value);
      }
      return DateTime.parse(value as String);
    }

    return Song(
      id: map['id'] as int?,
      title: map['title'] as String,
      artist: map['artist'] as String?,
      album: map['album'] as String?,
      duration: map['duration'] as int?,
      filePath: map['file_path'] as String,
      albumArtPath: map['album_art_path'] as String?,
      albumArtBase64: map['album_art_base64'] as String?,
      lyricsPath: map['lyrics_path'] as String?,
      dateAdded: map['date_added'] as int?,
      createdAt: parseTimestamp(map['created_at']),
      updatedAt: parseTimestamp(map['updated_at']),
    );
  }

  /// 转换为数据库 Map
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'title': title,
      'artist': artist,
      'album': album,
      'duration': duration,
      'file_path': filePath,
      'album_art_path': albumArtPath,
      'album_art_base64': albumArtBase64,
      'lyrics_path': lyricsPath,
      'date_added': dateAdded,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// 复制并修改部分字段
  Song copyWith({
    int? id,
    String? title,
    String? artist,
    String? album,
    int? duration,
    String? filePath,
    String? albumArtPath,
    String? albumArtBase64,
    String? lyricsPath,
    int? dateAdded,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Song(
      id: id ?? this.id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      duration: duration ?? this.duration,
      filePath: filePath ?? this.filePath,
      albumArtPath: albumArtPath ?? this.albumArtPath,
      albumArtBase64: albumArtBase64 ?? this.albumArtBase64,
      lyricsPath: lyricsPath ?? this.lyricsPath,
      dateAdded: dateAdded ?? this.dateAdded,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// 格式化时长显示 (mm:ss)
  String get formattedDuration {
    if (duration == null) return '--:--';
    final minutes = duration! ~/ 60;
    final seconds = duration! % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  /// 获取艺术家名称（未知时显示默认值）
  String get displayArtist => artist ?? '未知艺术家';

  /// 获取专辑名称（未知时显示默认值）
  String get displayAlbum => album ?? '未知专辑';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Song && other.id == id && other.filePath == filePath;
  }

  @override
  int get hashCode => Object.hash(id, filePath);

  @override
  String toString() {
    return 'Song(id: $id, title: $title, artist: $artist, album: $album)';
  }
}
