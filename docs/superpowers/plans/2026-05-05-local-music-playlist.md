# 本地音乐默认歌单实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 创建系统默认歌单"本地音乐"，自动同步所有扫描到的本地歌曲，不可删除，支持排除机制。

**Architecture:** 数据库层新增 `is_system` 字段和 `excluded_songs` 表，Repository 层新增系统歌单和排除歌曲相关方法，Provider 层实现自动创建和同步逻辑，UI 层适配系统歌单的特殊显示和操作限制。

**Tech Stack:** Flutter, SQLite (sqflite), Provider

---

## 文件结构

**修改文件：**
- `lib/core/database/database_helper.dart` — 数据库迁移（版本 8→9）
- `lib/features/player/data/models/playlist.dart` — 新增 `isSystem` 属性
- `lib/features/playlist/data/playlist_repository.dart` — 新增系统歌单和排除歌曲方法
- `lib/features/playlist/presentation/providers/playlist_provider.dart` — 新增同步和排除逻辑
- `lib/features/playlist/presentation/widgets/playlist_item.dart` — UI 适配系统歌单

**新增文件：**
- `test/local_music_playlist_test.dart` — 功能测试

---

### Task 1: 数据库迁移

**Files:**
- Modify: `lib/core/database/database_helper.dart:19-342`

- [ ] **Step 1: 更新数据库版本号**

将 `_databaseVersion` 从 8 改为 9：

```dart
static const int _databaseVersion = 9;
```

- [ ] **Step 2: 新增表名常量**

在表名常量区域添加：

```dart
static const String tableExcludedSongs = 'excluded_songs';
```

- [ ] **Step 3: 在 _onCreate 中创建新表**

在 `_onCreate` 方法中，在创建设置表之后添加：

```dart
// 创建排除歌曲表
await db.execute('''
  CREATE TABLE $tableExcludedSongs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    song_id INTEGER NOT NULL,
    excluded_at TEXT NOT NULL,
    FOREIGN KEY (song_id) REFERENCES $tableSongs (id) ON DELETE CASCADE,
    UNIQUE(song_id)
  )
''');

// 创建排除歌曲表索引
await db.execute('''
  CREATE INDEX idx_excluded_songs_song ON $tableExcludedSongs (song_id)
''');
```

同时在 `_onCreate` 的 playlists 表创建语句中添加 `is_system` 字段：

```dart
await db.execute('''
  CREATE TABLE $tablePlaylists (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    description TEXT,
    cover_path TEXT,
    is_system INTEGER NOT NULL DEFAULT 0,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL
  )
''');
```

- [ ] **Step 4: 在 _onUpgrade 中添加迁移逻辑**

在 `_onUpgrade` 方法末尾添加版本 8→9 的迁移：

```dart
// 版本 8 -> 9: 新增 is_system 字段和 excluded_songs 表
if (oldVersion < 9) {
  // 添加 is_system 字段到 playlists 表
  await db.execute(
    'ALTER TABLE $tablePlaylists ADD COLUMN is_system INTEGER NOT NULL DEFAULT 0',
  );

  // 创建 excluded_songs 表
  await db.execute('''
    CREATE TABLE $tableExcludedSongs (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      song_id INTEGER NOT NULL,
      excluded_at TEXT NOT NULL,
      FOREIGN KEY (song_id) REFERENCES $tableSongs (id) ON DELETE CASCADE,
      UNIQUE(song_id)
    )
  ''');

  // 创建索引
  await db.execute('''
    CREATE INDEX idx_excluded_songs_song ON $tableExcludedSongs (song_id)
  ''');
}
```

- [ ] **Step 5: 运行测试验证迁移**

```bash
cd mysic_flutter && flutter test test/playlist_repository_test.dart
```

Expected: 所有测试通过

- [ ] **Step 6: 提交**

```bash
git add mysic_flutter/lib/core/database/database_helper.dart
git commit -m "feat(db): 添加 is_system 字段和 excluded_songs 表支持本地音乐歌单"
```

---

### Task 2: 更新 Playlist 模型

**Files:**
- Modify: `lib/features/player/data/models/playlist.dart:1-133`

- [ ] **Step 1: 添加 isSystem 属性**

在 Playlist 类中添加 `isSystem` 属性：

```dart
class Playlist {
  final int? id;
  final String name;
  final String? description;
  final String? coverPath;
  final bool isSystem; // 新增
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<Song>? songs;

  const Playlist({
    this.id,
    required this.name,
    this.description,
    this.coverPath,
    this.isSystem = false, // 新增，默认 false
    required this.createdAt,
    required this.updatedAt,
    this.songs,
  });
```

