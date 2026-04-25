# 歌曲删除功能实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在播放页面添加歌曲删除功能，通过弹出菜单触发，删除后歌曲从所有歌单移除且再次扫描不会添加。

**Architecture:** 采用软删除方案，在 songs 表添加 is_deleted 字段标记删除状态。扫描时跳过已删除的文件路径。UI 使用 PopupMenu 和 BottomSheet 实现类似微信的交互体验。

**Tech Stack:** Flutter, SQLite (sqflite), Provider

---

## Task 1: 数据库升级 - 添加 is_deleted 字段

**Files:**
- Modify: `mysic_flutter/lib/core/database/database_helper.dart`

- [ ] **Step 1: 更新数据库版本号和字段定义**

修改 `database_helper.dart`:

```dart
// 第 19 行，修改版本号
static const int _databaseVersion = 4;

// 在 _onCreate 方法中，songs 表创建语句添加 is_deleted 字段
// 第 58-71 行，修改 CREATE TABLE 语句
await db.execute('''
  CREATE TABLE $tableSongs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    title TEXT NOT NULL,
    artist TEXT,
    album TEXT,
    duration INTEGER NOT NULL,
    file_path TEXT NOT NULL UNIQUE,
    album_art_path TEXT,
    date_added INTEGER,
    is_deleted INTEGER NOT NULL DEFAULT 0,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL
  )
''');
```

- [ ] **Step 2: 添加数据库升级逻辑**

在 `_onUpgrade` 方法末尾添加版本 3→4 的升级逻辑:

```dart
// 版本 3 -> 4: 新增 is_deleted 字段
if (oldVersion < 4) {
  await db.execute('ALTER TABLE songs ADD COLUMN is_deleted INTEGER NOT NULL DEFAULT 0');
}
```

- [ ] **Step 3: 提交数据库变更**

```bash
cd mysic_flutter && git add lib/core/database/database_helper.dart
git commit -m "feat: 数据库升级到版本 4，添加 is_deleted 字段"
```

---

## Task 2: SongRepository 新增标记删除方法

**Files:**
- Modify: `mysic_flutter/lib/features/player/data/repositories/song_repository.dart`

- [ ] **Step 1: 添加 markAsDeleted 方法**

在 `song_repository.dart` 的 `deleteSong` 方法后添加:

```dart
/// 标记歌曲为已删除（软删除）
Future<void> markAsDeleted(int songId) async {
  final db = await _dbHelper.database;
  await db.update(
    DatabaseHelper.tableSongs,
    {'is_deleted': 1, 'updated_at': DateTime.now().toIso8601String()},
    where: 'id = ?',
    whereArgs: [songId],
  );
}

/// 获取已删除的文件路径集合
Future<Set<String>> getDeletedFilePaths() async {
  final db = await _dbHelper.database;
  final maps = await db.query(
    DatabaseHelper.tableSongs,
    columns: ['file_path'],
    where: 'is_deleted = 1',
  );
  return maps.map((map) => map['file_path'] as String).toSet();
}
```

- [ ] **Step 2: 修改 getAllSongs 方法排除已删除歌曲**

```dart
/// 获取所有歌曲（排除已删除）
Future<List<Song>> getAllSongs() async {
  final db = await _dbHelper.database;
  final maps = await db.query(
    DatabaseHelper.tableSongs,
    where: 'is_deleted = 0 OR is_deleted IS NULL',
    orderBy: 'title ASC',
  );
  return maps.map((map) => Song.fromMap(map)).toList();
}
```

- [ ] **Step 3: 提交变更**

```bash
cd mysic_flutter && git add lib/features/player/data/repositories/song_repository.dart
git commit -m "feat: SongRepository 新增 markAsDeleted 和 getDeletedFilePaths 方法"
```

---

## Task 3: PlaylistRepository 新增从所有歌单移除歌曲方法

**Files:**
- Modify: `mysic_flutter/lib/features/playlist/data/playlist_repository.dart`

- [ ] **Step 1: 添加 removeFromAllPlaylists 方法**

在 `playlist_repository.dart` 的 `isSongInPlaylist` 方法后添加:

```dart
/// 从所有歌单中移除指定歌曲
Future<int> removeFromAllPlaylists(int songId) async {
  final db = await _db;

  // 获取包含该歌曲的所有歌单 ID
  final playlistSongs = await db.query(
    DatabaseHelper.tablePlaylistSongs,
    columns: ['playlist_id'],
    where: 'song_id = ?',
    whereArgs: [songId],
  );

  final playlistIds = playlistSongs.map((ps) => ps['playlist_id'] as int).toSet();

  // 删除所有关联
  final count = await db.delete(
    DatabaseHelper.tablePlaylistSongs,
    where: 'song_id = ?',
    whereArgs: [songId],
  );

  // 更新相关歌单的时间戳
  for (final playlistId in playlistIds) {
    await _updatePlaylistTimestamp(playlistId);
  }

  return count;
}
```

