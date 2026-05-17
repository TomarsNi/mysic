# 专辑封面关联功能实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 扫描歌曲时按优先级关联专辑封面：元数据内嵌封面 > 同名图片文件 > MediaStore 封面（仅 Android）

**Architecture:** 扩展 MetadataExtractor 新增封面提取方法，修改 Windows/Mobile 扫描器调整封面获取优先级逻辑

**Tech Stack:** Flutter, audiotags (封面提取), on_audio_query (Android MediaStore), SQLite

---

## 文件结构

| 文件 | 职责 |
|------|------|
| `lib/shared/utils/metadata_extractor.dart` | 新增 `extractArtwork()` 方法提取内嵌封面 |
| `lib/shared/utils/windows_music_scanner.dart` | 调整封面获取优先级：内嵌 > 同名图片 |
| `lib/shared/utils/mobile_music_scanner.dart` | 调整封面获取优先级：内嵌 > 同名图片 > MediaStore |

---

### Task 1: 扩展 MetadataExtractor 新增封面提取方法

**Files:**
- Modify: `lib/shared/utils/metadata_extractor.dart`

- [ ] **Step 1: 添加 `extractArtwork()` 方法**

在 `MetadataExtractor` 类中新增静态方法，从音频文件提取内嵌封面：

```dart
import 'dart:typed_data';

// 在 MetadataExtractor 类中添加:

/// 从音频文件提取内嵌封面
///
/// [filePath] 音频文件路径
/// 返回封面图片字节数据，无封面返回 null
static Future<Uint8List?> extractArtwork(String filePath) async {
  final extension = filePath.toLowerCase();

  // WAV 文件：RIFF INFO 不包含封面，直接返回 null
  if (extension.endsWith('.wav')) {
    return null;
  }

  // 其他格式使用 audiotags 提取
  try {
    final tag = await AudioTags.read(filePath);
    if (tag != null && tag.pictures.isNotEmpty) {
      // 优先查找 front cover，否则使用第一张图片
      for (final picture in tag.pictures) {
        if (picture.pictureType == PictureType.coverFront) {
          return picture.bytes;
        }
      }
      // 没有 front cover，使用第一张图片
      return tag.pictures.first.bytes;
    }
  } catch (e) {
    debugPrint('提取内嵌封面失败: $filePath, 错误: $e');
  }
  return null;
}
```

需要添加导入：

```dart
import 'package:audiotags/audiotags.dart';
```

- [ ] **Step 2: 验证代码编译通过**

Run: `cd mysic_flutter && flutter analyze lib/shared/utils/metadata_extractor.dart`

Expected: No issues found

- [ ] **Step 3: Commit**

```bash
git add mysic_flutter/lib/shared/utils/metadata_extractor.dart
git commit -m "feat(scanner): 添加 MetadataExtractor.extractArtwork() 方法"
```

---

### Task 2: 修改 WindowsMusicScanner 封面获取逻辑

**Files:**
- Modify: `lib/shared/utils/windows_music_scanner.dart`

- [ ] **Step 1: 添加封面保存方法**

在 `WindowsMusicScanner` 类中添加保存封面到私有目录的方法：

```dart
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';

// 在类中添加字段:
/// 封面缓存目录路径
String? _albumArtDirectory;

/// 获取或创建封面缓存目录
Future<String> _ensureAlbumArtDirectory() async {
  if (_albumArtDirectory != null) {
    return _albumArtDirectory!;
  }

  final appDir = await getApplicationDocumentsDirectory();
  final artDir = Directory('${appDir.path}/album_art');
  if (!await artDir.exists()) {
    await artDir.create(recursive: true);
  }
  _albumArtDirectory = artDir.path;
  return _albumArtDirectory!;
}

/// 保存封面到私有目录
///
/// [songId] 歌曲ID
/// [artworkBytes] 封面图片字节数据
/// 返回保存的文件路径
Future<String?> _saveArtworkToFile(int songId, Uint8List artworkBytes) async {
  try {
    if (artworkBytes.isEmpty) return null;

    final artDir = await _ensureAlbumArtDirectory();
    final filePath = '$artDir/$songId.jpg';
    final file = File(filePath);
    await file.writeAsBytes(artworkBytes);

    debugPrint('内嵌封面保存成功: $filePath (${artworkBytes.length} bytes)');
    return filePath;
  } catch (e) {
    debugPrint('保存封面失败: songId=$songId, error=$e');
    return null;
  }
}
```