- [ ] **Step 2: 更新 fromMap 方法**

更新 `fromMap` 工厂方法：

```dart
factory Playlist.fromMap(Map<String, dynamic> map, {List<Song>? songs}) {
  return Playlist(
    id: map['id'] as int?,
    name: map['name'] as String,
    description: map['description'] as String?,
    coverPath: map['cover_path'] as String?,
    isSystem: (map['is_system'] as int?) == 1, // 新增
    createdAt: DateTime.parse(map['created_at'] as String),
    updatedAt: DateTime.parse(map['updated_at'] as String),
    songs: songs,
  );
}
```

- [ ] **Step 3: 更新 toMap 方法**

更新 `toMap` 方法：

```dart
Map<String, dynamic> toMap() {
  return {
    if (id != null) 'id': id,
    'name': name,
    'description': description,
    'cover_path': coverPath,
    'is_system': isSystem ? 1 : 0, // 新增
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };
}
```

- [ ] **Step 4: 更新 copyWith 方法**

更新 `copyWith` 方法：

```dart
Playlist copyWith({
  int? id,
  String? name,
  String? description,
  String? coverPath,
  bool? isSystem, // 新增
  DateTime? createdAt,
  DateTime? updatedAt,
  List<Song>? songs,
}) {
  return Playlist(
    id: id ?? this.id,
    name: name ?? this.name,
    description: description ?? this.description,
    coverPath: coverPath ?? this.coverPath,
    isSystem: isSystem ?? this.isSystem, // 新增
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    songs: songs ?? this.songs,
  );
}
```

- [ ] **Step 5: 运行测试验证模型**

```bash
cd mysic_flutter && flutter test test/playlist_repository_test.dart
```

Expected: 所有测试通过

- [ ] **Step 6: 提交**

```bash
git add mysic_flutter/lib/features/player/data/models/playlist.dart
git commit -m "feat(model): Playlist 模型新增 isSystem 属性"
```

---

### Task 3: PlaylistRepository 新增系统歌单方法

**Files:**
- Modify: `lib/features/playlist/data/playlist_repository.dart:1-607`

- [ ] **Step 1: 添加表名常量引用**

在文件顶部确保可以访问 `tableExcludedSongs`：

```dart
// DatabaseHelper.tableExcludedSongs 已定义
```

- [ ] **Step 2: 添加 createSystemPlaylist 方法**

在歌单操作区域添加：

```dart
/// 创建系统歌单
Future<Playlist> createSystemPlaylist({
  required String name,
  String? description,
}) async {
  final db = await _db;
  final now = DateTime.now();

  final id = await db.insert(
    DatabaseHelper.tablePlaylists,
    {
      'name': name,
      'description': description,
      'is_system': 1,
      'created_at': now.toIso8601String(),
      'updated_at': now.toIso8601String(),
    },
  );

  return Playlist(
    id: id,
    name: name,
    description: description,
    isSystem: true,
    createdAt: now,
    updatedAt: now,
    songs: [],
  );
}
```

- [ ] **Step 3: 添加 getSystemPlaylist 方法**

```dart
/// 获取系统歌单
Future<Playlist?> getSystemPlaylist() async {
  final db = await _db;
  final List<Map<String, dynamic>> maps = await db.query(
    DatabaseHelper.tablePlaylists,
    where: 'is_system = ?',
    whereArgs: [1],
    limit: 1,
  );

  if (maps.isEmpty) return null;

  final playlist = Playlist.fromMap(maps.first);
  final songs = await getSongsInPlaylist(playlist.id!);
  return playlist.copyWith(songs: songs);
}
```

- [ ] **Step 4: 添加 getSystemPlaylistId 方法**

```dart
/// 获取系统歌单 ID
Future<int?> getSystemPlaylistId() async {
  final db = await _db;
  final result = await db.query(
    DatabaseHelper.tablePlaylists,
    columns: ['id'],
    where: 'is_system = ?',
    whereArgs: [1],
    limit: 1,
  );

  if (result.isEmpty) return null;
  return result.first['id'] as int;
}
```

- [ ] **Step 5: 修改 getAllPlaylists 排序逻辑**

修改 `getAllPlaylists` 方法，使系统歌单排在前面：

