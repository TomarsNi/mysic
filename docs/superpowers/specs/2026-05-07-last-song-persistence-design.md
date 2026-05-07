# 播放歌曲持久化设计

## 背景

当前实现：应用启动时恢复上次播放的歌单，但总是从第一首歌开始播放。

用户需求：记录最后播放的歌曲，重新打开应用时从这首歌继续播放。

## 目标

- 应用关闭前记录当前播放的歌曲 ID
- 应用启动时恢复到该歌曲（从头播放，不记录进度）
- 歌曲从歌单删除时优雅降级

## 技术方案

### 存储方式

使用 `SharedPreferences` 存储 `last_song_id`，与现有 `PlayModePreference` 保持一致。

**Why**: 简单、轻量、与现有模式统一，无需数据库操作。

### 数据结构

```dart
// PlayModePreference 扩展
class PlayModePreference {
  static const _keyShuffleMode = 'play_mode_shuffle';
  static const _keyLoopMode = 'play_mode_loop';
  static const _keyLastSongId = 'last_song_id';  // 新增
}
```

### 触发时机

**保存**：歌曲切换时保存 `last_song_id`
- 位置：`PlayerProvider._init()` 中监听 `currentSongStream`
- 条件：`song != null && song.id != null`

**恢复**：应用启动时
- 位置：`_restoreLastPlaylist()` 方法
- 逻辑：查找歌曲在歌单中的位置，找到则从该位置播放

### 流程图

```
启动应用
    ↓
加载歌单列表
    ↓
读取 last_playlist_id
    ↓
加载歌单歌曲
    ↓
读取 last_song_id
    ↓
查找歌曲在歌单中的位置
    ↓
┌─────────────────┐
│ 找到？          │
├──────┬──────────┤
│ 是   │ 否       │
↓      ↓
从该位置  从第一首
播放      播放
└──────┴──────────┘
```

## 实现细节

### 1. PlayModePreference 扩展

```dart
class PlayModePreference {
  // 现有代码...

  static const _keyLastSongId = 'last_song_id';

  /// 保存最后播放的歌曲 ID
  static Future<void> saveLastSongId(int songId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyLastSongId, songId);
  }

  /// 加载最后播放的歌曲 ID
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
```

### 2. PlayerProvider 修改

在 `_init()` 中添加歌曲变化监听：

```dart
// 监听当前歌曲变化
_audioPlayerService.currentSongStream.listen((song) {
  _currentSong = song;
  // 保存最后播放的歌曲
  if (song?.id != null) {
    PlayModePreference.saveLastSongId(song!.id!);
  }
  // 加载歌词
  _loadLyricsForSong(song);
  notifyListeners();
});
```

### 3. 启动恢复逻辑修改

修改 `_restoreLastPlaylist()` 方法：

```dart
Future<void> _restoreLastPlaylist() async {
  // ... 现有代码获取歌单 ...

  // 4. 尝试恢复最后播放的歌曲
  final lastSongId = await PlayModePreference.loadLastSongId();
  int startIndex = 0;

  if (lastSongId != null) {
    // 查找歌曲在歌单中的位置
    final index = songs.indexWhere((s) => s.id == lastSongId);
    if (index != -1) {
      startIndex = index;
    }
  }

  // 5. 播放歌单
  await playerProvider.setPlaylist(songs, startIndex: startIndex, autoPlay: true);
}
```

## 边界情况处理

| 场景 | 处理方式 |
|------|----------|
| 歌曲已从歌单删除 | `indexWhere` 返回 -1，`startIndex` 保持 0 |
| 歌曲 ID 为 null | 不保存，启动时从第一首开始 |
| 歌单为空 | 不播放，保持 idle 状态 |
| 首次启动（无记录） | `loadLastSongId()` 返回 null，从第一首开始 |

## 测试要点

1. **正常流程**：播放歌曲 → 关闭应用 → 重新打开 → 验证从该歌曲开始
2. **歌曲删除**：播放歌曲 → 从歌单删除该歌曲 → 关闭应用 → 重新打开 → 验证从第一首开始
3. **歌单切换**：播放歌单 A 的歌曲 → 切换到歌单 B → 关闭应用 → 重新打开 → 验证恢复歌单 B 的歌曲
4. **首次启动**：全新安装 → 打开应用 → 验证从第一首开始

## 文件变更

| 文件 | 变更类型 | 说明 |
|------|----------|------|
| `lib/features/settings/data/play_mode_preference.dart` | 修改 | 添加 `last_song_id` 存取方法 |
| `lib/features/player/presentation/providers/player_provider.dart` | 修改 | 监听歌曲变化并保存 |
| `lib/main.dart` | 修改 | 恢复时查找歌曲位置 |

## 风险评估

- **低风险**：改动范围小，逻辑简单
- **向后兼容**：不影响现有功能，只是增强恢复逻辑