- [ ] **Step 2: 提交变更**

```bash
cd mysic_flutter && git add lib/features/playlist/data/playlist_repository.dart
git commit -m "feat: PlaylistRepository 新增 removeFromAllPlaylists 方法"
```

---

## Task 4: WindowsMusicScanner 扫描时跳过已删除路径

**Files:**
- Modify: `mysic_flutter/lib/shared/utils/windows_music_scanner.dart`

- [ ] **Step 1: 修改 _saveSongsToDatabase 方法**

在 `_saveSongsToDatabase` 方法开头添加查询已删除路径的逻辑:

```dart
Future<Map<String, int>> _saveSongsToDatabase(List<File> songs) async {
  final db = await _dbHelper.database;
  int newAdded = 0;
  int duplicates = 0;
  int filtered = 0;
  int skipped = 0;
  final now = DateTime.now();
  final nowIso = now.toIso8601String();

  // 1. 查询所有已存在的路径
  final allExisting = await db.query(
    DatabaseHelper.tableSongs,
    columns: ['file_path'],
  );
  final existingPaths = allExisting.map((row) => row['file_path'] as String).toSet();

  // 2. 查询已删除的路径（软删除，需要跳过）
  final deletedPaths = await db.query(
    DatabaseHelper.tableSongs,
    columns: ['file_path'],
    where: 'is_deleted = 1',
  );
  final deletedPathSet = deletedPaths.map((row) => row['file_path'] as String).toSet();
```

- [ ] **Step 2: 在循环中添加跳过已删除路径的逻辑**

修改循环中的判断:

```dart
  // 3. 批量插入（使用事务）
  await db.transaction((txn) async {
    for (final file in songs) {
      if (isCancelled) break;

      final filePath = file.path;

      // 跳过已删除的路径
      if (deletedPathSet.contains(filePath)) {
        skipped++;
        continue;
      }

      if (existingPaths.contains(filePath)) {
        duplicates++;
      } else {
        // ... 其余代码保持不变
      }
    }
  });

  print('Windows扫描完成: newAdded=$newAdded, duplicates=$duplicates, filtered=$filtered, skipped=$skipped');
  return {'newAdded': newAdded, 'duplicates': duplicates};
}
```

- [ ] **Step 3: 提交变更**

```bash
cd mysic_flutter && git add lib/shared/utils/windows_music_scanner.dart
git commit -m "feat: WindowsMusicScanner 扫描时跳过已删除路径"
```

---

## Task 5: MobileMusicScanner 扫描时跳过已删除路径

**Files:**
- Modify: `mysic_flutter/lib/shared/utils/mobile_music_scanner.dart`

- [ ] **Step 1: 修改 _saveSongsToDatabase 方法**

在方法开头添加查询已删除路径的逻辑:

```dart
Future<Map<String, int>> _saveSongsToDatabase(List<SongModel> songs) async {
  final db = await _dbHelper.database;
  int newAdded = 0;
  int duplicates = 0;
  int filtered = 0;
  int skipped = 0;
  final now = DateTime.now();
  final nowIso = now.toIso8601String();

  // 查询已删除的路径（软删除，需要跳过）
  final deletedPaths = await db.query(
    DatabaseHelper.tableSongs,
    columns: ['file_path'],
    where: 'is_deleted = 1',
  );
  final deletedPathSet = deletedPaths.map((row) => row['file_path'] as String).toSet();
```

- [ ] **Step 2: 在循环中添加跳过逻辑**

```dart
  for (int i = 0; i < songs.length; i++) {
    if (isCancelled) break;

    final songModel = songs[i];

    // 跳过已删除的路径
    if (deletedPathSet.contains(songModel.data)) {
      skipped++;
      continue;
    }

    // 过滤：时长不在有效范围内（165秒 ~ 1500秒）
    // ... 其余代码保持不变
  }

  print('Mobile扫描完成: newAdded=$newAdded, duplicates=$duplicates, filtered=$filtered, skipped=$skipped');
  return {'newAdded': newAdded, 'duplicates': duplicates};
}
```

- [ ] **Step 3: 提交变更**

