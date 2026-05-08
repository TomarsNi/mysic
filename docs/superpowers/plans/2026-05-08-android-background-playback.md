# Android 后台播放自动切歌修复实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 切换到 `just_audio` + `audio_service` 解决 Android 后台播放自动切歌问题

**Architecture:** 新增 `AudioHandler` 实现后台播放回调，重写 `AudioPlayerService` 使用 `just_audio`，保持现有 API 接口不变

**Tech Stack:** Flutter, just_audio, audio_service, audio_session

---

## 文件结构

```
lib/features/player/data/
├── models/
│   └── song.dart                    # 保持不变
├── services/
│   ├── audio_player_service.dart    # 重写，使用 just_audio
│   └── audio_handler.dart           # 新增，实现 AudioHandler
```

---

### Task 1: 更新依赖

**Files:**
- Modify: `mysic_flutter/pubspec.yaml`

- [ ] **Step 1: 移除 audioplayers，添加 just_audio 和 audio_service**

```yaml
dependencies:
  flutter:
    sdk: flutter

  # ... 其他依赖保持不变 ...

  # 音频播放 - 替换 audioplayers
  # audioplayers: ^6.0.0  # 移除
  just_audio: ^0.9.40
  audio_service: ^0.18.15
  audio_session: ^0.1.18  # 保留
```

- [ ] **Step 2: 获取新依赖**

Run: `cd mysic_flutter && flutter pub get`
Expected: 依赖安装成功

- [ ] **Step 3: 提交**

```bash
git add mysic_flutter/pubspec.yaml mysic_flutter/pubspec.lock
git commit -m "chore: 切换音频播放库到 just_audio + audio_service"
```

---

### Task 2: 创建 AudioHandler

**Files:**
- Create: `mysic_flutter/lib/features/player/data/services/audio_handler.dart`

- [ ] **Step 1: 创建 MysicAudioHandler 类**

```dart
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import '../models/song.dart';

/// 后台音频处理器
/// 实现 audio_service 的回调，处理后台播放、通知栏控制
class MysicAudioHandler extends BaseAudioHandler with QueueHandler, SeekHandler {
  final AudioPlayer _player;

  // 播放列表
  List<Song> _playlist = [];
  int _currentIndex = -1;

  // 循环模式
  bool _loopMode = false;

  MysicAudioHandler(this._player) {
    _init();
  }

  void _init() {
    // 监听播放状态
    _player.playerStateStream.listen((state) {
      _updatePlaybackState();
    });

    // 监听播放位置
    _player.positionStream.listen((position) {
      // 更新通知栏进度
    });

    // 监听歌曲时长
    _player.durationStream.listen((duration) {
      _updateMediaItem(duration);
    });

    // 监听播放完成
    _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        _onSongCompleted();
      }
    });
  }

  void _updatePlaybackState() {
    final state = _player.playerState;
    playbackState.add(PlaybackState(
      controls: [
        MediaControl.skipToPrevious,
        MediaControl.rewind,
        if (state.playing) MediaControl.pause else MediaControl.play,
        MediaControl.fastForward,
        MediaControl.skipToNext,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
        MediaAction.skipToNext,
        MediaAction.skipToPrevious,
      },
      androidCompactActionIndices: const [0, 2, 4],
      processingState: const {
        ProcessingState.idle: AudioProcessingState.idle,
        ProcessingState.loading: AudioProcessingState.loading,
        ProcessingState.ready: AudioProcessingState.ready,
        ProcessingState.completed: AudioProcessingState.completed,
        ProcessingState.buffering: AudioProcessingState.buffering,
      }[state.processingState]!,
      playing: state.playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
    ));
  }

  void _updateMediaItem(Duration? duration) {
    if (_currentIndex < 0 || _currentIndex >= _playlist.length) return;
    final song = _playlist[_currentIndex];
    mediaItem.add(MediaItem(
      id: song.id?.toString() ?? song.filePath,
      title: song.title,
      artist: song.artist ?? '未知艺术家',
      album: song.album ?? '未知专辑',
      duration: duration,
      artUri: song.albumArtPath != null ? Uri.file(song.albumArtPath!) : null,
    ));
  }

  void _onSongCompleted() {
    if (_loopMode || _currentIndex < _playlist.length - 1) {
      skipToNext();
    }
  }

  // AudioHandler 回调实现
  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() async {
    await _player.stop();
    await super.stop();
  }

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> skipToNext() async {
    if (_playlist.isEmpty) return;
    if (_currentIndex < _playlist.length - 1) {
      _currentIndex++;
    } else if (_loopMode) {
      _currentIndex = 0;
    } else {
      return;
    }
    await _playCurrentSong();
  }

  @override
  Future<void> skipToPrevious() async {
    if (_playlist.isEmpty) return;
    if (_currentIndex > 0) {
      _currentIndex--;
    } else if (_loopMode) {
      _currentIndex = _playlist.length - 1;
    } else {
      await _player.seek(Duration.zero);
      return;
    }
    await _playCurrentSong();
  }

  @override
  Future<void> skipToQueueItem(int index) async {
    if (index < 0 || index >= _playlist.length) return;
    _currentIndex = index;
    await _playCurrentSong();
  }

  Future<void> _playCurrentSong() async {
    if (_currentIndex < 0 || _currentIndex >= _playlist.length) return;
    final song = _playlist[_currentIndex];
    await _player.setFilePath(song.filePath);
    await _player.play();
    _updateMediaItem(_player.duration);
  }

  /// 设置播放列表
  Future<void> setPlaylist(List<Song> songs, {int startIndex = 0}) async {
    _playlist = List.from(songs);
    _currentIndex = startIndex;
    queue.add(songs.map((s) => MediaItem(
      id: s.id?.toString() ?? s.filePath,
      title: s.title,
      artist: s.artist ?? '未知艺术家',
    )).toList());
  }

  /// 设置循环模式
  void setLoopMode(bool enabled) {
    _loopMode = enabled;
  }

  /// 获取当前歌曲
  Song? get currentSong =>
      _currentIndex >= 0 && _currentIndex < _playlist.length
          ? _playlist[_currentIndex]
          : null;

  /// 获取当前索引
  int get currentIndex => _currentIndex;

  /// 获取播放列表
  List<Song> get playlist => List.unmodifiable(_playlist);
}
```

