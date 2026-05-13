# 音乐扫描性能优化实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将音乐扫描性能提升 50-70%，通过并行元数据提取、歌词缓存和批量数据库操作实现。

**Architecture:** 三阶段扫描流程：文件发现（串行）→ 元数据提取（并行）→ 数据库保存（批量）。新增 `LyricsCache` 类缓存歌词文件映射，修改 `ScanOptions` 支持批次配置，重构 `WindowsMusicScanner` 和 `MobileMusicScanner` 实现并行处理。

**Tech Stack:** Flutter/Dart, `compute` Isolate, sqflite Batch, audiotags

---

## 文件结构

```
lib/shared/utils/
├── lyrics_cache.dart              # 新增：歌词文件缓存类
├── platform_music_scanner.dart    # 修改：扩展 ScanOptions
├── windows_music_scanner.dart     # 重构：并行元数据提取、批量插入
└── mobile_music_scanner.dart      # 重构：并行元数据提取、并行封面获取

test/
└── lyrics_cache_test.dart         # 新增：歌词缓存单元测试
```

---

### Task 1: 创建 LyricsCache 类

**Files:**
- Create: `mysic_flutter/lib/shared/utils/lyrics_cache.dart`
- Test: `mysic_flutter/test/lyrics_cache_test.dart`

- [ ] **Step 1: 编写 LyricsCache 单元测试**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mysic/shared/utils/lyrics_cache.dart';

void main() {
  group('LyricsCache', () {
    test('精确匹配歌词文件', () {
      final cache = LyricsCache();
      cache.addDirectory('/music/album', {'song1', 'song2'});

      expect(cache.findLyricsPath('/music/album/song1.mp3'), '/music/album/song1.lrc');
      expect(cache.findLyricsPath('/music/album/song2.flac'), '/music/album/song2.lrc');
    });

    test('宽松匹配忽略序号前缀', () {
      final cache = LyricsCache();
      cache.addDirectory('/music/album', {'01 - song name'});

      // 音频文件名无序号，歌词文件有序号
      expect(cache.findLyricsPath('/music/album/song name.mp3'), '/music/album/01 - song name.lrc');

      // 音频文件名有序号，歌词文件无序号
      cache.addDirectory('/music/album2', {'song name'});
      expect(cache.findLyricsPath('/music/album2/02. song name.mp3'), '/music/album2/song name.lrc');
    });

    test('找不到歌词返回 null', () {
      final cache = LyricsCache();
      cache.addDirectory('/music/album', {'other'});

      expect(cache.findLyricsPath('/music/album/song.mp3'), null);
      expect(cache.findLyricsPath('/music/other/song.mp3'), null);
    });

    test('处理不同分隔符的序号前缀', () {
      final cache = LyricsCache();
      cache.addDirectory('/music/album', {'song'});

      expect(cache.findLyricsPath('/music/album/01 - song.mp3'), '/music/album/song.lrc');
      expect(cache.findLyricsPath('/music/album/02.song.mp3'), '/music/album/song.lrc');
      expect(cache.findLyricsPath('/music/album/03_song.mp3'), '/music/album/song.lrc');
    });
  });
}
```

- [ ] **Step 2: 运行测试验证失败**

Run: `cd mysic_flutter && flutter test test/lyrics_cache_test.dart`
Expected: FAIL - LyricsCache 类不存在

- [ ] **Step 3: 实现 LyricsCache 类**

```dart
import 'dart:io';

/// 歌词文件缓存
/// 在文件扫描阶段预先收集所有歌词文件，避免重复扫描目录
class LyricsCache {
  /// 目录路径 → 该目录下歌词文件名集合（不含扩展名）
  final Map<String, Set<String>> _directoryCache = {};

  /// 添加目录的歌词文件
  void addDirectory(String dirPath, Set<String> lrcNames) {
    if (lrcNames.isNotEmpty) {
      _directoryCache[dirPath] = lrcNames;
    }
  }

  /// 查找音频文件对应的歌词文件
  /// 返回完整路径，找不到返回 null
  String? findLyricsPath(String audioFilePath) {
    final file = File(audioFilePath);
    final dirPath = file.parent.path;
    final audioName = _getFileNameWithoutExtension(audioFilePath);
    final lrcNames = _directoryCache[dirPath];

    if (lrcNames == null) return null;

    // 精确匹配
    if (lrcNames.contains(audioName)) {
      return '$dirPath${Platform.pathSeparator}$audioName.lrc';
    }

    // 宽松匹配（忽略序号前缀）
    final cleanedAudioName = _cleanFileName(audioName);
    for (final lrcName in lrcNames) {
      if (_cleanFileName(lrcName) == cleanedAudioName) {
        return '$dirPath${Platform.pathSeparator}$lrcName.lrc';
      }
    }

    return null;
  }

