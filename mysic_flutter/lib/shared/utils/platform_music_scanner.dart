import 'dart:async';
import '../../features/player/data/models/song.dart';

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

  const ScanResult({
    required this.totalFound,
    required this.newAdded,
    required this.duplicates,
    required this.scanDuration,
    this.errorMessage,
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

  /// 请求权限
  Future<bool> requestPermission();

  /// 检查权限
  Future<bool> hasPermission();

  /// 扫描音乐
  Future<ScanResult> scanMusic();

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
