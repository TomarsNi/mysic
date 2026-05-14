# 同名图片文件封面获取策略实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 扫描音频文件时，在同级目录查找同名图片文件，将路径存入 `albumArtPath` 字段，作为封面显示的优先来源。

**Architecture:** 新增 `ImageCache` 类缓存扫描过程中发现的图片文件，在元数据提取阶段查找匹配的封面路径，保存到数据库。参考现有 `LyricsCache` 的实现模式。

**Tech Stack:** Dart, Flutter, SQLite

---

## 文件结构

```
lib/shared/utils/
├── image_cache.dart          [新增] 图片文件缓存类
├── windows_music_scanner.dart [修改] 集成 ImageCache
├── mobile_music_scanner.dart  [修改] 集成 ImageCache
└── lyrics_cache.dart          [参考] 现有歌词缓存实现

test/
└── image_cache_test.dart      [新增] ImageCache 单元测试
```

---

### Task 1: 创建 ImageCache 类

**Files:**
- Create: `lib/shared/utils/image_cache.dart`
- Test: `test/image_cache_test.dart`

- [ ] **Step 1: 创建 ImageCache 类文件**

```dart
/// 图片文件缓存
/// 在文件扫描阶段预先收集所有图片文件，支持按音频文件名查找同名图片
class ImageCache {
  /// 支持的图片格式（按优先级排序）
  static const _extensions = ['.jpg', '.jpeg', '.png', '.webp', '.gif'];

  /// 目录路径 → {小写文件名（含扩展名） → 图片完整路径}
  final Map<String, Map<String, String>> _cache = {};

  /// 添加目录下的图片到缓存
  void addDirectory(String directory, Map<String, String> images) {
    if (images.isNotEmpty) {
      _cache[directory] = images;
    }
  }

  /// 查找音频文件对应的图片路径
  /// 返回优先级最高的匹配图片路径，无匹配返回 null
  String? findImagePath(String audioFilePath) {
    if (audioFilePath.isEmpty) return null;

    final dirPath = _getParentDirectory(audioFilePath);
    final audioName = _getFileNameWithoutExtension(audioFilePath);
    final images = _cache[dirPath];

    if (images == null) return null;

    // 按优先级查找同名图片
    for (final ext in _extensions) {
      final key = '$audioName$ext'.toLowerCase();
      if (images.containsKey(key)) {
        return images[key];
      }
    }

    return null;
  }

  /// 获取父目录路径（跨平台兼容）
  String _getParentDirectory(String path) {
    final parts = path.replaceAll('\\', '/').split('/');
    if (parts.length <= 1) return '';
    return parts.sublist(0, parts.length - 1).join('/');
  }

  /// 获取文件名（不含扩展名）
  String _getFileNameWithoutExtension(String path) {
    final fileName = path.replaceAll('\\', '/').split('/').last;
    return fileName.replaceAll(RegExp(r'\.[^.]+$'), '');
  }

  /// 获取缓存的目录数量
  int get cachedDirectoryCount => _cache.length;

  /// 清空缓存
  void clear() {
    _cache.clear();
  }
}
```

- [ ] **Step 2: 创建 ImageCache 单元测试文件**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mysic/shared/utils/image_cache.dart';