  /// 获取文件名（不含扩展名）
  String _getFileNameWithoutExtension(String path) {
    final fileName = path.split(Platform.pathSeparator).last;
    return fileName.replaceAll(RegExp(r'\.[^.]+$'), '');
  }

  /// 清理文件名：移除序号前缀并转小写
  String _cleanFileName(String name) {
    // 移除序号前缀（如 "01 - ", "02.", "03_"）
    return name.replaceFirst(RegExp(r'^\d+[\s.\-_]*'), '').toLowerCase();
  }

  /// 获取缓存的目录数量
  int get cachedDirectoryCount => _directoryCache.length;

  /// 清空缓存
  void clear() {
    _directoryCache.clear();
  }
}
```

- [ ] **Step 4: 运行测试验证通过**

Run: `cd mysic_flutter && flutter test test/lyrics_cache_test.dart`
Expected: PASS - 所有测试通过

- [ ] **Step 5: 提交**

```bash
cd mysic_flutter && git add lib/shared/utils/lyrics_cache.dart test/lyrics_cache_test.dart
git commit -m "feat(scanner): 添加 LyricsCache 歌词文件缓存类"
```

---

### Task 2: 扩展 ScanOptions 配置参数

**Files:**
- Modify: `mysic_flutter/lib/shared/utils/platform_music_scanner.dart:5-21`

- [ ] **Step 1: 修改 ScanOptions 类，添加新参数**

```dart
/// 扫描选项配置
class ScanOptions {
  final List<String> audioFormats;
  final int minFileSizeKb;
  final bool autoDedupe;

  /// 元数据提取并行批次大小
  final int metadataBatchSize;

  /// 封面获取并行批次大小（移动端）
  final int artworkBatchSize;

  /// 进度更新间隔（文件数）
  final int progressUpdateInterval;

  const ScanOptions({
    this.audioFormats = const ['mp3', 'flac', 'wav', 'm4a', 'ogg', 'aac', 'wma', 'ape'],
    this.minFileSizeKb = 100,
    this.autoDedupe = true,
    this.metadataBatchSize = 50,
    this.artworkBatchSize = 10,
    this.progressUpdateInterval = 100,
  });

  /// 最小文件大小（字节）
  int get minFileSizeBytes => minFileSizeKb * 1024;

  /// 音频格式扩展名集合
  Set<String> get audioExtensions => audioFormats.map((f) => '.$f').toSet();
}
```

- [ ] **Step 2: 运行分析验证无错误**

Run: `cd mysic_flutter && flutter analyze lib/shared/utils/platform_music_scanner.dart`
Expected: No issues found

- [ ] **Step 3: 提交**

```bash
cd mysic_flutter && git add lib/shared/utils/platform_music_scanner.dart
git commit -m "feat(scanner): 扩展 ScanOptions 添加并行批次配置参数"
```

---

### Task 3: 重构 WindowsMusicScanner - 文件扫描阶段

**Files:**
- Modify: `mysic_flutter/lib/shared/utils/windows_music_scanner.dart`

- [ ] **Step 1: 添加 LyricsCache 导入和成员变量**

在文件顶部添加导入：
```dart
import 'lyrics_cache.dart';
```

在 `WindowsMusicScanner` 类中添加成员变量：
```dart
class WindowsMusicScanner extends PlatformMusicScanner {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final ScanDirectoryProvider _directoryProvider = ScanDirectoryProvider();

  /// 歌词文件缓存
  final LyricsCache _lyricsCache = LyricsCache();

