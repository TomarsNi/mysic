import 'package:shared_preferences/shared_preferences.dart';

/// 播放模式偏好设置
/// 用于持久化保存用户的播放模式选择
class PlayModePreference {
  static const _keyShuffleMode = 'play_mode_shuffle';
  static const _keyLoopMode = 'play_mode_loop';
  static const _keyLastSongId = 'last_song_id';

  /// 保存播放模式
  /// [shuffle] 是否随机模式
  /// [loopMode] 循环模式：'off' 或 'all'
  static Future<void> save({
    required bool shuffle,
    required String loopMode,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.setBool(_keyShuffleMode, shuffle),
      prefs.setString(_keyLoopMode, loopMode),
    ]);
  }

  /// 加载播放模式
  /// 返回 (shuffle, loopMode)
  /// 默认值：shuffle=false, loopMode='off'
  static Future<({bool shuffle, String loopMode})> load() async {
    final prefs = await SharedPreferences.getInstance();
    return (
      shuffle: prefs.getBool(_keyShuffleMode) ?? false,
      loopMode: prefs.getString(_keyLoopMode) ?? 'off',
    );
  }

  /// 保存最后播放的歌曲 ID
  static Future<void> saveLastSongId(int songId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyLastSongId, songId);
  }

  /// 加载最后播放的歌曲 ID
  /// 返回 null 表示无记录
  static Future<int?> loadLastSongId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyLastSongId);
  }

  /// 清除最后播放的歌曲 ID
  static Future<void> clearLastSongId() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyLastSongId);
  }
}
