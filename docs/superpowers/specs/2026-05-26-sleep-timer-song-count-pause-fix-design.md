# 睡眠定时器按歌曲数倒计时 — 暂停不生效修复设计

## 问题描述

设置睡眠定时器为 N 首歌后，当前歌曲播放完成时，虽然出现了暂停提示（SnackBar），但下一首歌仍然继续播放。暂停操作未生效。

## 根本原因

在 `AudioPlayerService._onSongCompleted()` 中：

```dart
void _onSongCompleted() {
    _songCompletedController.add(null);   // 1. 同步发出完成事件
    if (_currentIndex < _playlist.length - 1 || _loopMode == MysicLoopMode.all) {
      next();                             // 2. 立即开始下一首
    }
}
```

执行时序问题：

1. `_songCompletedController.add(null)` 同步触发流监听器 → `sleepTimerProvider.onSongCompleted()` → 递减倒计时 → `_complete()` → `pause()`
2. 同一调用栈中，`next()` 紧接着执行 → 设置新歌 → `play()`

由于 `pause()` 和 `play()` 都是异步操作，两者谁先完成不确定。在 Windows 平台上 `next()` 的 `play()` 往往先于 `pause()` 生效，导致暂停被覆盖。

## 修复方案

在 `_onSongCompleted()` 决定是否播放下一首之前，通过回调询问外部是否允许继续。

### 设计要点

- **同步检查**：在 `next()` 被调用之前，同步判定是否应该阻止自动下一首
- **解耦**：`AudioPlayerService` 不感知睡眠定时器，只通过一个 `bool` 回调获取决策
- **精确标记**：只在定时器刚触发时阻止自动下一首，不影响后续手动操作

### 改动详情

#### 1. `audio_player_service.dart` — 增加 `shouldAutoNext` 回调

```dart
bool Function()? shouldAutoNext;

void _onSongCompleted() {
    _songCompletedController.add(null);

    if (shouldAutoNext != null && !shouldAutoNext!()) {
      _updateState(MysicPlayerState.completed);
      return;
    }

    if (_currentIndex < _playlist.length - 1 || _loopMode == MysicLoopMode.all) {
      next();
    } else {
      _updateState(MysicPlayerState.completed);
    }
}
```

#### 2. `player_provider.dart` — 透传回调

```dart
bool Function()? shouldAutoNext;

// 在 _init() 中：
_audioPlayerService.shouldAutoNext = shouldAutoNext;
```

#### 3. `sleep_timer_service.dart` — 增加 `justCompleted` 标志

```dart
bool _justCompleted = false;
bool get justCompleted => _justCompleted;

void _complete() {
    _cancelTimer();
    _state = SleepTimerState.inactive();
    _justCompleted = true;
    onStateChanged?.call();
    onComplete?.call();
    Future.microtask(() => _justCompleted = false);
}
```

`justCompleted` 在 `_complete()` 中设为 `true`，在当前微任务结束后清除。由于 `_onSongCompleted()` 和 `_complete()` 在同一个同步调用栈中执行，`shouldAutoNext` 回调检查时 `justCompleted` 一定为 `true`。

#### 4. `sleep_timer_provider.dart` — 透传 getter

```dart
bool get justCompleted => _sleepTimerService.justCompleted;
```

#### 5. `main.dart` — 设置回调逻辑

在 `_setupSleepTimerCallback()` 中增加：

```dart
playerProvider.shouldAutoNext = () {
  return !sleepTimerProvider.justCompleted;
};
```

## 涉及文件

| 文件 | 改动 |
|------|------|
| `audio_player_service.dart` | 增加 `shouldAutoNext` 回调，`_onSongCompleted` 中检查 |
| `player_provider.dart` | 透传 `shouldAutoNext` 到 `AudioPlayerService` |
| `sleep_timer_service.dart` | 增加 `justCompleted` 标志 |
| `sleep_timer_provider.dart` | 透传 `justCompleted` getter |
| `main.dart` | 设置 `shouldAutoNext` 回调 |

## 验证方式

1. 设置睡眠定时器为 1 首歌 → 当前歌播完后应暂停，不播放下一首
2. 设置睡眠定时器为 2 首歌 → 当前歌播完后继续下一首，第二首播完后暂停
3. 手动暂停/播放不受影响
4. 不设置睡眠定时器时，自动下一首行为不变
