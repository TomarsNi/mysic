import 'dart:io';
import '../../features/player/data/models/song.dart';
import 'platform_music_scanner.dart';
import 'windows_music_scanner.dart';
import 'mobile_music_scanner.dart';

// 导出类型供外部使用
export 'platform_music_scanner.dart' show ScanState, ScanProgress, ScanResult, ScanOptions;

/// 音乐扫描服务
/// 根据平台自动选择合适的扫描器实现
class MusicScanner {
  late final PlatformMusicScanner _platformScanner;

  MusicScanner({
    List<String>? audioFormats,
    int? minFileSizeKb,
    bool? autoDedupe,
  }) {
    if (Platform.isWindows || Platform.isLinux) {
      _platformScanner = WindowsMusicScanner();
    } else {
      _platformScanner = MobileMusicScanner();
    }

    // 设置扫描选项
    if (audioFormats != null || minFileSizeKb != null || autoDedupe != null) {
      _platformScanner.setOptions(ScanOptions(
        audioFormats: audioFormats ?? const ['mp3', 'flac', 'wav', 'm4a', 'ogg', 'aac', 'wma', 'ape'],
        minFileSizeKb: minFileSizeKb ?? 100,
        autoDedupe: autoDedupe ?? true,
      ));
    }
  }

  // 委托给平台实现
  Stream<ScanState> get stateStream => _platformScanner.stateStream;
  Stream<ScanProgress> get progressStream => _platformScanner.progressStream;
  ScanState get state => _platformScanner.state;
  bool get isScanning => _platformScanner.isScanning;

  /// 请求存储权限
  Future<bool> requestPermission() => _platformScanner.requestPermission();

  /// 检查是否有权限
  Future<bool> hasPermission() => _platformScanner.hasPermission();

  /// 扫描本地音乐
  Future<ScanResult> scanMusic() => _platformScanner.scanMusic();

  /// 扫描指定目录的音乐
  Future<ScanResult> scanMusicInDirectory(String directory) =>
      _platformScanner.scanMusicInDirectory(directory);

  /// 取消扫描
  void cancelScan() => _platformScanner.cancelScan();

  /// 从数据库获取所有歌曲
  Future<List<Song>> getAllSongs() => _platformScanner.getAllSongs();

  /// 从数据库获取歌曲数量
  Future<int> getSongCount() => _platformScanner.getSongCount();

  /// 搜索歌曲
  Future<List<Song>> searchSongs(String query) async {
    if (query.isEmpty) return getAllSongs();

    final allSongs = await getAllSongs();
    final lowerQuery = query.toLowerCase();
    return allSongs.where((song) {
      return song.title.toLowerCase().contains(lowerQuery) ||
          (song.artist?.toLowerCase().contains(lowerQuery) ?? false) ||
          (song.album?.toLowerCase().contains(lowerQuery) ?? false);
    }).toList();
  }

  /// 删除歌曲
  Future<void> deleteSong(int songId) => _platformScanner.deleteSong(songId);

  /// 清空所有歌曲
  Future<void> clearAllSongs() => _platformScanner.clearAllSongs();

  /// 重置状态
  void reset() {
    _platformScanner.updateState(ScanState.idle);
    _platformScanner.updateProgress(const ScanProgress());
  }

  /// 释放资源
  Future<void> dispose() => _platformScanner.dispose();
}