- [ ] **Step 2: 修改 `_saveSongsToDatabase` 方法**

修改封面获取逻辑，优先使用内嵌封面。找到以下代码段（约第 575-621 行）：

```dart
for (final metadata in metadataList) {
  // ... 现有代码 ...
  
  songsToInsert.add({
    'title': title,
    'artist': metadata.artist,
    'album': metadata.album,
    'duration': metadata.duration ?? 0,
    'file_path': filePath,
    'album_art_path': metadata.albumArtPath,  // 这行需要修改
    'lyrics_path': metadata.lyricsPath,
    'date_added': null,
    'created_at': nowIso,
    'updated_at': nowIso,
  });
}
```

修改为：

```dart
for (final metadata in metadataList) {
  // ... 现有代码保持不变直到 songsToInsert ...

  // 封面路径：优先同名图片（已在 metadata.albumArtPath 中）
  // 内嵌封面将在事务后处理
  songsToInsert.add({
    'title': title,
    'artist': metadata.artist,
    'album': metadata.album,
    'duration': metadata.duration ?? 0,
    'file_path': filePath,
    'album_art_path': metadata.albumArtPath, // 同名图片路径（作为兜底）
    'lyrics_path': metadata.lyricsPath,
    'date_added': null,
    'created_at': nowIso,
    'updated_at': nowIso,
  });
}
```

- [ ] **Step 3: 添加内嵌封面提取逻辑**

在 `_saveSongsToDatabase` 方法的批量插入后、返回结果前，添加内嵌封面处理：

```dart
// 4. 批量插入
if (songsToInsert.isNotEmpty) {
  await db.transaction((txn) async {
    final batch = txn.batch();
    for (final songData in songsToInsert) {
      batch.insert(DatabaseHelper.tableSongs, songData);
    }
    final results = await batch.commit(noResult: false);
    newSongIds.addAll(results.cast<int>());
    newAdded = newSongIds.length;
  });
}

// 5. 提取内嵌封面并更新（优先于同名图片）
if (!isCancelled && newSongIds.isNotEmpty) {
  debugPrint('开始提取内嵌封面，共 ${newSongIds.length} 首');
  final artworkUpdates = <int, String>{};

  for (final songId in newSongIds) {
    if (isCancelled) break;

    // 获取歌曲文件路径
    final songData = songsToInsert.firstWhere(
      (data) => data['file_path'] != null,
      orElse: () => <String, dynamic>{},
    );
    final filePath = songData['file_path'] as String?;

    if (filePath == null) continue;

    // 提取内嵌封面
    final artworkBytes = await MetadataExtractor.extractArtwork(filePath);
    if (artworkBytes != null && artworkBytes.isNotEmpty) {
      final savedPath = await _saveArtworkToFile(songId, artworkBytes);
      if (savedPath != null) {
        artworkUpdates[songId] = savedPath;
      }
    }
  }

  // 批量更新封面路径
  if (artworkUpdates.isNotEmpty) {
    final updateBatch = db.batch();
    for (final entry in artworkUpdates.entries) {
      updateBatch.update(
        DatabaseHelper.tableSongs,
        {
          'album_art_path': entry.value,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [entry.key],
      );
    }
    await updateBatch.commit(noResult: true);
    debugPrint('内嵌封面更新完成: ${artworkUpdates.length} 首');
  }
}
```

- [ ] **Step 4: 验证代码编译通过**

Run: `cd mysic_flutter && flutter analyze lib/shared/utils/windows_music_scanner.dart`

Expected: No issues found

- [ ] **Step 5: Commit**

```bash
git add mysic_flutter/lib/shared/utils/windows_music_scanner.dart
git commit -m "feat(scanner): Windows 扫描器优先使用内嵌封面"
```