void main() {
  group('ImageCache', () {
    late ImageCache cache;

    setUp(() {
      cache = ImageCache();
    });

    test('同名 jpg 图片被正确匹配', () {
      cache.addDirectory('/music', {
        'song.jpg': '/music/song.jpg',
      });

      final result = cache.findImagePath('/music/song.mp3');
      expect(result, '/music/song.jpg');
    });

    test('多格式共存时按优先级选择 (jpg > png > webp > gif)', () {
      cache.addDirectory('/music', {
        'song.png': '/music/song.png',
        'song.gif': '/music/song.gif',
      });

      // png > gif
      var result = cache.findImagePath('/music/song.mp3');
      expect(result, '/music/song.png');

      // 添加 jpg 后，jpg 优先
      cache.addDirectory('/music', {
        'song.jpg': '/music/song.jpg',
        'song.png': '/music/song.png',
        'song.gif': '/music/song.gif',
      });

      result = cache.findImagePath('/music/song.mp3');
      expect(result, '/music/song.jpg');
    });

    test('无同名图片时返回 null', () {
      cache.addDirectory('/music', {
        'other.jpg': '/music/other.jpg',
      });

      final result = cache.findImagePath('/music/song.mp3');
      expect(result, isNull);
    });

    test('不同目录同名文件不混淆', () {
      cache.addDirectory('/music/album1', {
        'song.jpg': '/music/album1/song.jpg',
      });
      cache.addDirectory('/music/album2', {
        'song.jpg': '/music/album2/song.jpg',
      });

      expect(
        cache.findImagePath('/music/album1/song.mp3'),
        '/music/album1/song.jpg',
      );
      expect(
        cache.findImagePath('/music/album2/song.mp3'),
        '/music/album2/song.jpg',
      );
    });

    test('文件名大小写不敏感', () {
      cache.addDirectory('/music', {
        'song.jpg': '/music/Song.JPG',
      });

      final result = cache.findImagePath('/music/SONG.mp3');
      expect(result, '/music/Song.JPG');
    });

    test('clear 清空缓存', () {
      cache.addDirectory('/music', {
        'song.jpg': '/music/song.jpg',
      });

      expect(cache.cachedDirectoryCount, 1);
      cache.clear();
      expect(cache.cachedDirectoryCount, 0);
      expect(cache.findImagePath('/music/song.mp3'), isNull);
    });

    test('空路径返回 null', () {
      cache.addDirectory('/music', {
        'song.jpg': '/music/song.jpg',
      });

      expect(cache.findImagePath(''), isNull);
    });

    test('Windows 路径分隔符兼容', () {
      cache.addDirectory('C:/music', {
        'song.jpg': 'C:/music/song.jpg',
      });

      // 使用反斜杠的路径也能匹配
      final result = cache.findImagePath('C:\\music\\song.mp3');
      expect(result, 'C:/music/song.jpg');
    });
  });
}
```

- [ ] **Step 3: 运行测试验证通过**

Run: `cd mysic_flutter && flutter test test/image_cache_test.dart`
Expected: All tests pass

- [ ] **Step 4: 提交**

```bash
git add lib/shared/utils/image_cache.dart test/image_cache_test.dart
git commit -m "feat(scanner): 新增 ImageCache 图片文件缓存类

- 支持按音频文件名查找同名图片
- 格式优先级: jpg > jpeg > png > webp > gif
- 跨平台路径兼容

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

### Task 2: 修改 WindowsMusicScanner 集成 ImageCache

**Files:**
- Modify: `lib/shared/utils/windows_music_scanner.dart`

- [ ] **Step 1: 添加 ImageCache 导入和成员变量**

在文件顶部导入区域添加：

```dart
import 'image_cache.dart';
```

在 `WindowsMusicScanner` 类中添加成员变量（约第 18 行，`_lyricsCache` 后面）：

```dart
/// 图片文件缓存
final ImageCache _imageCache = ImageCache();
```

- [ ] **Step 2: 添加图片文件检测辅助方法**

在 `_isLikelyNonMusicFile` 方法后添加：

```dart
/// 检查是否是图片文件
bool _isImageFile(String extension) {
  const imageExts = ['.jpg', '.jpeg', '.png', '.webp', '.gif'];
  return imageExts.any((ext) => extension.endsWith(ext));
}
```

- [ ] **Step 3: 修改 _scanDirectoryRecursive 收集图片文件**

找到 `_scanDirectoryRecursive` 方法中收集歌词文件的代码块（约第 386-412 行），修改为：

```dart
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
    // 收集当前目录的图片文件
    final imageFiles = <String, String>{};

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
          final nameWithoutExt = fileName.replaceAll(
            RegExp(r'\.lrc$', caseSensitive: false),
            '',
          );
          lrcNames.add(nameWithoutExt);
          continue;
        }

        // 检查是否是图片文件
        if (_isImageFile(extension)) {
          final fileName = entity.path.split(Platform.pathSeparator).last;
          imageFiles[fileName.toLowerCase()] = entity.path;
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
    // 将当前目录的图片文件添加到缓存
    _imageCache.addDirectory(path, imageFiles);
  } catch (_) {
    // 忽略无权限目录
  }
}
```