- [ ] **Step 2: 提交**

```bash
git add mysic_flutter/lib/features/player/data/services/audio_handler.dart
git commit -m "feat: 添加 AudioHandler 实现后台播放支持"
```

---

### Task 3: 重写 AudioPlayerService

**Files:**
- Modify: `mysic_flutter/lib/features/player/data/services/audio_player_service.dart`

- [ ] **Step 1: 重写 AudioPlayerService 使用 just_audio**

```dart
import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:flutter/foundation.dart';
import '../models/song.dart';
import 'audio_handler.dart';

/// 播放器状态
enum MysicPlayerState {
  idle,
  loading,
  ready,
  playing,
  paused,
  completed,
  error,
}

/// 循环模式
enum MysicLoopMode {
  off,
  all,
}

/// 音频播放服务
/// 使用 just_audio + audio_service 实现音频播放核心功能
class AudioPlayerService {
  late final AudioPlayer _player;
  MysicAudioHandler? _audioHandler;
  MysicPlayerState _state = MysicPlayerState.idle;
  Song? _currentSong;
  List<Song> _playlist = [];
  int _currentIndex = -1;
  bool _isShuffleMode = false;
  MysicLoopMode _loopMode = MysicLoopMode.off;

  // 状态流控制器
  final _stateController = StreamController<MysicPlayerState>.broadcast();
  final _positionController = StreamController<Duration>.broadcast();
  final _durationController = StreamController<Duration?>.broadcast();
  final _currentSongController = StreamController<Song?>.broadcast();

  // 公开的流
  Stream<MysicPlayerState> get stateStream => _stateController.stream;
  Stream<Duration> get positionStream => _positionController.stream;
  Stream<Duration?> get durationStream => _durationController.stream;
  Stream<Song?> get currentSongStream => _currentSongController.stream;

  // 当前状态
  MysicPlayerState get state => _state;
  Song? get currentSong => _currentSong;
  Duration get position => _player.position;
  Duration? get duration => _player.duration;
  bool get isPlaying => _state == MysicPlayerState.playing;
  bool get isShuffleMode => _isShuffleMode;
  MysicLoopMode get loopMode => _loopMode;
  List<Song> get playlist => List.unmodifiable(_playlist);
  int get currentIndex => _currentIndex;

  /// 初始化音频播放服务
  Future<void> initialize() async {
    _player = AudioPlayer();

    // 初始化 AudioHandler
    _audioHandler = await AudioService.init(
      builder: () => MysicAudioHandler(_player),
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.mysic.app.audio',
        androidNotificationChannelName: 'Mysic 播放器',
        androidNotificationOngoing: true,
        androidStopForegroundOnPause: true,
      ),
    );

    // 监听播放器状态
    _player.playerStateStream.listen((state) {
      _handlePlayerStateChange(state);
    });

    // 监听播放位置
    _player.positionStream.listen((position) {
      _positionController.add(position);
    });

    // 监听歌曲时长
    _player.durationStream.listen((duration) {
      _durationController.add(duration);
    });

    // 监听播放完成
    _player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) {
        _onSongCompleted();
      }
    });
  }

  /// 处理播放器状态变化
  void _handlePlayerStateChange(PlayerState state) {
    switch (state.processingState) {
      case ProcessingState.idle:
        _updateState(MysicPlayerState.idle);
        break;
      case ProcessingState.loading:
      case ProcessingState.buffering:
        _updateState(MysicPlayerState.loading);
        break;
      case ProcessingState.ready:
        _updateState(state.playing ? MysicPlayerState.playing : MysicPlayerState.ready);
        break;
      case ProcessingState.completed:
        _updateState(MysicPlayerState.completed);
        break;
    }
  }

  /// 更新状态
  void _updateState(MysicPlayerState newState) {
    if (_state != newState) {
      _state = newState;
      _stateController.add(_state);
    }
  }

  /// 播放歌曲
  Future<void> playSong(Song song) async {
    try {
      _updateState(MysicPlayerState.loading);
      _currentSong = song;
      _currentSongController.add(_currentSong);

      await _player.setFilePath(song.filePath);
      await _player.play();

      _updateState(MysicPlayerState.playing);
    } catch (e) {
      _updateState(MysicPlayerState.error);
      rethrow;
    }
  }

  /// 设置播放列表
  Future<void> setPlaylist(List<Song> songs, {int startIndex = 0, bool autoPlay = false}) async {
    if (songs.isEmpty) return;

    debugPrint('========== AudioPlayerService.setPlaylist 开始 ==========');
    debugPrint('歌曲数量: ${songs.length}, startIndex: $startIndex, autoPlay: $autoPlay');

    _playlist = List.from(songs);
    _currentIndex = startIndex;

    // 同步到 AudioHandler
    await _audioHandler?.setPlaylist(songs, startIndex: startIndex);

    _updateState(MysicPlayerState.loading);

    _currentSong = songs[startIndex];
    _currentSongController.add(_currentSong);

    if (autoPlay) {
      debugPrint('准备播放: ${songs[startIndex].filePath}');
      try {
        await _player.setFilePath(songs[startIndex].filePath);
        await _player.play();
        debugPrint('播放命令已执行');
      } catch (e) {
        debugPrint('播放错误: $e');
      }
      _updateState(MysicPlayerState.playing);
    } else {
      await _player.setFilePath(songs[startIndex].filePath);
      _updateState(MysicPlayerState.ready);
    }
    debugPrint('========== AudioPlayerService.setPlaylist 完成 ==========');
  }

  /// 播放
  Future<void> play() async {
    await _player.play();
  }

  /// 暂停
  Future<void> pause() async {
    await _player.pause();
  }

  /// 停止
  Future<void> stop() async {
    await _player.stop();
    _currentSong = null;
    _currentIndex = -1;
    _currentSongController.add(null);
    _updateState(MysicPlayerState.idle);
  }

  /// 播放下一首
  Future<void> next() async {
    if (_playlist.isEmpty) return;

    if (_isShuffleMode) {
      final randomIndex = _getRandomIndex();
      _currentIndex = randomIndex;
    } else {
      if (_currentIndex < _playlist.length - 1) {
        _currentIndex++;
      } else if (_loopMode == MysicLoopMode.all) {
        _currentIndex = 0;
      } else {
        return;
      }
    }

    _currentSong = _playlist[_currentIndex];
    _currentSongController.add(_currentSong);
    _updateState(MysicPlayerState.loading);
    await _player.setFilePath(_currentSong!.filePath);
    await _player.play();
    _updateState(MysicPlayerState.playing);
  }

  /// 播放上一首
  Future<void> previous() async {
    if (_playlist.isEmpty) return;

    if (_currentIndex > 0) {
      _currentIndex--;
    } else if (_loopMode == MysicLoopMode.all) {
      _currentIndex = _playlist.length - 1;
    } else {
      await _player.seek(Duration.zero);
      return;
    }

    _currentSong = _playlist[_currentIndex];
    _currentSongController.add(_currentSong);
    _updateState(MysicPlayerState.loading);
    await _player.setFilePath(_currentSong!.filePath);
    await _player.play();
    _updateState(MysicPlayerState.playing);
  }

  /// 跳转到指定位置
  Future<void> seek(Duration position) async {
    await _player.seek(position);
  }

  /// 跳转到指定歌曲
  Future<void> seekToIndex(int index) async {
    if (index < 0 || index >= _playlist.length) return;

    _currentIndex = index;
    _currentSong = _playlist[_currentIndex];
    _currentSongController.add(_currentSong);
    _updateState(MysicPlayerState.loading);
    await _player.setFilePath(_currentSong!.filePath);
    await _player.play();
    _updateState(MysicPlayerState.playing);
  }

  /// 设置播放速度
  Future<void> setSpeed(double speed) async {
    await _player.setSpeed(speed);
  }

  /// 切换随机模式
  Future<void> toggleShuffleMode() async {
    _isShuffleMode = !_isShuffleMode;
  }

  /// 设置循环模式
  Future<void> setLoopMode(MysicLoopMode mode) async {
    _loopMode = mode;
    _audioHandler?.setLoopMode(mode == MysicLoopMode.all);
  }

  /// 切换循环模式
  Future<void> toggleLoopMode() async {
    switch (_loopMode) {
      case MysicLoopMode.off:
        await setLoopMode(MysicLoopMode.all);
        break;
      case MysicLoopMode.all:
        await setLoopMode(MysicLoopMode.off);
        break;
    }
  }

  /// 歌曲播放完成回调
  void _onSongCompleted() {
    if (_currentIndex < _playlist.length - 1 || _loopMode == MysicLoopMode.all) {
      next();
    } else {
      _updateState(MysicPlayerState.completed);
    }
  }

  /// 获取随机索引
  int _getRandomIndex() {
    if (_playlist.length <= 1) return 0;

    int randomIndex;
    do {
      randomIndex = DateTime.now().millisecondsSinceEpoch % _playlist.length;
    } while (randomIndex == _currentIndex);

    return randomIndex;
  }

  /// 更新播放列表中的歌曲信息
  void updateSongInPlaylist(Song updatedSong) {
    final index = _playlist.indexWhere((s) => s.id == updatedSong.id);
    if (index != -1) {
      _playlist[index] = updatedSong;
    }
    if (_currentSong?.id == updatedSong.id) {
      _currentSong = updatedSong;
      _currentSongController.add(_currentSong);
    }
  }

  /// 从播放列表移除歌曲
  Future<bool> removeFromPlaylist(int index) async {
    if (index < 0 || index >= _playlist.length) return false;

    final wasPlayingCurrent = index == _currentIndex;
    final wasPlaying = _state == MysicPlayerState.playing;
    _playlist.removeAt(index);

    if (index < _currentIndex) {
      _currentIndex--;
    } else if (wasPlayingCurrent) {
      if (_playlist.isNotEmpty) {
        if (_currentIndex >= _playlist.length) {
          _currentIndex = _playlist.length - 1;
        }
        _currentSong = _playlist[_currentIndex];
        _currentSongController.add(_currentSong);

        if (wasPlaying) {
          _updateState(MysicPlayerState.loading);
          await _player.setFilePath(_currentSong!.filePath);
          await _player.play();
        } else {
          await _player.setFilePath(_currentSong!.filePath);
          _updateState(MysicPlayerState.ready);
        }
      } else {
        _currentIndex = -1;
        _currentSong = null;
        _currentSongController.add(null);
        await _player.stop();
        _updateState(MysicPlayerState.idle);
      }
    }

    return _playlist.isEmpty;
  }

  /// 释放资源
  Future<void> dispose() async {
    await _player.dispose();
    await _stateController.close();
    await _positionController.close();
    await _durationController.close();
    await _currentSongController.close();
  }
}
```

