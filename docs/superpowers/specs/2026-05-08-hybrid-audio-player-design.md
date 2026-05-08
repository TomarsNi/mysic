# 混合音频播放方案设计

## 问题背景

- `audioplayers`: Windows 原生支持，但 Android 后台播放时 `onPlayerComplete` 事件无法可靠触发
- `just_audio` + `audio_service`: Android/iOS 后台播放完美支持，但不支持 Windows 平台

## 解决方案

**混合方案：平台条件编译**

- **Android/iOS**: 使用 `just_audio` + `audio_service`（完整后台支持、通知栏控制）
- **Windows**: 使用 `audioplayers`（原生支持，无需后台服务）

## 架构设计

### 文件结构

```
lib/features/player/data/
├── models/
│   └── song.dart                    # 保持不变
├── services/
│   ├── audio_player_service.dart    # 平台条件编译，统一 API
│   └── audio_handler.dart           # 新增，仅移动端使用
```

### API 接口（保持不变）

```dart
class AudioPlayerService {
  // 状态流
  Stream<MysicPlayerState> get stateStream;
  Stream<Duration> get positionStream;
  Stream<Duration?> get durationStream;
  Stream<Song?> get currentSongStream;

  // 播放控制
  Future<void> initialize();
  Future<void> playSong(Song song);
  Future<void> setPlaylist(List<Song> songs, {int startIndex, bool autoPlay});
  Future<void> play();
  Future<void> pause();
  Future<void> stop();
  Future<void> next();
  Future<void> previous();
  Future<void> seek(Duration position);
  Future<void> seekToIndex(int index);
  Future<void> setSpeed(double speed);
  Future<void> toggleShuffleMode();
  Future<void> setLoopMode(MysicLoopMode mode);
  Future<void> toggleLoopMode();

  // 状态访问
  MysicPlayerState get state;
  Song? get currentSong;
  Duration get position;
  Duration? get duration;
  bool get isPlaying;
  bool get isShuffleMode;
  MysicLoopMode get loopMode;
  List<Song> get playlist;
  int get currentIndex;

  // 播放列表管理
  void updateSongInPlaylist(Song updatedSong);
  Future<bool> removeFromPlaylist(int index);
  Future<void> dispose();
}
```

### 平台条件编译

```dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/song.dart';

// 条件导入
import 'audio_player_service_mobile.dart'
    if (dart.library.io) 'audio_player_service_mobile.dart'
    if (dart.library.html) 'audio_player_service_web.dart';

class AudioPlayerService {
  // 统一 API，内部委托给平台实现
}
```

**更简单的方案：单文件条件编译**

```dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/song.dart';

class AudioPlayerService {
  // 公共状态
  MysicPlayerState _state = MysicPlayerState.idle;
  Song? _currentSong;
  List<Song> _playlist = [];
  int _currentIndex = -1;
  bool _isShuffleMode = false;
  MysicLoopMode _loopMode = MysicLoopMode.off;
  Duration _position = Duration.zero;
  Duration? _duration;

  // 状态流控制器
  final _stateController = StreamController<MysicPlayerState>.broadcast();
  final _positionController = StreamController<Duration>.broadcast();
  final _durationController = StreamController<Duration?>.broadcast();
  final _currentSongController = StreamController<Song?>.broadcast();

  // 平台特定实现
  late final dynamic _platformPlayer;

  Future<void> initialize() async {
    if (Platform.isAndroid || Platform.isIOS) {
      // 使用 just_audio + audio_service
      _platformPlayer = await _initMobilePlayer();
    } else {
      // Windows: 使用 audioplayers
      _platformPlayer = _initWindowsPlayer();
    }
  }

  // ... 统一 API 实现
}
```

## 依赖配置

**pubspec.yaml**

```yaml
dependencies:
  # 音频播放 - 混合方案
  just_audio: ^0.9.40        # Android/iOS
  audio_service: ^0.18.15    # Android/iOS 后台服务
  audioplayers: ^6.0.0       # Windows
```

## 实现要点

### 1. 移动端（just_audio + audio_service）

- 创建 `MysicAudioHandler` 实现 `BaseAudioHandler`
- 处理后台播放、通知栏控制、锁屏控制
- 监听 `ProcessingState.completed` 触发下一首

### 2. Windows 端（audioplayers）

- 保持现有实现
- 监听 `PlayerState.completed` 触发下一首
- 无需后台服务（Windows 桌面应用无后台限制）

### 3. 状态同步

- 两套实现共享相同的状态变量
- 通过 Stream 向上层通知状态变化
- PlayerProvider 无需任何修改

## 风险评估

- **低风险**: API 接口完全统一，上层代码无感知
- **测试成本**: 需要分别测试 Android、iOS、Windows 三个平台
- **维护成本**: 两套实现需要同步维护

## 验收标准

- [ ] Android 后台播放自动切歌正常
- [ ] Android 锁屏播放自动切歌正常
- [ ] Android 通知栏媒体控制正常
- [ ] iOS 后台播放正常
- [ ] Windows 播放正常
- [ ] 现有功能不受影响（播放、暂停、切歌、循环、随机）
- [ ] PlayerProvider 无需修改