---

### Task 3: 修改 MobileMusicScanner 封面获取逻辑

**Files:**
- Modify: `lib/shared/utils/mobile_music_scanner.dart`

- [ ] **Step 1: 添加内嵌封面提取和保存方法**

在 `MobileMusicScanner` 类中添加：

```dart
/// 从音频文件提取内嵌封面并保存到私有目录
///
/// [songId] 歌曲ID
/// [filePath] 音频文件路径
/// 返回保存的封面路径，失败返回 null
Future<String?> _extractAndSaveEmbeddedArtwork(int songId, String filePath) async {
  try {
    final artworkBytes = await MetadataExtractor.extractArtwork(filePath);
    if (artworkBytes == null || artworkBytes.isEmpty) {
      return null;
    }

    final artDir = await _ensureAlbumArtDirectory();
    final targetPath = '$artDir/$songId.jpg';
    final file = File(targetPath);
    await file.writeAsBytes(artworkBytes);

    debugPrint('内嵌封面保存成功: $targetPath (${artworkBytes.length} bytes)');
    return targetPath;
  } catch (e) {
    debugPrint('提取内嵌封面失败: $filePath, error=$e');
    return null;
  }
}
```

- [ ] **Step 2: 修改 `_saveMediaSongsToDatabase` 方法**

修改封面获取优先级逻辑。找到以下代码段（约第 744-794 行）：

```dart
// 查找同名图片（优先于 MediaStore 封面）
String? sourceImagePath;
// ... 同名图片查找逻辑 ...
```

修改为：

```dart
// 封面获取优先级：
// 1. 内嵌封面（事务后提取）
// 2. 同名图片（事务后复制）
// 3. MediaStore 封面（事务后获取）

String? sourceImagePath;
final fileName = filePath.split(Platform.pathSeparator).last;
final nameWithoutExt = fileName.replaceAll(RegExp(r'\.[^.]+$'), '');
final dir = File(filePath).parent;

debugPrint('查找同名图片: 音频文件名=$fileName, 无扩展名=$nameWithoutExt, 目录=${dir.path}');

// 按优先级查找同名图片
for (final ext in ['.jpg', '.jpeg', '.png', '.webp', '.gif']) {
  final imageFileName = '$nameWithoutExt$ext'.toLowerCase();
  final imageFile = File('${dir.path}${Platform.pathSeparator}$imageFileName');
  debugPrint('检查图片: ${imageFile.path}, 存在=${await imageFile.exists()}');
  if (await imageFile.exists()) {
    sourceImagePath = imageFile.path;
    debugPrint('找到同名图片: $sourceImagePath');
    break;
  }
}
```

- [ ] **Step 3: 修改歌曲插入后的封面处理逻辑**

找到以下代码段（约第 786-794 行）：

```dart
// 如果有同名图片，记录需要复制（事务外执行）
// 同时保存 mediaId，以便复制失败时回退到 MediaStore
if (sourceImagePath != null) {
  // 将图片路径和 mediaId 暂存，事务外复制
  _pendingImageCopies[songId] = (sourceImagePath, mediaSong.id);
} else {
  // 没有同名图片，直接从 MediaStore 获取封面
  songMediaIdMap[songId] = mediaSong.id;
}
```

修改为：

```dart
// 记录封面信息，用于事务后处理
// 结构: (filePath, sourceImagePath, mediaId)
// filePath 用于提取内嵌封面
// sourceImagePath 用于同名图片兜底
// mediaId 用于 MediaStore 兜底
_pendingArtworkInfo[songId] = (filePath, sourceImagePath, mediaSong.id);
```

- [ ] **Step 4: 添加新的数据结构存储封面信息**

在 `MobileMusicScanner` 类中添加字段：

```dart
/// 待处理的封面信息（songId -> (filePath, sourceImagePath, mediaId)）
/// 用于按优先级处理：内嵌封面 > 同名图片 > MediaStore
final Map<int, (String, String?, int)> _pendingArtworkInfo = {};
```