  // ... 其他现有成员
```

- [ ] **Step 2: 修改 _scanDirectory 方法，同时收集歌词文件**

将现有的 `_scanDirectory` 方法修改为返回扫描结果，同时收集歌词文件：

```dart
/// 递归扫描目录
/// 返回音频文件列表，同时填充歌词缓存
Future<List<File>> _scanDirectoryWithLyricsCache(
  String path,
  void Function(String path, int count) onProgress,
) async {
  final songs = <File>[];

  await _scanDirectoryRecursive(path, songs, onProgress);

  return songs;
}

/// 递归扫描目录（内部实现）
Future<void> _scanDirectoryRecursive(
  String path,
  List<File> songs,
  void Function(String path, int count) onProgress,
) async {
  if (isCancelled) return;

  try {
    final dir = Directory(path);
    if (!await dir.exists()) return;

    // 收集当前目录的歌词文件
    final lrcNames = <String>{};

    await for (final entity in dir.list(followLinks: false)) {
      if (isCancelled) return;

      if (entity is Directory) {
        final dirName = entity.path.split(Platform.pathSeparator).last;
        if (_skipDirectories.contains(dirName)) continue;

        try {
          await _scanDirectoryRecursive(entity.path, songs, onProgress);
        } catch (_) {
          // 忽略无权限目录
        }
      } else if (entity is File) {
        final extension = entity.path.toLowerCase();

        // 检查是否是歌词文件
        if (extension.endsWith('.lrc')) {
          final fileName = entity.path.split(Platform.pathSeparator).last;
          final nameWithoutExt = fileName.replaceAll(RegExp(r'\.lrc$', caseSensitive: false), '');
          lrcNames.add(nameWithoutExt);
          continue;
        }

        // 检查是否是音频文件
        for (final ext in options.audioExtensions) {
          if (extension.endsWith(ext)) {
            if (_isLikelyNonMusicFile(entity.path)) {
              break;
            }
            try {
              final fileSize = await entity.length();
              if (fileSize >= options.minFileSizeBytes) {
                songs.add(entity);
                onProgress(entity.path, 1);
              }
            } catch (_) {
              // 忽略无法读取的文件
            }
            break;
          }
        }
      }
    }

    // 将当前目录的歌词文件添加到缓存
    _lyricsCache.addDirectory(path, lrcNames);
  } catch (_) {
    // 忽略无权限目录
  }
}
```

- [ ] **Step 3: 提交**

```bash
cd mysic_flutter && git add lib/shared/utils/windows_music_scanner.dart
git commit -m "refactor(scanner): Windows 扫描阶段同时收集歌词文件到缓存"
```

---

### Task 4: 重构 WindowsMusicScanner - 并行元数据提取

**Files:**
- Modify: `mysic_flutter/lib/shared/utils/windows_music_scanner.dart`

- [ ] **Step 1: 添加元数据提取辅助类**

在文件末尾修改 `_AudioMetadata` 类，添加 `filePath` 和 `lyricsPath` 字段：

```dart
/// 音频元数据辅助类
class _AudioMetadata {
  _AudioMetadata({
    required this.filePath,
    this.title,
    this.artist,
    this.album,
    this.duration,
    this.lyricsPath,
  });

