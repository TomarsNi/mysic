import 'song.dart';

/// 歌单数据模型
class Playlist {
  final int? id;
  final String name;
  final String? description;
  final String? coverPath;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<Song>? songs; // 可选的歌曲列表

  const Playlist({
    this.id,
    required this.name,
    this.description,
    this.coverPath,
    required this.createdAt,
    required this.updatedAt,
    this.songs,
  });

  /// 从数据库 Map 创建 Playlist 对象
  factory Playlist.fromMap(Map<String, dynamic> map, {List<Song>? songs}) {
    return Playlist(
      id: map['id'] as int?,
      name: map['name'] as String,
      description: map['description'] as String?,
      coverPath: map['cover_path'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      songs: songs,
    );
  }

  /// 转换为数据库 Map
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'description': description,
      'cover_path': coverPath,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// 复制并修改部分字段
  Playlist copyWith({
    int? id,
    String? name,
    String? description,
    String? coverPath,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<Song>? songs,
  }) {
    return Playlist(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      coverPath: coverPath ?? this.coverPath,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      songs: songs ?? this.songs,
    );
  }

  /// 获取歌曲数量
  int get songCount => songs?.length ?? 0;

  /// 获取总时长（毫秒）
  int get totalDuration {
    if (songs == null || songs!.isEmpty) return 0;
    return songs!.fold(0, (sum, song) => sum + (song.duration ?? 0));
  }

  /// 格式化总时长显示 (HH:mm:ss 或 mm:ss)
  String get formattedTotalDuration {
    final totalMs = totalDuration;
    if (totalMs == 0) return '00:00';

    final hours = totalMs ~/ 3600000;
    final minutes = (totalMs % 3600000) ~/ 60000;
    final seconds = (totalMs % 60000) ~/ 1000;

    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  /// 是否为空歌单
  bool get isEmpty => songs == null || songs!.isEmpty;

  /// 是否包含指定歌曲
  bool containsSong(Song song) {
    if (songs == null) return false;
    return songs!.any((s) => s.id == song.id || s.filePath == song.filePath);
  }

  /// 添加歌曲
  Playlist addSong(Song song) {
    if (containsSong(song)) return this;
    return copyWith(
      songs: [...(songs ?? []), song],
      updatedAt: DateTime.now(),
    );
  }

  /// 移除歌曲
  Playlist removeSong(Song song) {
    if (songs == null) return this;
    return copyWith(
      songs: songs!.where((s) => s.id != song.id && s.filePath != song.filePath).toList(),
      updatedAt: DateTime.now(),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Playlist && other.id == id && other.name == name;
  }

  @override
  int get hashCode => Object.hash(id, name);

  @override
  String toString() {
    return 'Playlist(id: $id, name: $name, songCount: $songCount)';
  }
}

/// 歌单-歌曲关联模型
class PlaylistSong {
  final int? id;
  final int playlistId;
  final int songId;
  final int position;
  final DateTime addedAt;

  const PlaylistSong({
    this.id,
    required this.playlistId,
    required this.songId,
    required this.position,
    required this.addedAt,
  });

  /// 从数据库 Map 创建 PlaylistSong 对象
  factory PlaylistSong.fromMap(Map<String, dynamic> map) {
    return PlaylistSong(
      id: map['id'] as int?,
      playlistId: map['playlist_id'] as int,
      songId: map['song_id'] as int,
      position: map['position'] as int,
      addedAt: DateTime.parse(map['added_at'] as String),
    );
  }

  /// 转换为数据库 Map
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'playlist_id': playlistId,
      'song_id': songId,
      'position': position,
      'added_at': addedAt.toIso8601String(),
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PlaylistSong &&
        other.playlistId == playlistId &&
        other.songId == songId;
  }

  @override
  int get hashCode => Object.hash(playlistId, songId);

  @override
  String toString() {
    return 'PlaylistSong(playlistId: $playlistId, songId: $songId, position: $position)';
  }
}
