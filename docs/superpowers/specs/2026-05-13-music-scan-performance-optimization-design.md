# 音乐扫描性能优化设计文档

**日期**: 2026-05-13
**作者**: Claude
**状态**: 待审核

## 1. 问题分析

### 1.1 当前性能瓶颈

| 瓶颈点 | 平台 | 描述 | 影响 |
|--------|------|------|------|
| 元数据提取串行化 | Windows/Mobile | `_extractMetadata()` 对每个文件串行调用 `AudioTags.read()` | 500-2000 首歌曲耗时 30-120 秒 |
| 歌词文件查找低效 | Windows | `_findLyricsFile()` 每次扫描同目录，同一目录重复扫描 | 额外 10-30% 时间开销 |
| 数据库单条插入 | Windows/Mobile | 事务内逐条 `insert`，未使用 Batch | 5-10% 时间开销 |
| 封面获取串行化 | Mobile | `_fetchAndSaveArtwork()` 逐个获取封面 | 额外 20-40% 时间开销 |

### 1.2 目标

- 扫描 500-2000 歌曲，总耗时减少 50-70%
- 保持 UI 响应性，支持进度显示
- 不改变现有 API 接口

## 2. 优化方案

### 2.1 架构变更

```
优化后扫描流程：

阶段1：文件发现（串行，快速）
├── 递归扫描目录，收集音频文件路径
├── 同时构建歌词文件缓存（新增）
└── 输出：文件路径列表 + 歌词缓存

阶段2：元数据提取（并行化）
├── 分批并行处理（每批 N 个文件）
├── 使用 compute/Isolate 在后台提取
├── 从缓存查找歌词路径（替代实时扫描）
└── 输出：元数据列表 + 歌词路径列表

阶段3：数据库保存（批量操作）
├── 过滤已存在/已删除路径
├── 使用 Batch 批量插入
├── 移动端：并行获取封面（新增）
└── 输出：新增歌曲 ID 列表
```

### 2.2 核心优化点

#### 2.2.1 歌词文件缓存

**新增类**: `LyricsCache`

```dart
/// 歌词文件缓存
/// 在文件扫描阶段预先收集所有歌词文件，避免重复扫描目录
class LyricsCache {
  /// 目录路径 → 该目录下歌词文件名集合（不含扩展名）
  final Map<String, Set<String>> _directoryCache = {};

  /// 添加目录的歌词文件
  void addDirectory(String dirPath, Set<String> lrcNames) {
    _directoryCache[dirPath] = lrcNames;
  }

  /// 查找音频文件对应的歌词文件
  /// 返回完整路径，找不到返回 null
  String? findLyricsPath(String audioFilePath) {
    final dirPath = File(audioFilePath).parent.path;
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

  String _getFileNameWithoutExtension(String path) {
    final fileName = path.split(Platform.pathSeparator).last;
    return fileName.replaceAll(RegExp(r'\.[^.]+$'), '');
  }

  String _cleanFileName(String name) {
    // 移除序号前缀（如 "01 - "）
    return name.replaceFirst(RegExp(r'^\d+[\s.\-_]*'), '').toLowerCase();
  }
}
```

#### 2.2.2 并行元数据提取

**方法**: `_extractMetadataParallel`

```dart
/// 并行提取元数据
/// 使用 compute 在 Isolate 中执行，避免阻塞主线程
Future<List<_AudioMetadata>> _extractMetadataParallel(
  List<String> filePaths,
  LyricsCache lyricsCache,
  void Function(int processed, int total) onProgress,
) async {
  const batchSize = 50;
  final results = <_AudioMetadata>[];

  for (var i = 0; i < filePaths.length; i += batchSize) {
    final batch = filePaths.sublist(
      i,
      min(i + batchSize, filePaths.length),
    );

    // 并行处理当前批次
    final batchResults = await Future.wait(
      batch.map((path) => compute(_extractSingleMetadata, path)),
    );

    // 为每个结果添加歌词路径
    for (var j = 0; j < batchResults.length; j++) {
      final lyricsPath = lyricsCache.findLyricsPath(batch[j]);
      batchResults[j].lyricsPath = lyricsPath;
    }

    results.addAll(batchResults);
    onProgress(results.length, filePaths.length);
  }

  return results;
}

/// Isolate 入口函数：提取单个文件的元数据
_AudioMetadata _extractSingleMetadata(String filePath) {
  try {
    final tag = AudioTags.read(filePath);
    if (tag != null) {
      return _AudioMetadata(
        filePath: filePath,
        title: tag.title,
        artist: tag.trackArtist,
        album: tag.album,
        duration: tag.duration,
      );
    }
  } catch (e) {
    // 失败时使用文件名
  }

  final fileName = filePath.split(Platform.pathSeparator).last;
  return _AudioMetadata(
    filePath: filePath,
    title: _cleanTitleFromFileName(fileName),
    artist: null,
    album: null,
    duration: null,
  );
}
```