- [ ] **Step 2: 提交**

```bash
git add mysic_flutter/lib/features/player/data/services/audio_player_service.dart
git commit -m "refactor: 重写 AudioPlayerService 使用 just_audio"
```

---

### Task 4: 验证 iOS 配置

**Files:**
- Read: `mysic_flutter/ios/Runner/Info.plist`

- [ ] **Step 1: 确认 iOS 后台音频配置已存在**

已确认 `Info.plist` 包含：
```xml
<key>UIBackgroundModes</key>
<array>
    <string>audio</string>
</array>
```

无需修改。

---

### Task 5: 测试构建

- [ ] **Step 1: 运行 Flutter 分析**

Run: `cd mysic_flutter && flutter analyze`
Expected: 无错误

- [ ] **Step 2: 测试 Windows 构建**

Run: `cd mysic_flutter && flutter build windows`
Expected: 构建成功

- [ ] **Step 3: 提交最终更改**

```bash
git add -A
git commit -m "feat: 完成 just_audio + audio_service 迁移"
```

---

## 验收清单

- [ ] Android 后台播放自动切歌正常
- [ ] Android 锁屏播放自动切歌正常
- [ ] 通知栏媒体控制正常
- [ ] iOS 后台播放正常
- [ ] Windows 播放正常
- [ ] 现有功能不受影响（播放、暂停、切歌、循环、随机）
