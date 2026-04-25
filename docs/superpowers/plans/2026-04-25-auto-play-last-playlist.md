# 自动播放上次歌单功能实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 打开应用时自动播放上次播放的歌单，无记录时默认播放"本地音乐"歌单。

**Architecture:** 新建 `app_state` 表存储最后播放的歌单 ID。用户点击歌单播放时记录，应用启动时读取并恢复播放。

**Tech Stack:** Flutter, SQLite (sqflite), Provider

---

## 文件结构

| 文件 | 职责 |
|------|------|
| `lib/core/database/database_helper.dart` | 数据库表定义和迁移 |
| `lib/features/playlist/data/playlist_repository.dart` | 应用状态的读写方法 |
| `lib/main.dart` | 记录和恢复播放逻辑 |

---

### Task 1: 数据库升级 - 新增 app_state 表

**Files:**
- Modify: `mysic_flutter/lib/core/database/database_helper.dart`

- [ ] **Step 1: 添加表名常量和升级版本**

在 `DatabaseHelper` 类中：

```dart
/// 表名常量
static const String tableSongs = 'songs';
static const String tablePlaylists = 'playlists';
static const String tablePlaylistSongs = 'playlist_songs';
static const String tableLyrics = 'lyrics';
static const String tablePlayHistory = 'play_history';
static const String tableAppState = 'app_state';  // 新增

/// 数据库版本
static const int _databaseVersion = 3;  // 从 2 升级到 3
```

- [ ] **Step 2: 在 _onCreate 中创建 app_state 表**

在 `_onCreate` 方法末尾添加：

```dart
// 创建应用状态表
await db.execute('''
  CREATE TABLE $tableAppState (
    key TEXT PRIMARY KEY,
    value TEXT
  )
''');
```

- [ ] **Step 3: 在 _onUpgrade 中添加版本 2→3 的迁移逻辑**

在 `_onUpgrade` 方法末尾添加：

```dart
// 版本 2 -> 3: 新增 app_state 表
if (oldVersion < 3) {
  await db.execute('''
    CREATE TABLE $tableAppState (
      key TEXT PRIMARY KEY,
      value TEXT
    )
  ''');
}
```

- [ ] **Step 4: 验证修改**

运行应用确认数据库升级成功：

```bash
cd mysic_flutter && flutter run -d windows
```

- [ ] **Step 5: 提交**

```bash
git add mysic_flutter/lib/core/database/database_helper.dart
git commit -m "feat: 新增 app_state 表用于存储应用状态"
```

---

### Task 2: PlaylistRepository 新增应用状态读写方法

**Files:**
- Modify: `mysic_flutter/lib/features/playlist/data/playlist_repository.dart`

- [ ] **Step 1: 添加 getAppState 方法**

在 `PlaylistRepository` 类的末尾（`getPlaylistSongCount` 方法之后）添加：

```dart
// ==================== 应用状态操作 ====================

/// 获取应用状态
Future<String?> getAppState(String key) async {
  final db = await _db;
  final result = await db.query(
    DatabaseHelper.tableAppState,
    where: 'key = ?',
    whereArgs: [key],
    limit: 1,
  );
  if (result.isEmpty) return null;
  return result.first['value'] as String?;
}

/// 设置应用状态
Future<void> setAppState(String key, String value) async {
  final db = await _db;
  await db.insert(
    DatabaseHelper.tableAppState,
    {'key': key, 'value': value},
    conflictAlgorithm: ConflictAlgorithm.replace,
  );
}
```

- [ ] **Step 2: 验证修改**

运行静态分析：

```bash
cd mysic_flutter && flutter analyze
```

- [ ] **Step 3: 提交**

```bash
git add mysic_flutter/lib/features/playlist/data/playlist_repository.dart
git commit -m "feat: PlaylistRepository 新增应用状态读写方法"
```

---

### Task 3: main.dart 实现记录和恢复播放逻辑

**Files:**
- Modify: `mysic_flutter/lib/main.dart`

- [ ] **Step 1: 添加 PlaylistRepository 导入**

在文件顶部的导入区域添加：

```dart
import 'features/playlist/data/playlist_repository.dart';
```

- [ ] **Step 2: 在 _HomePageState 中添加 _restoreLastPlaylist 方法**

在 `_HomePageState` 类中，`_loadPlaylists` 方法之后添加：

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

  // 4. 播放歌单（与用户点击歌单逻辑一致）
  await playerProvider.setPlaylist(songs, autoPlay: true);
}
```

- [ ] **Step 3: 修改 initState 调用恢复逻辑**

修改 `initState` 方法：

```dart
@override
void initState() {
  super.initState();
  _fabAnimationController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
  );

  // 加载歌单并恢复播放 - 延迟到 build 完成后执行
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    await _loadPlaylists();
    // 恢复上次播放的歌单
    await _restoreLastPlaylist();
  });
}
```

- [ ] **Step 4: 修改 onPlaylistTap 回调记录歌单 ID**

修改 `build` 方法中 `AppDrawer` 的 `onPlaylistTap` 回调：

```dart
onPlaylistTap: (playlist) async {
  final playlistId = playlist.id;
  if (playlistId == null) return;

  // 1. 记录最后播放的歌单
  final repository = PlaylistRepository();
  await repository.setAppState('last_playlist_id', playlistId.toString());

  // 2. 选择歌单（加载歌曲）
  await playlistProvider.selectPlaylist(playlistId);

  // 3. 获取歌曲列表
  final songs = playlistProvider.selectedPlaylistSongs;

  if (songs.isNotEmpty) {
    // 4. 设置播放列表并自动播放
    await playerProvider.setPlaylist(songs, autoPlay: true);
  }

  // 5. 抽屉会自动关闭（在 AppDrawer 中处理）
},
```

- [ ] **Step 5: 验证修改**

运行静态分析：

```bash
cd mysic_flutter && flutter analyze
```

- [ ] **Step 6: 提交**

```bash
git add mysic_flutter/lib/main.dart
git commit -m "feat: 实现自动播放上次歌单功能"
```

---

### Task 4: 集成测试验证

**Files:**
- 无新增文件

- [ ] **Step 1: 运行应用进行手动测试**

```bash
cd mysic_flutter && flutter run -d windows
```

测试场景：
1. 首次启动（无记录）→ 应自动播放"本地音乐"歌单
2. 点击其他歌单播放 → 退出应用 → 重新启动 → 应自动播放该歌单
3. 删除上次播放的歌单 → 退出应用 → 重新启动 → 应回退到"本地音乐"歌单

- [ ] **Step 2: 最终提交（如有遗漏修改）**

```bash
git status
# 如有未提交的修改
git add -A
git commit -m "fix: 修复自动播放功能遗漏问题"
```