- [ ] **Step 4: 修改 _AudioMetadata 类添加 albumArtPath 字段**

找到 `_AudioMetadata` 类（约第 668-684 行），添加 `albumArtPath` 字段：

```dart
/// 音频元数据辅助类
class _AudioMetadata {
  _AudioMetadata({
    required this.filePath,
    this.title,
    this.artist,
    this.album,
    this.duration,
  });

  final String filePath;
  final String? title;
  final String? artist;
  final String? album;
  final int? duration;
  String? lyricsPath;
  String? albumArtPath;  // 新增
}
```

- [ ] **Step 5: 修改 _extractMetadataParallel 查找封面路径**

找到 `_extractMetadataParallel` 方法中添加歌词路径的代码块（约第 503-506 行），修改为：

```dart
// 为每个结果添加歌词路径和封面路径
for (var j = 0; j < batchResults.length; j++) {
  final lyricsPath = _lyricsCache.findLyricsPath(batch[j]);
  batchResults[j].lyricsPath = lyricsPath;

  // 查找封面路径
  final albumArtPath = _imageCache.findImagePath(batch[j]);
  batchResults[j].albumArtPath = albumArtPath;
}
```

- [ ] **Step 6: 修改 _saveSongsToDatabase 保存封面路径**

找到 `_saveSongsToDatabase` 方法中 `songsToInsert.add` 的代码块（约第 583-594 行），修改为：

```dart
songsToInsert.add({
  'title': title,
  'artist': metadata.artist,
  'album': metadata.album,
  'duration': metadata.duration ?? 0,
  'file_path': filePath,
  'album_art_path': metadata.albumArtPath,  // 新增
  'lyrics_path': metadata.lyricsPath,
  'date_added': null,
  'created_at': nowIso,
  'updated_at': nowIso,
});
```

- [ ] **Step 7: 修改 _executeScan 清理图片缓存**

找到 `_executeScan` 方法开头清理歌词缓存的代码（约第 174 行），修改为：

```dart
final stopwatch = Stopwatch()..start();
_lyricsCache.clear();
_imageCache.clear();  // 新增
```

- [ ] **Step 8: 运行测试验证**

Run: `cd mysic_flutter && flutter test test/windows_scanner_directory_test.dart`
Expected: All tests pass

- [ ] **Step 9: 提交**

