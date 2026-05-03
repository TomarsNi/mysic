/// 扫描目录配置数据模型
/// 用于存储扫描目录与歌单的关联关系
class ScanDirectoryConfig {
  /// 目录名称/路径
  final String directory;

  /// 关联的歌单 ID（可空）
  final int? playlistId;

  /// 关联的歌单名称（可空）
  final String? playlistName;

  const ScanDirectoryConfig({
    required this.directory,
    this.playlistId,
    this.playlistName,
  });

  /// 判断是否已关联歌单
  /// 需要 playlistId 和 playlistName 同时存在才算已关联
  bool get isLinked => playlistId != null && playlistName != null;

  /// 从 JSON 创建配置对象
  factory ScanDirectoryConfig.fromJson(Map<String, dynamic> json) {
    return ScanDirectoryConfig(
      directory: json['directory'] as String,
      playlistId: json['playlistId'] as int?,
      playlistName: json['playlistName'] as String?,
    );
  }

  /// 转换为 JSON
  Map<String, dynamic> toJson() {
    return {
      'directory': directory,
      'playlistId': playlistId,
      'playlistName': playlistName,
    };
  }

  /// 复制并修改部分字段
  /// clearPlaylist: true 时清除歌单关联
  ScanDirectoryConfig copyWith({
    String? directory,
    int? playlistId,
    String? playlistName,
    bool clearPlaylist = false,
  }) {
    return ScanDirectoryConfig(
      directory: directory ?? this.directory,
      playlistId: clearPlaylist ? null : (playlistId ?? this.playlistId),
      playlistName: clearPlaylist ? null : (playlistName ?? this.playlistName),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ScanDirectoryConfig &&
        other.directory == directory &&
        other.playlistId == playlistId &&
        other.playlistName == playlistName;
  }

  @override
  int get hashCode => Object.hash(directory, playlistId, playlistName);

  @override
  String toString() {
    return 'ScanDirectoryConfig(directory: $directory, playlistId: $playlistId, playlistName: $playlistName)';
  }
}