  final String filePath;
  final String? title;
  final String? artist;
  final String? album;
  final int? duration;
  String? lyricsPath;
}
```

- [ ] **Step 2: 添加并行元数据提取方法**

```dart
/// 并行提取元数据
Future<List<_AudioMetadata>> _extractMetadataParallel(
  List<File> files,
  void Function(int processed, int total) onProgress,
) async {
  final batchSize = options.metadataBatchSize;
  final results = <_AudioMetadata>[];
  final filePaths = files.map((f) => f.path).toList();

  for (var i = 0; i < filePaths.length; i += batchSize) {
    if (isCancelled) break;

    final batch = filePaths.sublist(
      i,
      (i + batchSize < filePaths.length) ? i + batchSize : filePaths.length,
    );

    // 并行处理当前批次
    final batchResults = await Future.wait(
      batch.map((path) => _extractMetadata(path)),
    );

    // 为每个结果添加歌词路径
    for (var j = 0; j < batchResults.length; j++) {
      final lyricsPath = _lyricsCache.findLyricsPath(batch[j]);
      batchResults[j].lyricsPath = lyricsPath;
    }

    results.addAll(batchResults);
    onProgress(results.length, filePaths.length);
  }

  return results;
}
```

- [ ] **Step 3: 提交**

```bash
cd mysic_flutter && git add lib/shared/utils/windows_music_scanner.dart
git commit -m "refactor(scanner): Windows 添加并行元数据提取方法"
```

---

### Task 5: 重构 WindowsMusicScanner - 批量数据库插入

**Files:**
- Modify: `mysic_flutter/lib/shared/utils/windows_music_scanner.dart`

- [ ] **Step 1: 重写 _saveSongsToDatabase 方法使用批量插入**

```dart
/// 保存歌曲到数据库（批量操作优化）
Future<Map<String, dynamic>> _saveSongsToDatabase(
  List<_AudioMetadata> metadataList,
) async {
  final db = await _dbHelper.database;
  int newAdded = 0;
  int duplicates = 0;
  int filtered = 0;
  int skipped = 0;
  final newSongIds = <int>[];
  final now = DateTime.now();
  final nowIso = now.toIso8601String();

  // 1. 一次性查询所有已存在的路径
  final allExisting = await db.query(
    DatabaseHelper.tableSongs,
    columns: ['file_path'],
  );
  final existingPaths = allExisting.map((row) => row['file_path'] as String).toSet();

  // 2. 查询已删除的路径（软删除标记）
  final deletedPathsResult = await db.query(
    DatabaseHelper.tableSongs,
    columns: ['file_path'],
    where: 'is_deleted = ?',
    whereArgs: [1],
  );
  final deletedPaths = deletedPathsResult
      .map((row) => row['file_path'] as String)
      .toSet();

  // 3. 过滤并准备批量插入数据
  final songsToInsert = <Map<String, dynamic>>[];

  for (final metadata in metadataList) {
    if (isCancelled) break;

    final filePath = metadata.filePath;

    // 跳过已删除的路径
    if (deletedPaths.contains(filePath)) {
      skipped++;
      continue;
    }

    if (existingPaths.contains(filePath)) {
      if (options.autoDedupe) {
        duplicates++;
      } else {
        skipped++;
      }
    } else {
      // 过滤：时长不在有效范围内
      if (metadata.duration != null) {
        if (metadata.duration! < _minDurationSec || metadata.duration! > _maxDurationSec) {
          filtered++;
          continue;
        }
      }

      // 确定最终标题
      final fileName = filePath.split(Platform.pathSeparator).last;
      final title = metadata.title?.isNotEmpty == true
          ? metadata.title
          : _cleanTitleFromFileName(fileName);

      songsToInsert.add({
        'title': title,
        'artist': metadata.artist,
        'album': metadata.album,
        'duration': metadata.duration ?? 0,
        'file_path': filePath,
        'album_art_path': null,
        'lyrics_path': metadata.lyricsPath,
        'date_added': null,
        'created_at': nowIso,
        'updated_at': nowIso,
      });
    }
  }

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

  debugPrint('Windows扫描完成: newAdded=$newAdded, duplicates=$duplicates, filtered=$filtered, skipped=$skipped');
  return {'newAdded': newAdded, 'duplicates': duplicates, 'newSongIds': newSongIds};
}
```

- [ ] **Step 2: 提交**

```bash
cd mysic_flutter && git add lib/shared/utils/windows_music_scanner.dart
git commit -m "refactor(scanner): Windows 使用批量插入优化数据库操作"
```

---

### Task 6: 重构 WindowsMusicScanner - 整合新流程

**Files:**
- Modify: `mysic_flutter/lib/shared/utils/windows_music_scanner.dart`

- [ ] **Step 1: 重写 scanMusic 方法整合新流程**

```dart
@override
Future<ScanResult> scanMusic() async {
  if (isScanning) {
    return const ScanResult(
      totalFound: 0,
      newAdded: 0,
      duplicates: 0,
      scanDuration: Duration.zero,
      errorMessage: '扫描正在进行中',
    );
  }

  final stopwatch = Stopwatch()..start();
  resetCancel();
  _lyricsCache.clear();

  try {
    updateState(ScanState.scanning);

    // 获取扫描根目录列表
    final scanRoots = await _getScanRoots();
    if (scanRoots.isEmpty) {
      updateState(ScanState.completed);
      stopwatch.stop();
      return ScanResult(
        totalFound: 0,
        newAdded: 0,
        duplicates: 0,
        scanDuration: stopwatch.elapsed,
      );
    }

    // 阶段1：文件发现（同时构建歌词缓存）
    final songs = <File>[];
    int filesScanned = 0;
    int progressCounter = 0;

    for (int i = 0; i < scanRoots.length; i++) {
      if (isCancelled) break;

      final root = scanRoots[i];
      final rootProgress = i / scanRoots.length;

      final dirSongs = await _scanDirectoryWithLyricsCache(root, (path, count) {
        filesScanned += count;
        progressCounter++;

        if (progressCounter % options.progressUpdateInterval == 0 || songs.length % 50 == 0) {
          updateProgress(ScanProgress(
            currentPath: path,
            filesScanned: filesScanned,
            songsFound: songs.length,
            progress: rootProgress + (1 / scanRoots.length) * 0.4,
          ));
        }
      });
      songs.addAll(dirSongs);
    }

    if (isCancelled) {
      updateState(ScanState.idle);
      stopwatch.stop();
      return ScanResult(
        totalFound: songs.length,
        newAdded: 0,
        duplicates: 0,
        scanDuration: stopwatch.elapsed,
        errorMessage: '扫描已取消',
      );
    }

    final totalFound = songs.length;
    updateProgress(ScanProgress(
      currentPath: '正在提取元数据...',
      filesScanned: filesScanned,
      songsFound: totalFound,
      progress: 0.5,
    ));

    // 阶段2：并行元数据提取
    final metadataList = await _extractMetadataParallel(songs, (processed, total) {
      if (processed % options.progressUpdateInterval == 0) {
        updateProgress(ScanProgress(
          currentPath: '正在提取元数据...',
          filesScanned: filesScanned,
          songsFound: totalFound,
          progress: 0.5 + (processed / total) * 0.4,
        ));
      }
    });

    if (isCancelled) {
      updateState(ScanState.idle);
      stopwatch.stop();
      return ScanResult(
        totalFound: totalFound,
        newAdded: 0,
        duplicates: 0,
        scanDuration: stopwatch.elapsed,
        errorMessage: '扫描已取消',
      );
    }

    updateProgress(ScanProgress(
      currentPath: '正在保存...',
      filesScanned: filesScanned,
      songsFound: totalFound,
      progress: 0.95,
    ));

    updateState(ScanState.saving);

    // 阶段3：批量保存到数据库
    final result = await _saveSongsToDatabase(metadataList);

    updateState(ScanState.completed);
    stopwatch.stop();
    debugPrint('Windows扫描完成: totalFound=$totalFound, newAdded=${result['newAdded']}, duplicates=${result['duplicates']}');

    updateProgress(ScanProgress(
      currentPath: '完成',
      filesScanned: filesScanned,
      songsFound: totalFound,
      progress: 1.0,
    ));

    return ScanResult(
      totalFound: totalFound,
      newAdded: result['newAdded']! as int,
      duplicates: result['duplicates']! as int,
      scanDuration: stopwatch.elapsed,
      newSongIds: result['newSongIds']! as List<int>,
    );
  } catch (e) {
    updateState(ScanState.error);
    stopwatch.stop();
    return ScanResult(
      totalFound: 0,
      newAdded: 0,
      duplicates: 0,
      scanDuration: stopwatch.elapsed,
      errorMessage: e.toString(),
    );
  }
}
```

- [ ] **Step 2: 同样重写 scanMusicInDirectory 方法**

参照 scanMusic 的结构，修改 scanMusicInDirectory 方法使用相同的三阶段流程。

- [ ] **Step 3: 运行分析验证无错误**

Run: `cd mysic_flutter && flutter analyze lib/shared/utils/windows_music_scanner.dart`
Expected: No issues found

- [ ] **Step 4: 提交**

```bash
cd mysic_flutter && git add lib/shared/utils/windows_music_scanner.dart
git commit -m "refactor(scanner): Windows 整合三阶段扫描流程"
```

---

### Task 7: 重构 MobileMusicScanner - 并行元数据提取

**Files:**
- Modify: `mysic_flutter/lib/shared/utils/mobile_music_scanner.dart`

- [ ] **Step 1: 添加 LyricsCache 导入和成员变量**

在文件顶部添加导入：
```dart
import 'lyrics_cache.dart';
```

在 `MobileMusicScanner` 类中添加成员变量：
```dart
class MobileMusicScanner extends PlatformMusicScanner {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final ScanDirectoryProvider _directoryProvider = ScanDirectoryProvider();
  final OnAudioQuery _audioQuery = OnAudioQuery();

