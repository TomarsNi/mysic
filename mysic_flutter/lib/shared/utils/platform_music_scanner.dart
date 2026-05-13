import 'dart:async';
import '../../features/player/data/models/song.dart';

/// 扫描选项配置
class ScanOptions {
  final List<String> audioFormats;
  final int minFileSizeKb;
  final bool autoDedupe;

  /// 元数据提取并行批次大小
  final int metadataBatchSize;

  /// 封面获取并行批次大小（移动端）
  final int artworkBatchSize;

  /// 进度更新间隔（文件数）
  final int progressUpdateInterval;

  const ScanOptions({
    this.audioFormats = const [
      'mp3',
      'flac',
      'wav',
      'm4a',
      'ogg',
      'aac',
      'wma',
      'ape',
    ],
    this.minFileSizeKb = 100,
    this.autoDedupe = true,
    this.metadataBatchSize = 50,
    this.artworkBatchSize = 10,
    this.progressUpdateInterval = 100,
  });

  /// 最小文件大小（字节）
  int get minFileSizeBytes => minFileSizeKb * 1024;

  /// 音频格式扩展名集合
  Set<String> get audioExtensions => audioFormats.map((f) => '.$f').toSet();
}

/// 扫描状态
enum ScanState {
  idle,
  scanning,
  saving,
  completed,
  error,
}

/// 扫描进度
class ScanProgress {
  final String currentPath;
  final int filesScanned;
  final int songsFound;
  final double progress;

  const ScanProgress({
    this.currentPath = '',
    this.filesScanned = 0,
    this.songsFound = 0,
    this.progress = 0.0,
  });

  ScanProgress copyWith({
    String? currentPath,
    int? filesScanned,
    int? songsFound,
    double? progress,
  }) {
    return ScanProgress(
      currentPath: currentPath ?? this.currentPath,
      filesScanned: filesScanned ?? this.filesScanned,
      songsFound: songsFound ?? this.songsFound,
      progress: progress ?? this.progress,
    );
  }
}

/// 扫描结果
class ScanResult {
  final int totalFound;
  final int newAdded;
  final int duplicates;
  final Duration scanDuration;
  final String? errorMessage;
  /// 本次扫描新增的歌曲 ID 列表
  final List<int> newSongIds;

  const ScanResult({
    required this.totalFound,
    required this.newAdded,
    required this.duplicates,
    required this.scanDuration,
    this.errorMessage,
    this.newSongIds = const [],
  });

  bool get isSuccess => errorMessage == null;
}

/// 平台音乐扫描器抽象基类
abstract class PlatformMusicScanner {
  // 状态流控制器
  final _stateController = StreamController<ScanState>.broadcast();
  final _progressController = StreamController<ScanProgress>.broadcast();

  // 公开的流
  Stream<ScanState> get stateStream => _stateController.stream;
  Stream<ScanProgress> get progressStream => _progressController.stream;

  // 当前状态
  ScanState _state = ScanState.idle;
  ScanState get state => _state;
  bool get isScanning => _state == ScanState.scanning || _state == ScanState.saving;

  // 取消标志
  bool _cancelled = false;
  bool get isCancelled => _cancelled;

  /// 扫描选项
  ScanOptions _options = const ScanOptions();
  ScanOptions get options => _options;

  /// 设置扫描选项
  void setOptions(ScanOptions options) {
    _options = options;
  }

  /// 请求权限
  Future<bool> requestPermission();

  /// 检查权限
  Future<bool> hasPermission();

  /// 扫描音乐
  Future<ScanResult> scanMusic();

  /// 扫描指定目录的音乐
  Future<ScanResult> scanMusicInDirectory(String directory);

  /// 删除歌曲
  Future<void> deleteSong(int songId);

  /// 获取所有歌曲
  Future<List<Song>> getAllSongs();

  /// 根据 ID 列表获取歌曲
  Future<List<Song>> getSongsByIds(List<int> ids);

  /// 获取歌曲数量
  Future<int> getSongCount();

  /// 清空所有歌曲
  Future<void> clearAllSongs();

  /// 取消扫描
  void cancelScan() {
    _cancelled = true;
  }

  /// 重置取消标志
  void resetCancel() {
    _cancelled = false;
  }

  /// 更新状态
  void updateState(ScanState newState) {
    if (_state != newState) {
      _state = newState;
      _stateController.add(_state);
    }
  }

  /// 更新进度
  void updateProgress(ScanProgress progress) {
    _progressController.add(progress);
  }

  /// 释放资源
  Future<void> dispose() async {
    await _stateController.close();
    await _progressController.close();
  }
}