并删除原有的 `_pendingImageCopies` 字段（或保留用于兼容）。

- [ ] **Step 5: 修改事务后的封面处理逻辑**

找到以下代码段（约第 808-827 行）：

```dart
// 4. 复制同名图片到私有目录（事务外执行）
if (!isCancelled && _pendingImageCopies.isNotEmpty) {
  // ...
}
```

修改为：

```dart
// 4. 按优先级处理封面：内嵌 > 同名图片 > MediaStore
if (!isCancelled && _pendingArtworkInfo.isNotEmpty) {
  debugPrint('开始处理封面，共 ${_pendingArtworkInfo.length} 首');
  final stillNeedMediaStore = <int, int>{}; // songId -> mediaId

  for (final entry in _pendingArtworkInfo.entries) {
    if (isCancelled) break;

    final songId = entry.key;
    final (filePath, sourceImagePath, mediaId) = entry.value;

    // 优先级 1: 内嵌封面
    String? savedPath = await _extractAndSaveEmbeddedArtwork(songId, filePath);

    // 优先级 2: 同名图片
    if (savedPath == null && sourceImagePath != null) {
      savedPath = await _copyImageToPrivateDir(songId, sourceImagePath, _currentSafTreeUri);
    }

    // 更新数据库
    if (savedPath != null) {
      await db.update(
        DatabaseHelper.tableSongs,
        {
          'album_art_path': savedPath,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [songId],
      );
      debugPrint('封面更新成功: songId=$songId, path=$savedPath');
    } else {
      // 优先级 3: MediaStore（稍后批量处理）
      stillNeedMediaStore[songId] = mediaId;
    }
  }

  _pendingArtworkInfo.clear();

  // 5. 批量从 MediaStore 获取封面
  if (!isCancelled && stillNeedMediaStore.isNotEmpty) {
    debugPrint('开始从 MediaStore 获取封面，共 ${stillNeedMediaStore.length} 首');
    await _fetchArtworksParallel(stillNeedMediaStore);
    debugPrint('MediaStore 封面获取完成');
  }
}
```

- [ ] **Step 6: 清理旧代码**

删除以下不再需要的代码：
- `_pendingImageCopies` 字段定义
- `_copyImagesParallel` 方法调用（保留方法本身，因为 `_copyImageToPrivateDir` 仍被使用）

- [ ] **Step 7: 验证代码编译通过**

Run: `cd mysic_flutter && flutter analyze lib/shared/utils/mobile_music_scanner.dart`

Expected: No issues found

- [ ] **Step 8: Commit**

```bash
git add mysic_flutter/lib/shared/utils/mobile_music_scanner.dart
git commit -m "feat(scanner): Android 扫描器优先使用内嵌封面"
```

---

### Task 4: 验证功能完整性

**Files:**
- Test: 手动测试

- [ ] **Step 1: 运行静态分析**

Run: `cd mysic_flutter && flutter analyze`

Expected: No issues found

- [ ] **Step 2: 运行现有测试**

Run: `cd mysic_flutter && flutter test`

Expected: All tests pass

- [ ] **Step 3: 手动测试**

1. 在 Windows 上运行应用：`flutter run -d windows`
2. 扫描包含内嵌封面的 MP3 文件
3. 验证封面正确显示
4. 扫描无内嵌封面但有同名图片的歌曲
5. 验证同名图片作为兜底

- [ ] **Step 4: 最终 Commit**

```bash
git add -A
git commit -m "feat(scanner): 专辑封面关联功能完成

- 新增 MetadataExtractor.extractArtwork() 提取内嵌封面
- Windows 扫描器优先级：内嵌封面 > 同名图片
- Android 扫描器优先级：内嵌封面 > 同名图片 > MediaStore"
```

---

## 测试要点

- [ ] MP3 文件内嵌封面提取
- [ ] FLAC 文件内嵌封面提取
- [ ] WAV 文件同名图片兜底
- [ ] 无封面歌曲的 MediaStore 回退（Android）
- [ ] 封面文件正确保存到私有目录
- [ ] 数据库 `album_art_path` 正确记录
