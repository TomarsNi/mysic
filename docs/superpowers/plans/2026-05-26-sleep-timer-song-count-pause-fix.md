# 睡眠定时器按歌曲数倒计时暂停不生效 — 修复实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 修复睡眠定时器按歌曲数倒计时时，当前歌曲播放完成后暂停不生效、下一首继续播放的 bug。

**Architecture:** 在 `AudioPlayerService._onSongCompleted()` 中增加同步检查回调 `shouldAutoNext`，在调用 `next()` 之前询问外部是否允许自动下一首。`SleepTimerService` 增加 `justCompleted` 标志，在定时器刚触发时标记为 `true`，供回调判断。

**Tech Stack:** Dart/Flutter, Provider (ChangeNotifier)

---

### Task 1: SleepTimerService 增加 justCompleted 标志

**Files:**
- Modify: `mysic_flutter/lib/features/player/data/services/sleep_timer_service.dart:59-147`

- [ ] **Step 1: 在 SleepTimerService 中增加 `_justCompleted` 字段和 getter**

在 `sleep_timer_service.dart` 第 59 行（`class SleepTimerService {` 之后），添加字段：

```dart
class SleepTimerService {
  Timer? _timer;
  SleepTimerState _state = SleepTimerState.inactive();
  bool _justCompleted = false;
```

在第 63 行（`SleepTimerState get state => _state;` 之后），添加 getter：

```dart
  SleepTimerState get state => _state;
  bool get justCompleted => _justCompleted;
```

- [ ] **Step 2: 在 `_complete()` 方法中设置和清除标志**

将 `_complete()` 方法（第 142-147 行）修改为：

```dart
  void _complete() {
    _cancelTimer();
    _state = SleepTimerState.inactive();
    _justCompleted = true;
    onStateChanged?.call();
    onComplete?.call();
    Future.microtask(() => _justCompleted = false);
  }
```

- [ ] **Step 3: 验证编译通过**

Run: `cd mysic_flutter && flutter analyze lib/features/player/data/services/sleep_timer_service.dart`
Expected: No errors

- [ ] **Step 4: Commit**

```bash
git add mysic_flutter/lib/features/player/data/services/sleep_timer_service.dart
git commit -m "fix(sleep-timer): 增加justCompleted标志用于阻止自动下一首"
```

---

### Task 2: SleepTimerProvider 透传 justCompleted getter

**Files:**
- Modify: `mysic_flutter/lib/features/player/presentation/providers/sleep_timer_provider.dart:15`

- [ ] **Step 1: 在 SleepTimerProvider 中添加 justCompleted getter**

在 `sleep_timer_provider.dart` 第 15 行（`SleepTimerState get state => _service.state;` 之后），添加：

```dart
  SleepTimerState get state => _service.state;
  bool get justCompleted => _service.justCompleted;
```

- [ ] **Step 2: 验证编译通过**

Run: `cd mysic_flutter && flutter analyze lib/features/player/presentation/providers/sleep_timer_provider.dart`
Expected: No errors

- [ ] **Step 3: Commit**

```bash
git add mysic_flutter/lib/features/player/presentation/providers/sleep_timer_provider.dart
git commit -m "fix(sleep-timer): 透传justCompleted getter到Provider层"
```

---

### Task 3: AudioPlayerService 增加 shouldAutoNext 回调

**Files:**
- Modify: `mysic_flutter/lib/features/player/data/services/audio_player_service.dart:517-530`

- [ ] **Step 1: 在 AudioPlayerService 中添加 shouldAutoNext 字段**

在 `audio_player_service.dart` 第 50 行（`final _songCompletedController = StreamController<void>.broadcast();` 之后），添加：

```dart
  final _songCompletedController = StreamController<void>.broadcast();

  /// 外部回调：是否允许自动播放下一首
  /// 返回 false 时，_onSongCompleted 不会调用 next()
  bool Function()? shouldAutoNext;
```

- [ ] **Step 2: 修改 `_onSongCompleted()` 方法，在调用 next() 前检查回调**

将 `_onSongCompleted()` 方法（第 517-530 行）修改为：

```dart
  void _onSongCompleted() {
    AppLogger.d('AudioPlayerService#_onSongCompleted', '========== _onSongCompleted ==========');
    AppLogger.d('AudioPlayerService#_onSongCompleted', 'currentIndex: $_currentIndex, playlist length: ${_playlist.length}, loopMode: $_loopMode');
    _songCompletedController.add(null);

    // 检查外部是否允许自动播放下一首
    if (shouldAutoNext != null && !shouldAutoNext!()) {
      AppLogger.i('AudioPlayerService#_onSongCompleted', '外部阻止自动下一首，停止播放');
      _updateState(MysicPlayerState.completed);
      return;
    }

    if (_currentIndex < _playlist.length - 1 || _loopMode == MysicLoopMode.all) {
      AppLogger.i('AudioPlayerService#_onSongCompleted', '准备播放下一首');
      next();
    } else {
      AppLogger.i('AudioPlayerService#_onSongCompleted', '播放列表结束');
      _updateState(MysicPlayerState.completed);
    }
  }
```

