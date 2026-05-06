# 本地音乐默认歌单设计文档

## 功能概述

创建一个系统默认歌单"本地音乐"，自动同步所有扫描到的本地歌曲，且不可被用户删除。

## 核心特性

1. **自动创建** — 应用首次启动时自动创建"本地音乐"歌单
2. **固定首位** — 始终显示在歌单列表第一位
3. **不可删除** — 用户无法删除此歌单（UI 上隐藏删除按钮）
4. **自动同步** — 扫描到新歌曲时自动添加到此歌单
5. **排除机制** — 用户移除歌曲后记录排除列表，不再自动添加该歌曲

## 数据结构变更

### 数据库表变更

#### 1. playlists 表新增字段

```sql
ALTER TABLE playlists ADD COLUMN is_system INTEGER NOT NULL DEFAULT 0;
```

- `is_system`: 标识是否为系统歌单（0 = 用户歌单，1 = 系统歌单）

#### 2. 新增 excluded_songs 表

```sql
CREATE TABLE excluded_songs (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  song_id INTEGER NOT NULL,
  excluded_at TEXT NOT NULL,
  FOREIGN KEY (song_id) REFERENCES songs (id) ON DELETE CASCADE,
  UNIQUE(song_id)
);
```

- 记录用户从"本地音乐"歌单中手动移除的歌曲
- 防止这些歌曲在下次扫描时被重新添加

### 模型变更

#### Playlist 模型

新增属性：
```dart
final bool isSystem;
```

`fromMap` 和 `toMap` 方法需相应更新。

## 实现要点

### 1. 数据库迁移

- 数据库版本从 8 升级到 9
- `onUpgrade` 中添加迁移逻辑：
  - 添加 `is_system` 字段
  - 创建 `excluded_songs` 表
  - 创建索引

### 2. 初始化逻辑

在 `PlaylistProvider._loadData()` 中：

```dart
Future<void> _ensureSystemPlaylistExists() async {
  final systemPlaylist = await _repository.getSystemPlaylist();
  if (systemPlaylist == null) {
    await _repository.createSystemPlaylist(
      name: '本地音乐',
      description: '自动同步本地扫描的所有音乐',
    );
  }
}
```

在 `PlaylistRepository` 中新增：
- `getSystemPlaylist()` — 获取系统歌单
- `createSystemPlaylist()` — 创建系统歌单（设置 `is_system = 1`）

### 3. 同步逻辑

扫描完成后（`MusicScanner` 扫描结束）：

```dart
Future<void> syncSongsToLocalMusicPlaylist(List<Song> scannedSongs) async {
  final systemPlaylistId = await _repository.getSystemPlaylistId();
  if (systemPlaylistId == null) return;

  final excludedSongIds = await _repository.getExcludedSongIds();

  for (final song in scannedSongs) {
    // 跳过已排除的歌曲
    if (excludedSongIds.contains(song.id)) continue;

    // 添加到本地音乐歌单
    await _repository.addSongToPlaylist(systemPlaylistId, song);
  }
}
```

在 `PlaylistRepository` 中新增：
- `getSystemPlaylistId()` — 获取系统歌单 ID
- `getExcludedSongIds()` — 获取排除歌曲 ID 列表
- `excludeSong()` — 添加歌曲到排除列表
- `restoreSong()` — 从排除列表移除歌曲

### 4. 移除歌曲逻辑

从"本地音乐"歌单移除歌曲时：

```dart
Future<bool> removeSongFromSystemPlaylist(int songId) async {
  // 1. 从歌单移除
  final success = await removeSongFromPlaylist(systemPlaylistId, songId);

  // 2. 添加到排除列表
  if (success) {
    await excludeSong(songId);
  }

  return success;
}
```

### 5. UI 调整

#### 歌单列表显示

- 系统歌单始终排在第一位（查询排序调整）
- 系统歌单显示特殊图标标识（如文件夹图标）
- 系统歌单隐藏删除按钮和重命名选项

#### 歌单项组件 (PlaylistItem)

```dart
// 根据是否为系统歌单显示不同 UI
if (playlist.isSystem) {
  // 显示系统歌单图标
  // 隐藏删除/重命名按钮
}
```

### 6. 排序调整

歌单查询排序逻辑：

```sql
SELECT * FROM playlists
ORDER BY is_system DESC, updated_at DESC
```

- 系统歌单优先（`is_system DESC`）
- 用户歌单按更新时间排序

## API 变更

### PlaylistRepository 新增方法

| 方法 | 说明 |
|------|------|
| `getSystemPlaylist()` | 获取系统歌单 |
| `createSystemPlaylist()` | 创建系统歌单 |
| `getSystemPlaylistId()` | 获取系统歌单 ID |
| `getExcludedSongIds()` | 获取排除歌曲 ID 列表 |
| `excludeSong(int songId)` | 添加歌曲到排除列表 |
| `restoreSong(int songId)` | 从排除列表移除歌曲 |
| `isSongExcluded(int songId)` | 检查歌曲是否被排除 |

### PlaylistProvider 新增方法

| 方法 | 说明 |
|------|------|
| `syncToLocalMusicPlaylist(List<Song>)` | 同步歌曲到本地音乐歌单 |
| `removeFromLocalMusic(int songId)` | 从本地音乐移除并排除 |
| `restoreToLocalMusic(int songId)` | 恢复歌曲到本地音乐 |

## 测试要点

1. **初始化测试** — 验证首次启动时自动创建系统歌单
2. **同步测试** — 验证扫描后歌曲自动添加到系统歌单
3. **排除测试** — 验证移除歌曲后不再自动添加
4. **恢复测试** — 验证可以恢复被排除的歌曲
5. **排序测试** — 验证系统歌单始终在第一位
6. **删除保护测试** — 验证系统歌单无法被删除

## 注意事项

1. 系统歌单的 ID 应在创建后记录，便于后续操作
2. 排除列表仅对"本地音乐"歌单生效，不影响用户自定义歌单
3. 用户删除歌曲（从库中删除）时，应同时清理排除列表中的记录
4. 系统歌单的重命名功能可考虑开放，允许用户自定义名称（可选）