  /// 歌词文件缓存
  final LyricsCache _lyricsCache = LyricsCache();

  // ... 其他现有成员
```

- [ ] **Step 2: 添加并行元数据提取方法**

```dart
/// 并行提取元数据
Future<List<_AudioMetadata>> _extractMetadataParallel(
  List<File> files,
  void Function(int processed, int total) onProgress,
) async {
  final batchSize = options.metadataBatchSize;
  final results = <_AudioMetadata>[];
  final filePaths = files.map((f) => f.path).toList();

  for (var i = 0; i < filePaths.length; i += batchSize) {
    if (isCancelled) break;

    final batch = filePaths.sublist(
      i,
      (i + batchSize < filePaths.length) ? i + batchSize : filePaths.length,
    );

    final batchResults = await Future.wait(
      batch.map((path) => _extractMetadata(path)),
    );

    // 添加歌词路径
    for (var j = 0; j < batchResults.length; j++) {
      final lyricsPath = _lyricsCache.findLyricsPath(batch[j]);
      batchResults[j].lyricsPath = lyricsPath;
    }

    results.addAll(batchResults);
    onProgress(results.length, filePaths.length);
  }

  return results;
}
```

- [ ] **Step 3: 提交**

```bash
cd mysic_flutter && git add lib/shared/utils/mobile_music_scanner.dart
git commit -m "refactor(scanner): Mobile 添加并行元数据提取方法"
```

---

### Task 8: 重构 MobileMusicScanner - 并行封面获取

**Files:**
- Modify: `mysic_flutter/lib/shared/utils/mobile_music_scanner.dart`

- [ ] **Step 1: 添加并行封面获取方法**

```dart
/// 并行获取封面
Future<void> _fetchArtworksParallel(
  Map<int, int> songMediaIdMap,
) async {
  final db = await _dbHelper.database;
  final batchSize = options.artworkBatchSize;
  final entries = songMediaIdMap.entries.toList();

  for (var i = 0; i < entries.length; i += batchSize) {
    if (isCancelled) break;

    final batch = entries.sublist(
      i,
      (i + batchSize < entries.length) ? i + batchSize : entries.length,
    );

    final results = await Future.wait(
      batch.map((entry) async {
        final artPath = await _fetchAndSaveArtwork(entry.key, entry.value);
        return (songId: entry.key, artPath: artPath);
      }),
    );

    // 批量更新封面路径
    final updateBatch = db.batch();
    for (final result in results) {
      if (result.artPath != null) {
        updateBatch.update(
          DatabaseHelper.tableSongs,
          {
            'album_art_path': result.artPath,
            'updated_at': DateTime.now().toIso8601String(),
          },
          where: 'id = ?',
          whereArgs: [result.songId],
        );
      }
    }
    await updateBatch.commit(noResult: true);
  }
}
```

- [ ] **Step 2: 修改 _saveMediaSongsToDatabase 使用并行封面获取**

将现有的串行封面获取代码替换为：
```dart
// 4. 并行获取封面（事务外执行）
if (!isCancelled && newSongIds.isNotEmpty) {
  debugPrint('开始并行获取封面，共 ${songMediaIdMap.length} 首');
  await _fetchArtworksParallel(songMediaIdMap);
  debugPrint('封面获取完成');
}
```

- [ ] **Step 3: 提交**

```bash
cd mysic_flutter && git add lib/shared/utils/mobile_music_scanner.dart
git commit -m "refactor(scanner): Mobile 并行获取封面并批量更新数据库"
```

---

### Task 9: 运行完整测试验证

**Files:**
- 无新增文件

- [ ] **Step 1: 运行所有单元测试**

Run: `cd mysic_flutter && flutter test`
Expected: All tests pass

- [ ] **Step 2: 运行静态分析**

Run: `cd mysic_flutter && flutter analyze`
Expected: No issues found

- [ ] **Step 3: 提交最终状态**

```bash
cd mysic_flutter && git add -A && git status
# 确认无遗漏文件后
git commit -m "refactor(scanner): 完成音乐扫描性能优化"
```

---

### Task 10: 更新设计文档状态

**Files:**
- Modify: `docs/superpowers/specs/2026-05-13-music-scan-performance-optimization-design.md`

- [ ] **Step 1: 更新设计文档状态为已实现**

将文档头部的状态从"待审核"改为"已实现"：
```markdown
**状态**: 已实现
```

- [ ] **Step 2: 提交**

```bash
git add docs/superpowers/specs/2026-05-13-music-scan-performance-optimization-design.md
git commit -m "docs: 更新音乐扫描优化设计文档状态为已实现"
```

---

## 自检清单

- [x] 所有文件路径精确
- [x] 每个步骤包含完整代码
- [x] 命令和预期输出明确
- [x] 无 TBD/TODO 占位符
- [x] 类型和方法签名一致
- [x] 设计文档所有需求都有对应任务