```bash
cd mysic_flutter && git add lib/shared/utils/mobile_music_scanner.dart
git commit -m "feat: MobileMusicScanner 扫描时跳过已删除路径"
```

---

## Task 6: PlayerProvider 新增 deleteSong 方法

**Files:**
- Modify: `mysic_flutter/lib/features/player/presentation/providers/player_provider.dart`

- [ ] **Step 1: 添加必要的 import**

在文件顶部添加:

```dart
import '../../../playlist/data/playlist_repository.dart';
```

- [ ] **Step 2: 添加 PlaylistRepository 依赖**

在 `PlayerProvider` 类中添加:

```dart
class PlayerProvider extends ChangeNotifier {
  final AudioPlayerService _audioPlayerService;
  final SongRepository _songRepository;
  final PlaylistRepository _playlistRepository;
  final LyricsParser _lyricsParser = LyricsParser();

  // ... 状态变量保持不变

  PlayerProvider({
    AudioPlayerService? audioPlayerService,
    SongRepository? songRepository,
    PlaylistRepository? playlistRepository,
  })  : _audioPlayerService = audioPlayerService ?? AudioPlayerService(),
        _songRepository = songRepository ?? SongRepository(),
        _playlistRepository = playlistRepository ?? PlaylistRepository() {
    _init();
  }
```

- [ ] **Step 3: 添加 deleteSong 方法**

在 `updateSong` 方法后添加:

```dart
/// 删除当前播放的歌曲
/// 返回 true 表示成功，false 表示失败
Future<bool> deleteCurrentSong() async {
  if (_currentSong == null || _currentSong!.id == null) return false;

  final songId = _currentSong!.id!;

  try {
    // 1. 标记为已删除
    await _songRepository.markAsDeleted(songId);

    // 2. 从所有歌单中移除
    await _playlistRepository.removeFromAllPlaylists(songId);

    // 3. 从播放列表中移除
    final playlistIndex = _playlist.indexWhere((s) => s.id == songId);
    if (playlistIndex != -1) {
      removeFromPlaylist(playlistIndex);
    }

    // 4. 清除当前歌曲引用
    _currentSong = null;
    _currentLyrics = LyricsResult.empty;

    notifyListeners();
    return true;
  } catch (e) {
    print('删除歌曲失败: $e');
    return false;
  }
}
```

- [ ] **Step 4: 提交变更**

```bash
cd mysic_flutter && git add lib/features/player/presentation/providers/player_provider.dart
git commit -m "feat: PlayerProvider 新增 deleteCurrentSong 方法"
```

---

## Task 7: PlayerPage UI - 重构 AppBar 为弹出菜单

**Files:**
- Modify: `mysic_flutter/lib/features/player/presentation/pages/player_page.dart`

- [ ] **Step 1: 添加必要的 import**

在文件顶部添加:

```dart
import 'dart:math' as math;
```

- [ ] **Step 2: 重构 _buildAppBar 方法**

替换整个 `_buildAppBar` 方法:

```dart
PreferredSizeWidget _buildAppBar(BuildContext context, PlayerProvider provider) {
  return AppBar(
    backgroundColor: AppColors.surface,
    elevation: 0,
    leading: IconButton(
      icon: const Icon(Icons.menu_rounded),
      onPressed: () {
        Scaffold.of(context).openDrawer();
      },
    ),
    title: const Text(
      '正在播放',
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
    ),
    centerTitle: true,
    actions: [
      _buildPopupMenu(context, provider),
    ],
  );
}
```

- [ ] **Step 3: 添加弹出菜单构建方法**

在 `_buildAppBar` 方法后添加:

```dart
Widget _buildPopupMenu(BuildContext context, PlayerProvider provider) {
  return PopupMenuButton<String>(
    icon: const Icon(Icons.add_rounded),
    color: AppColors.card,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    ),
    offset: const Offset(0, 48),
    onSelected: (value) => _handleMenuAction(context, provider, value),
    itemBuilder: (context) => [
      PopupMenuItem<String>(
        value: 'add_to_playlist',
        child: Row(
          children: [
            Icon(Icons.playlist_add, color: AppColors.white, size: 20),
            const SizedBox(width: 12),
            const Text('添加到歌单', style: TextStyle(color: AppColors.white)),
          ],
        ),
      ),
      PopupMenuItem<String>(
        value: 'edit',
        child: Row(
          children: [
            Icon(Icons.edit_rounded, color: AppColors.white, size: 20),
            const SizedBox(width: 12),
            const Text('编辑', style: TextStyle(color: AppColors.white)),
          ],
        ),
      ),
      const PopupMenuDivider(),
      PopupMenuItem<String>(
        value: 'delete',
        child: Row(
          children: [
            Icon(Icons.delete_rounded, color: const Color(0xFFEF4444), size: 20),
            const SizedBox(width: 12),
            const Text('删除', style: TextStyle(color: Color(0xFFEF4444))),
          ],
        ),
      ),
    ],
  );
}
```