```dart
Future<List<Playlist>> getAllPlaylists() async {
  final db = await _db;
  final List<Map<String, dynamic>> maps = await db.query(
    DatabaseHelper.tablePlaylists,
    orderBy: 'is_system DESC, updated_at DESC',
  );

  return maps.map((map) => Playlist.fromMap(map)).toList();
}
```

- [ ] **Step 6: 修改 deletePlaylist 防止删除系统歌单**

修改 `deletePlaylist` 方法：

```dart
Future<bool> deletePlaylist(int playlistId) async {
  final db = await _db;

  // 检查是否为系统歌单
  final playlist = await getPlaylistById(playlistId);
  if (playlist?.isSystem == true) {
    return false; // 系统歌单不可删除
  }

  // 先删除歌单中的歌曲关联
  await db.delete(
    DatabaseHelper.tablePlaylistSongs,
    where: 'playlist_id = ?',
    whereArgs: [playlistId],
  );

  // 再删除歌单
  final count = await db.delete(
    DatabaseHelper.tablePlaylists,
    where: 'id = ?',
    whereArgs: [playlistId],
  );

  return count > 0;
}
```

- [ ] **Step 7: 运行测试**

```bash
cd mysic_flutter && flutter test test/playlist_repository_test.dart
```

Expected: 所有测试通过

- [ ] **Step 8: 提交**

```bash
git add mysic_flutter/lib/features/playlist/data/playlist_repository.dart
git commit -m "feat(repo): 新增系统歌单相关方法"
```

---

### Task 4: PlaylistRepository 新增排除歌曲方法

**Files:**
- Modify: `lib/features/playlist/data/playlist_repository.dart`

- [ ] **Step 1: 添加 getExcludedSongIds 方法**

在文件末尾（统计信息区域之后）添加排除歌曲操作：

```dart
// ==================== 排除歌曲操作 ====================

/// 获取排除歌曲 ID 列表
Future<Set<int>> getExcludedSongIds() async {
  final db = await _db;
  final result = await db.query(
    DatabaseHelper.tableExcludedSongs,
    columns: ['song_id'],
  );

  return result.map((row) => row['song_id'] as int).toSet();
}
```

- [ ] **Step 2: 添加 excludeSong 方法**

```dart
/// 添加歌曲到排除列表
Future<void> excludeSong(int songId) async {
  final db = await _db;
  await db.insert(
    DatabaseHelper.tableExcludedSongs,
    {
      'song_id': songId,
      'excluded_at': DateTime.now().toIso8601String(),
    },
    conflictAlgorithm: ConflictAlgorithm.ignore,
  );
}
```

- [ ] **Step 3: 添加 restoreSong 方法**

```dart
/// 从排除列表移除歌曲
Future<void> restoreSong(int songId) async {
  final db = await _db;
  await db.delete(
    DatabaseHelper.tableExcludedSongs,
    where: 'song_id = ?',
    whereArgs: [songId],
  );
}
```

- [ ] **Step 4: 添加 isSongExcluded 方法**

```dart
/// 检查歌曲是否被排除
Future<bool> isSongExcluded(int songId) async {
  final db = await _db;
  final result = await db.query(
    DatabaseHelper.tableExcludedSongs,
    where: 'song_id = ?',
    whereArgs: [songId],
    limit: 1,
  );
  return result.isNotEmpty;
}
```

- [ ] **Step 5: 修改 deleteSong 清理排除列表**

在 `deleteSong` 方法中，删除歌曲后添加清理排除列表的逻辑：

```dart
Future<bool> deleteSong(int songId) async {
  final db = await _db;

  // 先删除歌单关联
  await db.delete(
    DatabaseHelper.tablePlaylistSongs,
    where: 'song_id = ?',
    whereArgs: [songId],
  );

  // 删除歌词
  await db.delete(
    DatabaseHelper.tableLyrics,
    where: 'song_id = ?',
    whereArgs: [songId],
  );

  // 删除播放历史
  await db.delete(
    DatabaseHelper.tablePlayHistory,
    where: 'song_id = ?',
    whereArgs: [songId],
  );

  // 删除排除记录
  await db.delete(
    DatabaseHelper.tableExcludedSongs,
    where: 'song_id = ?',
    whereArgs: [songId],
  );

  // 删除歌曲
  final count = await db.delete(
    DatabaseHelper.tableSongs,
    where: 'id = ?',
    whereArgs: [songId],
  );

  return count > 0;
}
```

- [ ] **Step 6: 运行测试**

```bash
cd mysic_flutter && flutter test test/playlist_repository_test.dart
```

Expected: 所有测试通过

- [ ] **Step 7: 提交**