```bash
git add lib/shared/utils/windows_music_scanner.dart
git commit -m "feat(scanner): WindowsMusicScanner 集成 ImageCache

- 扫描时收集同名图片文件
- 元数据提取时查找封面路径
- 保存 album_art_path 到数据库

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

### Task 3: 修改 MobileMusicScanner 集成 ImageCache

**Files:**
- Modify: `lib/shared/utils/mobile_music_scanner.dart`

- [ ] **Step 1: 添加 ImageCache 导入和成员变量**

在文件顶部导入区域添加：

```dart
import 'image_cache.dart';
```

在 `MobileMusicScanner` 类中添加成员变量（约第 20 行，`_lyricsCache` 后面）：

```dart
/// 图片文件缓存
final ImageCache _imageCache = ImageCache();
```

- [ ] **Step 2: 添加图片文件检测辅助方法**

在 `_isLikelyNonMusicFile` 方法后添加：

```dart
/// 检查是否是图片文件
bool _isImageFile(String extension) {
  const imageExts = ['.jpg', '.jpeg', '.png', '.webp', '.gif'];
  return imageExts.any((ext) => extension.endsWith(ext));
}
```

- [ ] **Step 3: 修改 _scanDirectory 收集图片文件**

找到 `_scanDirectory` 方法中收集歌词文件的代码块（约第 738-804 行），修改为：

```dart
/// 递归扫描目录（同时构建歌词缓存和图片缓存）
Future<void> _scanDirectory(
  String path,
  List<File> songs,
  void Function(String path, int count) onProgress,
) async {
  if (isCancelled) return;

  try {
    final dir = Directory(path);
    if (!await dir.exists()) {
      debugPrint('目录不存在: $path');
      return;
    }

    // 收集当前目录的歌词文件
    final lrcNames = <String>{};
    // 收集当前目录的图片文件
    final imageFiles = <String, String>{};
    int entityCount = 0;
    int dirCount = 0;
    int fileCount = 0;

    await for (final entity in dir.list(followLinks: false)) {
      if (isCancelled) return;

      entityCount++;

      if (entity is Directory) {
        dirCount++;
        final dirName = entity.path.split(Platform.pathSeparator).last;
        if (_skipDirectories.contains(dirName)) {
          debugPrint('跳过目录: $dirName');
          continue;
        }

        try {
          await _scanDirectory(entity.path, songs, onProgress);
        } catch (e) {
          debugPrint('无法访问目录 ${entity.path}: $e');
        }
      } else if (entity is File) {
        fileCount++;
        final extension = entity.path.toLowerCase();

        // 检查是否是歌词文件
        if (extension.endsWith('.lrc')) {
          final fileName = entity.path.split(Platform.pathSeparator).last;
          final nameWithoutExt = fileName.replaceAll(
            RegExp(r'\.lrc$', caseSensitive: false),
            '',
          );
          lrcNames.add(nameWithoutExt);
          continue;
        }

        // 检查是否是图片文件
        if (_isImageFile(extension)) {
          final fileName = entity.path.split(Platform.pathSeparator).last;
          imageFiles[fileName.toLowerCase()] = entity.path;
          continue;
        }

        // 检查是否是音频文件
        for (final ext in options.audioExtensions) {
          if (extension.endsWith(ext)) {
            // 检查文件名是否像非音乐文件
            if (_isLikelyNonMusicFile(entity.path)) {
              debugPrint('跳过非音乐文件: ${entity.path}');
              break;
            }
            // 检查文件大小
            try {
              final fileSize = await entity.length();
              if (fileSize >= options.minFileSizeBytes) {
                songs.add(entity);
                onProgress(entity.path, 1);
              } else {
                debugPrint('文件太小，跳过: ${entity.path} ($fileSize bytes)');
              }
            } catch (e) {
              debugPrint('无法读取文件 ${entity.path}: $e');
            }
            break;
          }
        }
      }
    }

    // 将当前目录的歌词文件添加到缓存
    _lyricsCache.addDirectory(path, lrcNames);
    // 将当前目录的图片文件添加到缓存
    _imageCache.addDirectory(path, imageFiles);

    debugPrint('目录 $path: 共 $entityCount 个实体, $dirCount 个目录, $fileCount 个文件, 找到 ${songs.length} 首歌曲');
  } catch (e) {
    debugPrint('扫描目录失败 $path: $e');
  }
}
```

- [ ] **Step 4: 修改 _AudioMetadata 类添加 albumArtPath 字段**

找到 `_AudioMetadata` 类（约第 1045-1061 行），添加 `albumArtPath` 字段：

```dart
/// 音频元数据辅助类
class _AudioMetadata {
  _AudioMetadata({
    required this.filePath,
    this.title,
    this.artist,
    this.album,
    this.duration,
  });

