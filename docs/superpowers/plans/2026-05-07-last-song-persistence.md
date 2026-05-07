# 播放歌曲持久化实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 记录最后播放的歌曲 ID，应用启动时从该歌曲继续播放

**Architecture:** 使用 SharedPreferences 存储 last_song_id，在 PlayerProvider 监听歌曲变化时保存，在 main.dart 启动恢复时读取并定位到该歌曲

**Tech Stack:** Flutter, SharedPreferences, Provider

---

## 文件结构

| 文件 | 责任 |
|------|------|
| `lib/features/settings/data/play_mode_preference.dart` | 添加 last_song_id 存取方法 |
| `test/features/settings/data/play_mode_preference_test.dart` | 测试新增方法 |
| `lib/features/player/presentation/providers/player_provider.dart` | 监听歌曲变化并保存 |
| `lib/main.dart` | 恢复时查找歌曲位置 |

---

### Task 1: PlayModePreference 扩展

**Files:**
- Modify: `lib/features/settings/data/play_mode_preference.dart`
- Modify: `test/features/settings/data/play_mode_preference_test.dart`

- [ ] **Step 1: 添加 last_song_id 存取方法**

在 `play_mode_preference.dart` 中添加：

```dart
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
```

- [ ] **Step 2: 添加测试**

在 `play_mode_preference_test.dart` 末尾添加：

```dart
    group('lastSongId', () {
      test('loadLastSongId returns null when not set', () async {
        final songId = await PlayModePreference.loadLastSongId();
        expect(songId, isNull);
      });

      test('save and load last song id', () async {
        await PlayModePreference.saveLastSongId(42);
        final songId = await PlayModePreference.loadLastSongId();
        expect(songId, 42);
      });

      test('clearLastSongId removes the value', () async {
        await PlayModePreference.saveLastSongId(42);
        await PlayModePreference.clearLastSongId();
        final songId = await PlayModePreference.loadLastSongId();
        expect(songId, isNull);
      });

      test('overwrite previous song id', () async {
        await PlayModePreference.saveLastSongId(42);
        await PlayModePreference.saveLastSongId(100);
        final songId = await PlayModePreference.loadLastSongId();
        expect(songId, 100);
      });
    });
```

- [ ] **Step 3: 运行测试验证**

Run: `cd mysic_flutter && flutter test test/features/settings/data/play_mode_preference_test.dart`
Expected: All tests pass

- [ ] **Step 4: 提交**

```bash
git add mysic_flutter/lib/features/settings/data/play_mode_preference.dart
git add mysic_flutter/test/features/settings/data/play_mode_preference_test.dart
git commit -m "feat(settings): 添加 last_song_id 持久化方法"
```

---

### Task 2: PlayerProvider 监听歌曲变化

**Files:**
- Modify: `lib/features/player/presentation/providers/player_provider.dart`

- [ ] **Step 1: 修改 currentSongStream 监听，保存歌曲 ID**

找到 `_init()` 方法中监听 `currentSongStream` 的代码块（约 74-80 行），修改为：

```dart
    // 监听当前歌曲变化
    _audioPlayerService.currentSongStream.listen((song) {
      _currentSong = song;
      // 保存最后播放的歌曲 ID
      if (song?.id != null) {
        PlayModePreference.saveLastSongId(song!.id!);
      }
      // 加载歌词
      _loadLyricsForSong(song);
      notifyListeners();
    });
```

- [ ] **Step 2: 运行分析验证**

Run: `cd mysic_flutter && flutter analyze lib/features/player/presentation/providers/player_provider.dart`
Expected: No issues found

- [ ] **Step 3: 提交**

```bash
git add mysic_flutter/lib/features/player/presentation/providers/player_provider.dart
git commit -m "feat(player): 歌曲切换时保存 last_song_id"
```

---

### Task 3: 启动恢复逻辑

**Files:**
- Modify: `lib/main.dart`

- [ ] **Step 1: 添加 PlayModePreference import**

在 `main.dart` 顶部添加 import（约第 10 行后）：

```dart
import 'features/settings/data/play_mode_preference.dart';
```

- [ ] **Step 2: 修改 _restoreLastPlaylist 方法**

找到 `_restoreLastPlaylist()` 方法（约 121-153 行），修改最后部分：

```dart
  /// 恢复上次播放的歌单
  Future<void> _restoreLastPlaylist() async {
    final playerProvider = context.read<PlayerProvider>();
    final playlistProvider = context.read<PlaylistProvider>();
    final repository = PlaylistRepository();

    // 1. 尝试获取上次播放的歌单 ID
    final lastPlaylistIdStr = await repository.getAppState('last_playlist_id');
    int? playlistId = lastPlaylistIdStr != null ? int.tryParse(lastPlaylistIdStr) : null;

    // 2. 如果歌单不存在，回退到"本地音乐"歌单
    if (playlistId == null) {
      final localPlaylist = playlistProvider.playlists.where((p) => p.name == '本地音乐').firstOrNull;
      playlistId = localPlaylist?.id;
    } else {
      // 验证歌单是否还存在
      final playlist = await repository.getPlaylistById(playlistId);
      if (playlist == null) {
        // 歌单已删除，回退到"本地音乐"
        final localPlaylist = playlistProvider.playlists.where((p) => p.name == '本地音乐').firstOrNull;
        playlistId = localPlaylist?.id;
      }
    }

    if (playlistId == null) return;

    // 3. 加载歌单歌曲
    await playlistProvider.selectPlaylist(playlistId);
    final songs = playlistProvider.selectedPlaylistSongs;
    if (songs.isEmpty) return;

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

- [ ] **Step 3: 运行分析验证**

Run: `cd mysic_flutter && flutter analyze lib/main.dart`
Expected: No issues found

- [ ] **Step 4: 提交**

```bash
git add mysic_flutter/lib/main.dart
git commit -m "feat: 启动时恢复最后播放的歌曲"
```

---

### Task 4: 集成测试

- [ ] **Step 1: 运行全部测试**

Run: `cd mysic_flutter && flutter test`
Expected: All tests pass

- [ ] **Step 2: 运行分析**

Run: `cd mysic_flutter && flutter analyze`
Expected: No issues found

- [ ] **Step 3: 手动测试验证**

1. 运行应用：`cd mysic_flutter && flutter run -d windows`
2. 播放歌单中的第 3 首歌曲
3. 关闭应用
4. 重新打开应用
5. 验证：从第 3 首歌曲开始播放

- [ ] **Step 4: 最终提交**

```bash
git add -A
git commit -m "feat: 播放歌曲持久化功能完成

- 记录最后播放的歌曲 ID
- 应用启动时恢复到该歌曲
- 歌曲从歌单删除时优雅降级"
```