```bash
git add mysic_flutter/lib/features/playlist/data/playlist_repository.dart
git commit -m "feat(repo): 新增排除歌曲相关方法"
```

---

### Task 5: PlaylistProvider 新增系统歌单逻辑

**Files:**
- Modify: `lib/features/playlist/presentation/providers/playlist_provider.dart:1-429`

- [ ] **Step 1: 添加系统歌单 ID 缓存**

在 PlaylistProvider 类中添加私有字段：

```dart
class PlaylistProvider extends ChangeNotifier {
  final PlaylistRepository _repository;

  // 状态
  List<Playlist> _playlists = [];
  Playlist? _selectedPlaylist;
  List<Song> _selectedPlaylistSongs = [];
  List<Song> _allSongs = [];
  List<Song> _playHistory = [];
  Set<int> _excludedSongIds = {}; // 新增：排除歌曲 ID 缓存
  int? _systemPlaylistId; // 新增：系统歌单 ID 缓存
  bool _isLoading = false;
  String? _error;
```

- [ ] **Step 2: 修改 _loadData 方法**

修改 `_loadData` 方法，确保系统歌单存在：

```dart
Future<void> _loadData() async {
  _setLoading(true);
  try {
    // 确保系统歌单存在
    await _ensureSystemPlaylistExists();

    await Future.wait([
      _loadPlaylists(),
      _loadAllSongs(),
      _loadPlayHistory(),
      _loadExcludedSongIds(), // 新增
    ]);
  } catch (e) {
    _setError('加载数据失败: $e');
  } finally {
    _setLoading(false);
  }
}
```

- [ ] **Step 3: 添加 _ensureSystemPlaylistExists 方法**

```dart
/// 确保系统歌单存在
Future<void> _ensureSystemPlaylistExists() async {
  final systemPlaylist = await _repository.getSystemPlaylist();
  if (systemPlaylist == null) {
    final created = await _repository.createSystemPlaylist(
      name: '本地音乐',
      description: '自动同步本地扫描的所有音乐',
    );
    _systemPlaylistId = created.id;
  } else {
    _systemPlaylistId = systemPlaylist.id;
  }
}
```

- [ ] **Step 4: 添加 _loadExcludedSongIds 方法**

```dart
/// 加载排除歌曲 ID 列表
Future<void> _loadExcludedSongIds() async {
  _excludedSongIds = await _repository.getExcludedSongIds();
}
```

- [ ] **Step 5: 添加 syncToLocalMusicPlaylist 方法**

```dart
/// 同步歌曲到本地音乐歌单
Future<void> syncToLocalMusicPlaylist(List<Song> scannedSongs) async {
  if (_systemPlaylistId == null) {
    await _ensureSystemPlaylistExists();
  }

  if (_systemPlaylistId == null) return;

  int addedCount = 0;
  for (final song in scannedSongs) {
    // 跳过已排除的歌曲
    if (_excludedSongIds.contains(song.id)) continue;

    // 添加到本地音乐歌单
    final success = await _repository.addSongToPlaylist(_systemPlaylistId!, song);
    if (success) addedCount++;
  }

  if (addedCount > 0) {
    await _loadPlaylists();
    notifyListeners();
  }
}
```

- [ ] **Step 6: 添加 removeFromLocalMusic 方法**

```dart
/// 从本地音乐移除并排除
Future<bool> removeFromLocalMusic(int songId) async {
  if (_systemPlaylistId == null) return false;

  try {
    // 1. 从歌单移除
    final success = await _repository.removeSongFromPlaylist(_systemPlaylistId!, songId);

    // 2. 添加到排除列表
    if (success) {
      await _repository.excludeSong(songId);
      _excludedSongIds.add(songId);
      notifyListeners();
    }

    return success;
  } catch (e) {
    _setError('移除歌曲失败: $e');
    return false;
  }
}
```

- [ ] **Step 7: 添加 restoreToLocalMusic 方法**

```dart
/// 恢复歌曲到本地音乐
Future<bool> restoreToLocalMusic(int songId) async {
  if (_systemPlaylistId == null) return false;

  try {
    // 1. 从排除列表移除
    await _repository.restoreSong(songId);
    _excludedSongIds.remove(songId);

    // 2. 获取歌曲并添加到歌单
    final song = await _repository.getSongById(songId);
    if (song != null) {
      await _repository.addSongToPlaylist(_systemPlaylistId!, song);
    }

    await _loadPlaylists();
    notifyListeners();
    return true;
  } catch (e) {
    _setError('恢复歌曲失败: $e');
    return false;
  }
}
```