  final String filePath;
  final String? title;
  final String? artist;
  final String? album;
  final int? duration;
  String? lyricsPath;
  String? albumArtPath;  // 新增
}
```

- [ ] **Step 5: 修改 _extractMetadataParallel 查找封面路径**

找到 `_extractMetadataParallel` 方法中添加歌词路径的代码块（约第 879-883 行），修改为：

```dart
// 添加歌词路径和封面路径
for (var j = 0; j < batchResults.length; j++) {
  final lyricsPath = _lyricsCache.findLyricsPath(batch[j]);
  batchResults[j].lyricsPath = lyricsPath;

  // 查找封面路径
  final albumArtPath = _imageCache.findImagePath(batch[j]);
  batchResults[j].albumArtPath = albumArtPath;
}
```

- [ ] **Step 6: 修改 _saveSongsToDatabase 保存封面路径**

找到 `_saveSongsToDatabase` 方法中 `songsToInsert.add` 的代码块（约第 961-972 行），修改为：

```dart
songsToInsert.add({
  'title': title,
  'artist': metadata.artist,
  'album': metadata.album,
  'duration': metadata.duration ?? 0,
  'file_path': filePath,
  'album_art_path': metadata.albumArtPath,  // 新增
  'lyrics_path': metadata.lyricsPath,
  'date_added': null,
  'created_at': nowIso,
  'updated_at': nowIso,
});
```

- [ ] **Step 7: 修改 scanMusic 清理图片缓存**

找到 `scanMusic` 方法开头清理歌词缓存的代码（约第 256 行），修改为：

```dart
final stopwatch = Stopwatch()..start();
resetCancel();
_lyricsCache.clear();
_imageCache.clear();  // 新增
```

- [ ] **Step 8: 修改 _saveMediaSongsToDatabase 优先使用同名图片**

找到 `_saveMediaSongsToDatabase` 方法，在插入歌曲前添加同名图片查找逻辑。

在方法开头添加 ImageCache 构建逻辑（约第 563 行后）：

```dart
/// 将 MediaStore 歌曲保存到数据库
Future<Map<String, dynamic>> _saveMediaSongsToDatabase(
  List<SongModel> mediaSongs,
  String directoryPath,
) async {
  final db = await _dbHelper.database;
  int newAdded = 0;
  int duplicates = 0;
  int filtered = 0;
  final newSongIds = <int>[];
  // 记录 songId 和 mediaId 的映射关系，用于后续获取封面
  final songMediaIdMap = <int, int>{};
  final now = DateTime.now();
  final nowIso = now.toIso8601String();

  // 构建目录下的图片文件缓存
  _imageCache.clear();
  await _buildImageCacheForDirectory(directoryPath);

  // ... 后续代码不变
```

- [ ] **Step 9: 添加 _buildImageCacheForDirectory 方法**

在 `_saveMediaSongsToDatabase` 方法前添加：

```dart
/// 构建指定目录的图片文件缓存
Future<void> _buildImageCacheForDirectory(String directoryPath) async {
  try {
    final dir = Directory(directoryPath);
    if (!await dir.exists()) return;

    final imageFiles = <String, String>{};

    await for (final entity in dir.list(followLinks: false, recursive: true)) {
      if (isCancelled) return;

      if (entity is File) {
        final extension = entity.path.toLowerCase();
        if (_isImageFile(extension)) {
          final fileName = entity.path.split(Platform.pathSeparator).last;
          imageFiles[fileName.toLowerCase()] = entity.path;
        }
      }
    }

    // 将图片文件添加到缓存（按目录分组）
    for (final entry in imageFiles.entries) {
      final imagePath = entry.value;
      final dir = imagePath.substring(0, imagePath.lastIndexOf(Platform.pathSeparator));
      final fileName = entry.key;

      if (!_imageCache.cachedDirectoryCount.toString().contains(dir)) {
        _imageCache.addDirectory(dir, {});
      }
      // 直接添加到缓存
      final cache = <String, String>{};
      cache[fileName] = imagePath;
      _imageCache.addDirectory(dir, cache);
    }
  } catch (e) {
    debugPrint('构建图片缓存失败: $e');
  }
}
```

- [ ] **Step 10: 修改 _saveMediaSongsToDatabase 使用同名图片优先**

找到插入歌曲的代码块（约第 648-661 行），修改为：

```dart
// 查找同名图片
final fileName = filePath.split(Platform.pathSeparator).last;
final nameWithoutExt = fileName.replaceAll(RegExp(r'\.[^.]+$'), '');
String? albumArtPath;

// 按优先级查找同名图片
for (final ext in ['.jpg', '.jpeg', '.png', '.webp', '.gif']) {
  final imageFileName = '$nameWithoutExt$ext'.toLowerCase();
  final imagePath = '$directoryPath${Platform.pathSeparator}$imageFileName';
  if (await File(imagePath).exists()) {
    albumArtPath = imagePath;
    break;
  }
}

final songId = await txn.insert(
  DatabaseHelper.tableSongs,
  {
    'title': title.isEmpty ? 'Unknown' : title,
    'artist': artist,
    'album': album,
    'duration': durationSec,
    'file_path': filePath,
    'album_art_path': albumArtPath,  // 使用同名图片路径
    'date_added': null,
    'created_at': nowIso,
    'updated_at': nowIso,
  },
);
```

- [ ] **Step 11: 运行测试验证**

Run: `cd mysic_flutter && flutter test test/mobile_scanner_directory_test.dart`
Expected: All tests pass

- [ ] **Step 12: 提交**

```bash
git add lib/shared/utils/mobile_music_scanner.dart
git commit -m "feat(scanner): MobileMusicScanner 集成 ImageCache

- 扫描时收集同名图片文件
- 元数据提取时查找封面路径
- 保存 album_art_path 到数据库
- 同名图片优先于 MediaStore 封面

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

### Task 4: 集成测试验证

**Files:**
- Modify: `test/functional/scanner_functional_test.dart`

- [ ] **Step 1: 添加同名图片封面测试用例**

在测试文件中添加：

```dart
group('同名图片封面获取', () {
  test('Windows 扫描同名 jpg 图片作为封面', () async {
    // 准备测试目录
    final testDir = await Directory.systemTemp.createTemp('music_test_');
    final audioFile = File('${testDir.path}/song.mp3');
    final imageFile = File('${testDir.path}/song.jpg');

    // 创建测试文件
    await audioFile.writeAsBytes([0] * 1024 * 100); // 100KB
    await imageFile.writeAsBytes([0] * 1024);

    try {
      final scanner = WindowsMusicScanner();
      final result = await scanner.scanMusicInDirectory(testDir.path);

      expect(result.totalFound, 1);
      expect(result.newAdded, 1);

      // 验证封面路径
      final songs = await scanner.getAllSongs();
      expect(songs.length, 1);
      expect(songs.first.albumArtPath, isNotNull);
      expect(songs.first.albumArtPath, contains('song.jpg'));

      // 清理
      await scanner.clearAllSongs();
    } finally {
      await testDir.delete(recursive: true);
    }
  });

  test('多格式图片按优先级选择', () async {
    final testDir = await Directory.systemTemp.createTemp('music_test_');
    final audioFile = File('${testDir.path}/song.mp3');
    final pngFile = File('${testDir.path}/song.png');
    final gifFile = File('${testDir.path}/song.gif');

    await audioFile.writeAsBytes([0] * 1024 * 100);
    await pngFile.writeAsBytes([0] * 1024);
    await gifFile.writeAsBytes([0] * 1024);

    try {
      final scanner = WindowsMusicScanner();
      await scanner.scanMusicInDirectory(testDir.path);

      final songs = await scanner.getAllSongs();
      // png > gif，应选择 png
      expect(songs.first.albumArtPath, contains('song.png'));

      await scanner.clearAllSongs();
    } finally {
      await testDir.delete(recursive: true);
    }
  });
});
```

- [ ] **Step 2: 运行集成测试**

Run: `cd mysic_flutter && flutter test test/functional/scanner_functional_test.dart`
Expected: All tests pass

- [ ] **Step 3: 提交**

```bash
git add test/functional/scanner_functional_test.dart
git commit -m "test(scanner): 添加同名图片封面集成测试

- 验证同名 jpg 图片作为封面
- 验证多格式图片优先级选择

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

### Task 5: 端到端验证

- [ ] **Step 1: 运行完整测试套件**

Run: `cd mysic_flutter && flutter test`
Expected: All tests pass

- [ ] **Step 2: 运行静态分析**

Run: `cd mysic_flutter && flutter analyze`
Expected: No issues found

- [ ] **Step 3: 手动验证（Windows 桌面版）**

1. 启动应用：`cd mysic_flutter && flutter run -d windows`
2. 选择一个包含同名图片的音乐文件夹进行扫描
3. 验证歌曲列表显示同名图片作为封面
4. 播放歌曲，验证播放界面封面显示正确

- [ ] **Step 4: 最终提交**

```bash
git add -A
git commit -m "feat(scanner): 完成同名图片文件封面获取策略

- 新增 ImageCache 图片缓存类
- WindowsMusicScanner 集成图片封面获取
- MobileMusicScanner 集成图片封面获取
- 封面优先级: 同名图片 > 内嵌封面 > 默认封面

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## 自检清单

- [x] Spec 覆盖：每个需求都有对应任务
- [x] 无占位符：所有代码完整
- [x] 类型一致：方法签名和字段名一致
- [x] 测试覆盖：单元测试 + 集成测试
- [x] 提交粒度：每个任务独立提交
