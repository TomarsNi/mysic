# Android 锁屏切歌后 App 状态同步设计

**日期**: 2026-05-10
**状态**: 待审核
**范围**: Android 锁屏控制状态同步

## 问题描述

Android 锁屏页面切歌后，通知栏歌曲信息正确更新，但回到 App 后 UI 显示的是旧歌曲信息。

## 根因分析

### 当前架构

```
锁屏控制 → MysicAudioHandler → just_audio.AudioPlayer
                                    ↓
                              playerStateStream
                                    ↓
                            AudioPlayerService
                                    ↓
                            currentSongStream
                                    ↓
                              PlayerProvider
                                    ↓
                                  UI
```

### 问题根源

`MysicAudioHandler` 和 `AudioPlayerService` 维护了**独立的状态**：

| 组件 | 状态 | 更新时机 |
|------|------|----------|
| `MysicAudioHandler` | `_currentIndex`, `_playlist` | 锁屏切歌时更新 |
| `AudioPlayerService` | `_currentIndex`, `_currentSong` | 仅在 App 内操作时更新 |

锁屏切歌流程：
1. 用户在锁屏点击"下一首"
2. `MysicAudioHandler.skipToNext()` 执行
3. `MysicAudioHandler._currentIndex++` 更新
4. `_playCurrentSong()` 播放新歌曲
5. 通知栏信息更新（`d2da90d` 已修复）
6. **但 `AudioPlayerService._currentSong` 未更新**
7. `PlayerProvider` 监听的是 `currentSongStream`，所以 UI 不刷新

## 解决方案

### 方案 A：状态同步回调

在 `MysicAudioHandler` 切歌时，通过回调通知 `AudioPlayerService` 同步状态。

### 设计

#### 1. MysicAudioHandler 添加回调

```dart
class MysicAudioHandler extends BaseAudioHandler with QueueHandler, SeekHandler {
  final AudioPlayer _player;
  final void Function()? onSongCompleted;
  final void Function(Song song, int index)? onSongChanged;  // 新增

  MysicAudioHandler(this._player, {this.onSongCompleted, this.onSongChanged}) {
    _init();
  }
}
```

#### 2. 切歌时触发回调

在 `skipToNext`、`skipToPrevious`、`skipToQueueItem` 中调用回调：

```dart
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
  onSongChanged?.call(currentSong!, _currentIndex);  // 通知状态变化
}
```

#### 3. AudioPlayerService 处理回调

```dart
_audioHandler = await AudioService.init(
  builder: () => MysicAudioHandler(
    _justAudioPlayer!,
    onSongCompleted: _onSongCompleted,
    onSongChanged: _handleSongChangedFromHandler,  // 新增
  ),
  // ...
);

void _handleSongChangedFromHandler(Song song, int index) {
  _currentSong = song;
  _currentIndex = index;
  _currentSongController.add(_currentSong);
}
```

### 修改文件清单

| 文件 | 修改内容 |
|------|----------|
| `audio_handler.dart` | 添加 `onSongChanged` 回调参数，在切歌方法中触发回调 |
| `audio_player_service.dart` | 初始化时传入回调，实现 `_handleSongChangedFromHandler` |

### 测试要点

1. 锁屏点击"下一首"，回到 App 验证歌曲信息正确
2. 锁屏点击"上一首"，回到 App 验证歌曲信息正确
3. 锁屏点击播放列表中的任意歌曲，回到 App 验证
4. App 内切歌功能不受影响
5. 播放列表循环模式正常工作

## 风险评估

- **低风险**：仅添加回调机制，不改变现有逻辑
- **向后兼容**：回调参数可选，默认为 null
- **性能影响**：无，仅增加一次函数调用

## 实现计划

1. 修改 `MysicAudioHandler` 添加回调
2. 修改 `AudioPlayerService` 处理回调
3. 测试验证