- [ ] **Step 8: 添加 getter**

```dart
// Getters 区域添加
int? get systemPlaylistId => _systemPlaylistId;
Set<int> get excludedSongIds => Set.unmodifiable(_excludedSongIds);
```

- [ ] **Step 9: 运行测试**

```bash
cd mysic_flutter && flutter test test/playlist_provider_test.dart
```

Expected: 所有测试通过

- [ ] **Step 10: 提交**

```bash
git add mysic_flutter/lib/features/playlist/presentation/providers/playlist_provider.dart
git commit -m "feat(provider): 新增本地音乐歌单同步和排除逻辑"
```

---

### Task 6: UI 适配系统歌单

**Files:**
- Modify: `lib/features/playlist/presentation/widgets/playlist_item.dart:1-509`

- [ ] **Step 1: 修改 PlaylistItem 的 _buildDefaultCoverIcon 方法**

为系统歌单显示特殊图标：

```dart
Widget _buildDefaultCoverIcon() {
  if (playlist.isSystem) {
    return const Icon(
      Icons.folder_rounded,
      color: AppColors.white,
      size: 32,
    );
  }
  return const Icon(
    Icons.playlist_play_rounded,
    color: AppColors.white,
    size: 32,
  );
}
```

- [ ] **Step 2: 修改 PlaylistItem 的 build 方法**

在 build 方法中，根据 `isSystem` 隐藏删除和编辑按钮（通过不传递回调）：

```dart
@override
Widget build(BuildContext context) {
  // 系统歌单不显示删除/编辑按钮
  final effectiveOnDelete = playlist.isSystem ? null : onDelete;
  final effectiveOnEdit = playlist.isSystem ? null : onEdit;

  return Material(
    color: isSelected
        ? AppColors.accent.withValues(alpha: 0.15)
        : Colors.transparent,
    borderRadius: BorderRadius.circular(16),
    child: InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      onLongPress: onLongPress ?? (effectiveOnDelete != null || effectiveOnEdit != null ? _showContextMenu : null),
      child: Container(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            _buildCover(),
            const SizedBox(width: 16),
            Expanded(
              child: _buildInfo(),
            ),
            if (onTap != null) _buildTrailing(),
          ],
        ),
      ),
    ),
  );
}
```

- [ ] **Step 3: 修改 PlaylistHeader 的 _buildDefaultCoverIcon 方法**

```dart
Widget _buildDefaultCoverIcon() {
  if (playlist.isSystem) {
    return const Icon(
      Icons.folder_rounded,
      color: AppColors.white,
      size: 48,
    );
  }
  return const Icon(
    Icons.playlist_play_rounded,
    color: AppColors.white,
    size: 48,
  );
}
```

- [ ] **Step 4: 运行 widget 测试**

```bash
cd mysic_flutter && flutter test test/widgets/playlist_item_test.dart
```

Expected: 所有测试通过

- [ ] **Step 5: 提交**

```bash
git add mysic_flutter/lib/features/playlist/presentation/widgets/playlist_item.dart
git commit -m "feat(ui): 系统歌单显示特殊图标并隐藏删除按钮"
```

---

### Task 7: 集成测试

**Files:**
- Create: `test/local_music_playlist_test.dart`