- [ ] **Step 4: 添加菜单动作处理方法**

```dart
void _handleMenuAction(BuildContext context, PlayerProvider provider, String action) {
  switch (action) {
    case 'add_to_playlist':
      if (provider.currentSong == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请先选择歌曲')),
        );
        return;
      }
      _showAddToPlaylistSheet(context, provider);
      break;
    case 'edit':
      if (provider.currentSong == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请先选择歌曲')),
        );
        return;
      }
      _showEditDialog(context, provider.currentSong!);
      break;
    case 'delete':
      if (provider.currentSong == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请先选择歌曲')),
        );
        return;
      }
      _showDeleteConfirmSheet(context, provider);
      break;
  }
}
```

- [ ] **Step 5: 提交变更**

```bash
cd mysic_flutter && git add lib/features/player/presentation/pages/player_page.dart
git commit -m "feat: PlayerPage 重构 AppBar 为弹出菜单样式"
```

---

## Task 8: PlayerPage UI - 添加删除确认 BottomSheet

**Files:**
- Modify: `mysic_flutter/lib/features/player/presentation/pages/player_page.dart`

- [ ] **Step 1: 添加删除确认 BottomSheet 方法**

在 `_handleMenuAction` 方法后添加:

```dart
void _showDeleteConfirmSheet(BuildContext context, PlayerProvider provider) {
  showModalBottomSheet(
    context: context,
    backgroundColor: AppColors.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) => _DeleteConfirmSheet(
      song: provider.currentSong!,
      onConfirm: () async {
        Navigator.pop(context);
        final success = await provider.deleteCurrentSong();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(success ? '已删除' : '删除失败'),
              backgroundColor: success ? AppColors.accent : Colors.red,
            ),
          );
        }
      },
    ),
  );
}
```

- [ ] **Step 2: 添加删除确认 BottomSheet 组件**

在文件末尾 `_AddToPlaylistSheet` 类之后添加:

```dart
/// 删除确认底部面板
class _DeleteConfirmSheet extends StatelessWidget {
  final Song song;
  final VoidCallback onConfirm;

  const _DeleteConfirmSheet({
    required this.song,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            // 拖动指示器
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.muted.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            // 警告图标
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.warning_rounded,
                color: Color(0xFFEF4444),
                size: 28,
              ),
            ),
            const SizedBox(height: 16),
            // 标题
            const Text(
              '确认删除',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.white,
              ),
            ),
            const SizedBox(height: 8),
            // 歌曲名称
            Text(
              song.title,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.muted,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 16),
            // 警告文字
            const Text(
              '删除后歌曲将从所有歌单中移除，且再次扫描不会添加进来',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.muted,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            // 按钮行
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.muted,
                      side: const BorderSide(color: AppColors.muted),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('取消'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: onConfirm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEF4444),
                      foregroundColor: AppColors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('删除'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 3: 提交变更**

```bash
cd mysic_flutter && git add lib/features/player/presentation/pages/player_page.dart
git commit -m "feat: PlayerPage 添加删除确认 BottomSheet"
```

---

## Task 9: 运行测试和代码分析

**Files:**
- None

- [ ] **Step 1: 运行 Flutter 代码分析**

```bash
cd mysic_flutter && flutter analyze
```

Expected: No issues found

- [ ] **Step 2: 运行现有测试**

```bash
cd mysic_flutter && flutter test
```

Expected: All tests pass

- [ ] **Step 3: 手动测试应用**

```bash
cd mysic_flutter && flutter run -d windows
```

测试要点:
1. 点击加号按钮，验证弹出菜单显示正确
2. 无歌曲时点击删除，显示提示
3. 有歌曲时点击删除，显示确认 BottomSheet
4. 确认删除后，歌曲从播放列表移除
5. 重新扫描，验证已删除歌曲不会再次添加

---

## Task 10: 最终提交

**Files:**
- None

- [ ] **Step 1: 确认所有变更已提交**

```bash
cd mysic_flutter && git status
```

Expected: nothing to commit, working tree clean

- [ ] **Step 2: 推送到远程仓库（如需要）**

```bash
git push origin master
```