#### 2.2.3 批量数据库插入

**方法**: `_batchInsertSongs`

```dart
/// 批量插入歌曲到数据库
Future<List<int>> _batchInsertSongs(List<_SongInsertData> songs) async {
  final db = await _dbHelper.database;
  final insertedIds = <int>[];

  await db.transaction((txn) async {
    final batch = txn.batch();

    for (final song in songs) {
      batch.insert(
        DatabaseHelper.tableSongs,
        {
          'title': song.title,
          'artist': song.artist,
          'album': song.album,
          'duration': song.duration,
          'file_path': song.filePath,
          'lyrics_path': song.lyricsPath,
          'album_art_path': null,
          'created_at': song.createdAt,
          'updated_at': song.updatedAt,
        },
      );
    }

    final results = await batch.commit(noResult: false);
    insertedIds.addAll(results.cast<int>());
  });

  return insertedIds;
}
```

#### 2.2.4 移动端封面并行获取

**方法**: `_fetchArtworksParallel`

```dart
/// 并行获取封面
Future<void> _fetchArtworksParallel(
  Map<int, int> songMediaIdMap,
  Database db,
) async {
  const batchSize = 10;
  final entries = songMediaIdMap.entries.toList();

  for (var i = 0; i < entries.length; i += batchSize) {
    final batch = entries.sublist(i, min(i + batchSize, entries.length));

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
          {'album_art_path': result.artPath},
          where: 'id = ?',
          whereArgs: [result.songId],
        );
      }
    }
    await updateBatch.commit(noResult: true);
  }
}
```

### 2.3 配置参数

新增 `ScanOptions` 参数：

```dart
class ScanOptions {
  // 现有参数
  final List<String> audioFormats;
  final int minFileSizeKb;
  final bool autoDedupe;

  // 新增参数
  final int metadataBatchSize;      // 默认 50
  final int artworkBatchSize;       // 默认 10（移动端）
  final int progressUpdateInterval; // 默认 100

  const ScanOptions({
    this.audioFormats = const ['mp3', 'flac', 'wav', 'm4a', 'ogg', 'aac', 'wma', 'ape'],
    this.minFileSizeKb = 100,
    this.autoDedupe = true,
    this.metadataBatchSize = 50,
    this.artworkBatchSize = 10,
    this.progressUpdateInterval = 100,
  });
}
```

## 3. 文件变更清单

| 文件 | 变更类型 | 描述 |
|------|----------|------|
| `lib/shared/utils/lyrics_cache.dart` | 新增 | 歌词文件缓存类 |
| `lib/shared/utils/windows_music_scanner.dart` | 重构 | 实现并行元数据提取、批量插入 |
| `lib/shared/utils/mobile_music_scanner.dart` | 重构 | 实现并行元数据提取、并行封面获取 |
| `lib/shared/utils/platform_music_scanner.dart` | 修改 | 新增 ScanOptions 参数 |

## 4. 实现顺序

1. **创建 `LyricsCache` 类** - 独立模块，无依赖
2. **修改 `ScanOptions`** - 扩展配置参数
3. **重构 `WindowsMusicScanner`** - 核心优化
4. **重构 `MobileMusicScanner`** - 核心优化 + 封面并行
5. **测试验证** - 性能对比测试

## 5. 预期效果

| 场景 | 当前耗时 | 优化后耗时 | 提升 |
|------|----------|------------|------|
| 500 首歌曲（首次扫描） | ~30 秒 | ~10-15 秒 | 50-67% |
| 1000 首歌曲（首次扫描） | ~60 秒 | ~20-30 秒 | 50-67% |
| 2000 首歌曲（首次扫描） | ~120 秒 | ~40-60 秒 | 50-67% |
| 增量扫描（大部分已存在） | ~10 秒 | ~5-8 秒 | 20-50% |

## 6. 风险与缓解

| 风险 | 概率 | 缓解措施 |
|------|------|----------|
| Isolate 内存占用过高 | 中 | 批次大小可配置，默认 50 适中 |
| 并发 I/O 导致系统压力 | 低 | 批次处理，非全量并发 |
| 单文件失败影响批次 | 低 | 异常捕获，单文件失败不影响其他 |
| 进度更新过于频繁 | 低 | 可配置更新间隔 |

## 7. 测试计划

1. **单元测试**
   - `LyricsCache` 精确匹配和宽松匹配
   - 并行元数据提取的正确性
   - 批量插入的正确性

2. **性能测试**
   - 对比优化前后扫描耗时
   - 测试不同批次大小的效果
   - 测试内存占用

3. **集成测试**
   - 完整扫描流程验证
   - 取消扫描功能验证
   - 进度显示验证