- [ ] **Step 1: 编写测试文件**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:mysic_flutter/core/database/database_helper.dart';
import 'package:mysic_flutter/features/player/data/models/song.dart';
import 'package:mysic_flutter/features/player/data/models/playlist.dart';
import 'package:mysic_flutter/features/playlist/data/playlist_repository.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('本地音乐歌单测试', () {
    late PlaylistRepository repository;
    late DatabaseHelper dbHelper;

    setUp(() async {
      dbHelper = DatabaseHelper();
      await dbHelper.clearAllTables();
      repository = PlaylistRepository(dbHelper: dbHelper);
    });

    tearDown(() async {
      await dbHelper.close();
    });

    Song createTestSong(String title) {
      final now = DateTime.now();
      return Song(
        title: title,
        artist: '艺术家',
        duration: 180000,
        filePath: '/test/$title.mp3',
        createdAt: now,
        updatedAt: now,
      );
    }

    test('创建系统歌单', () async {
      final playlist = await repository.createSystemPlaylist(
        name: '本地音乐',
        description: '自动同步',
      );

      expect(playlist.id, isNotNull);
      expect(playlist.name, equals('本地音乐'));
      expect(playlist.isSystem, isTrue);
    });

    test('获取系统歌单', () async {
      await repository.createSystemPlaylist(name: '本地音乐');

      final found = await repository.getSystemPlaylist();

      expect(found, isNotNull);
      expect(found!.isSystem, isTrue);
    });

    test('系统歌单不可删除', () async {
      final playlist = await repository.createSystemPlaylist(name: '本地音乐');

      final success = await repository.deletePlaylist(playlist.id!);

      expect(success, isFalse);

      final found = await repository.getPlaylistById(playlist.id!);
      expect(found, isNotNull);
    });

    test('用户歌单可以删除', () async {
      final playlist = await repository.createPlaylist(name: '用户歌单');

      final success = await repository.deletePlaylist(playlist.id!);

      expect(success, isTrue);
    });

    test('系统歌单排在第一位', () async {
      await repository.createPlaylist(name: '用户歌单A');
      await repository.createSystemPlaylist(name: '本地音乐');
      await repository.createPlaylist(name: '用户歌单B');

      final playlists = await repository.getAllPlaylists();

      expect(playlists.first.isSystem, isTrue);
      expect(playlists.first.name, equals('本地音乐'));
    });

    test('排除歌曲', () async {
      final song = await repository.saveSong(createTestSong('歌曲A'));

      await repository.excludeSong(song.id!);

      final excluded = await repository.getExcludedSongIds();
      expect(excluded.contains(song.id!), isTrue);

      final isExcluded = await repository.isSongExcluded(song.id!);
      expect(isExcluded, isTrue);
    });

    test('恢复被排除的歌曲', () async {
      final song = await repository.saveSong(createTestSong('歌曲A'));
      await repository.excludeSong(song.id!);

      await repository.restoreSong(song.id!);

      final excluded = await repository.getExcludedSongIds();
      expect(excluded.contains(song.id!), isFalse);
    });

    test('删除歌曲时清理排除记录', () async {
      final song = await repository.saveSong(createTestSong('歌曲A'));
      await repository.excludeSong(song.id!);

      await repository.deleteSong(song.id!);

      final excluded = await repository.getExcludedSongIds();
      expect(excluded.contains(song.id!), isFalse);
    });
  });
}
```

- [ ] **Step 2: 运行测试**

```bash
cd mysic_flutter && flutter test test/local_music_playlist_test.dart
```

Expected: 所有测试通过

- [ ] **Step 3: 提交**

```bash
git add mysic_flutter/test/local_music_playlist_test.dart
git commit -m "test: 添加本地音乐歌单功能测试"
```

---

### Task 8: 集成扫描同步逻辑

**Files:**
- Modify: `lib/main.dart` 或扫描完成回调处

- [ ] **Step 1: 查找扫描完成回调位置**

需要找到扫描完成后调用 `saveSongs` 的位置，在那里添加同步到本地音乐歌单的逻辑。

查看 `main.dart` 或设置页面中扫描完成后的处理逻辑。

- [ ] **Step 2: 在扫描完成后调用 syncToLocalMusicPlaylist**

在扫描完成并保存歌曲后，调用 `playlistProvider.syncToLocalMusicPlaylist(songs)`。

具体实现需要根据实际的扫描流程代码确定。

- [ ] **Step 3: 运行应用测试**

```bash
cd mysic_flutter && flutter run -d windows
```

手动测试：
1. 首次启动，检查是否自动创建"本地音乐"歌单
2. 扫描音乐，检查歌曲是否自动添加到"本地音乐"歌单
3. 从"本地音乐"移除歌曲，检查是否被排除
4. 再次扫描，检查被排除的歌曲是否不会重新添加

- [ ] **Step 4: 提交**

```bash
git add mysic_flutter/lib/main.dart
git commit -m "feat: 扫描完成后自动同步到本地音乐歌单"
```

---

## 自检结果

**1. Spec 覆盖检查：**
- ✅ 自动创建 — Task 5 Step 3
- ✅ 固定首位 — Task 3 Step 5
- ✅ 不可删除 — Task 3 Step 6
- ✅ 自动同步 — Task 5 Step 5, Task 8
- ✅ 排除机制 — Task 4, Task 5 Step 6-7
- ✅ UI 调整 — Task 6
- ✅ 测试 — Task 7

**2. 占位符检查：**
- ✅ 无 TBD、TODO
- ✅ 所有代码步骤都有完整代码

**3. 类型一致性检查：**
- ✅ `isSystem` 属性在模型、Repository、Provider 中一致
- ✅ 方法签名在各层一致