- [ ] **Step 3: 验证编译通过**

Run: `cd mysic_flutter && flutter analyze lib/features/player/data/services/audio_player_service.dart`
Expected: No errors

- [ ] **Step 4: Commit**

```bash
git add mysic_flutter/lib/features/player/data/services/audio_player_service.dart
git commit -m "fix(player): 增加shouldAutoNext回调，允许外部阻止自动下一首"
```

---

### Task 4: PlayerProvider 透传 shouldAutoNext 回调

**Files:**
- Modify: `mysic_flutter/lib/features/player/presentation/providers/player_provider.dart:46-92`

- [ ] **Step 1: 在 PlayerProvider 中添加 shouldAutoNext 属性**

在 `player_provider.dart` 第 47 行（`void Function()? onSongCompleted;` 之后），添加：

```dart
  /// 歌曲播放完成回调（用于睡眠定时器歌曲数模式）
  void Function()? onSongCompleted;

  /// 是否允许自动播放下一首的回调（用于睡眠定时器阻止自动下一首）
  bool Function()? shouldAutoNext;
```

- [ ] **Step 2: 在 `_init()` 中将回调传递给 AudioPlayerService**

在 `_init()` 方法中，第 92 行（`onSongCompleted?.call();` 所在的 `songCompletedStream.listen` 闭包之后），添加回调透传：

```dart
    // 监听歌曲播放完成（用于睡眠定时器歌曲数模式）
    _audioPlayerService.songCompletedStream.listen((_) {
      onSongCompleted?.call();
    });

    // 透传 shouldAutoNext 回调到 AudioPlayerService
    _audioPlayerService.shouldAutoNext = shouldAutoNext;
```

- [ ] **Step 3: 验证编译通过**

Run: `cd mysic_flutter && flutter analyze lib/features/player/presentation/providers/player_provider.dart`
Expected: No errors

- [ ] **Step 4: Commit**

```bash
git add mysic_flutter/lib/features/player/presentation/providers/player_provider.dart
git commit -m "fix(player): 透传shouldAutoNext回调到AudioPlayerService"
```

---

### Task 5: main.dart 设置 shouldAutoNext 回调逻辑

**Files:**
- Modify: `mysic_flutter/lib/main.dart:137-161`

- [ ] **Step 1: 在 `_setupSleepTimerCallback()` 中设置 shouldAutoNext 回调**

在 `main.dart` 的 `_setupSleepTimerCallback()` 方法中，第 160 行（`sleepTimerProvider.onSongCompleted();` 所在闭包的 `};` 之后），添加：

```dart
    // 设置歌曲播放完成回调（用于通知 SleepTimerProvider 递减歌曲计数）
    playerProvider.onSongCompleted = () {
      sleepTimerProvider.onSongCompleted();
    };

    // 设置是否允许自动播放下一首（睡眠定时器刚完成时阻止）
    playerProvider.shouldAutoNext = () {
      return !sleepTimerProvider.justCompleted;
    };
```

- [ ] **Step 2: 验证编译通过**

Run: `cd mysic_flutter && flutter analyze lib/main.dart`
Expected: No errors

- [ ] **Step 3: Commit**

```bash
git add mysic_flutter/lib/main.dart
git commit -m "fix(sleep-timer): 设置shouldAutoNext回调，定时器完成时阻止自动下一首"
```

---

### Task 6: 全量编译验证和手动测试

**Files:**
- None (verification only)

- [ ] **Step 1: 运行全量静态分析**

Run: `cd mysic_flutter && flutter analyze`
Expected: No errors

- [ ] **Step 2: 构建 Windows 版本验证**

Run: `cd mysic_flutter && flutter build windows`
Expected: Build succeeds

- [ ] **Step 3: 手动测试 — 睡眠定时器 1 首歌**

1. 启动应用，播放一首歌
2. 设置睡眠定时器为 1 首歌
3. 等待当前歌曲播放完成
4. 验证：播放暂停，不自动播放下一首，SnackBar 提示出现

- [ ] **Step 4: 手动测试 — 睡眠定时器 2 首歌**

1. 启动应用，播放一首歌
2. 设置睡眠定时器为 2 首歌
3. 等待当前歌曲播放完成 → 下一首应自动开始
4. 等待第二首播放完成 → 播放应暂停，不播放第三首

- [ ] **Step 5: 手动测试 — 无定时器时正常行为**

1. 不设置睡眠定时器
2. 播放歌曲，等待播放完成
3. 验证：自动播放下一首（行为不变）

- [ ] **Step 6: 手动测试 — 手动操作不受影响**

1. 设置睡眠定时器
2. 手动点击下一首/上一首
3. 验证：手动操作正常工作

- [ ] **Step 7: Commit (if any fixes needed)**

如果手动测试中发现问题并修复，提交修复。
