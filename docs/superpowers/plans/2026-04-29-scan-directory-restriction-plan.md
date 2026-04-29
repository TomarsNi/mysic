# 限制音乐扫描目录范围 - 实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 限制音乐扫描的目录范围，仅扫描用户配置的目录（如 Music、音乐、Downloads 等），而非全盘扫描。

**Architecture:** 在现有扫描架构上增加目录配置层。新增 `ScanDirectoryProvider` 管理目录配置，修改 `WindowsMusicScanner` 和 `MobileMusicScanner` 应用目录过滤逻辑，在设置页面提供目录管理 UI。

**Tech Stack:** Flutter、SQLite、Provider

---

## 文件结构

| 文件 | 操作 | 职责 |
|------|------|------|
| `lib/core/database/database_helper.dart` | 修改 | 添加 `settings` 表，升级数据库版本 |
| `lib/shared/utils/scan_directory_provider.dart` | 新增 | 目录配置管理类（CRUD 操作） |
| `lib/shared/utils/windows_music_scanner.dart` | 修改 | 应用目录过滤逻辑 |
| `lib/shared/utils/mobile_music_scanner.dart` | 重写 | 改为文件系统扫描 + 目录过滤 |
| `lib/shared/utils/music_scanner.dart` | 修改 | 注入 `ScanDirectoryProvider` |
| `lib/main.dart` | 修改 | 在 `SettingsSheet` 添加目录管理入口 |
| `lib/features/settings/presentation/widgets/scan_directory_list.dart` | 新增 | 目录列表管理组件 |
| `test/scan_directory_provider_test.dart` | 新增 | 目录配置管理测试 |
| `test/windows_scanner_directory_test.dart` | 新增 | Windows 扫描器目录过滤测试 |

---

## Task 1: 数据库添加 settings 表

**Files:**
- Modify: `lib/core/database/database_helper.dart:19-27` (添加表常量)
- Modify: `lib/core/database/database_helper.dart:57-172` (_onCreate 方法)
- Modify: `lib/core/database/database_helper.dart:175-322` (_onUpgrade 方法)
- Test: `test/database_helper_settings_test.dart`

- [ ] **Step 1: 写失败的测试**

```dart
// test/database_helper_settings_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mysic_flutter/core/database/database_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DatabaseHelper settings table', () {
    late DatabaseHelper dbHelper;

    setUp(() async {
      dbHelper = DatabaseHelper();
      await dbHelper.deleteDatabase();
    });

    tearDown(() async {
      await dbHelper.close();
    });

    test('settings table exists after database creation', () async {
      final db = await dbHelper.database;
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='settings'",
      );
      expect(tables, isNotEmpty);
    });

    test('settings table has correct columns', () async {
      final db = await dbHelper.database;
      final columns = await db.rawQuery('PRAGMA table_info(settings)');
      final columnNames = columns.map((c) => c['name'] as String).toList();

      expect(columnNames, contains('key'));
      expect(columnNames, contains('value'));
      expect(columnNames, contains('updated_at'));
    });
  });
}
```

- [ ] **Step 2: 运行测试验证失败**

Run: `cd mysic_flutter && flutter test test/database_helper_settings_test.dart`
Expected: FAIL - 表不存在

- [ ] **Step 3: 添加 settings 表常量**

```dart
// 在 database_helper.dart 第 27 行后添加
static const String tableSettings = 'settings';
```

- [ ] **Step 4: 在 _onCreate 中创建 settings 表**

```dart
// 在 _onCreate 方法的最后（第 171 行后）添加
// 创建设置表
await db.execute('''
  CREATE TABLE $tableSettings (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL,
    updated_at TEXT NOT NULL
  )
''');
```

- [ ] **Step 5: 更新数据库版本号**

```dart
// 修改第 19 行
static const int _databaseVersion = 8;
```

- [ ] **Step 6: 在 _onUpgrade 中添加迁移**

```dart
// 在 _onUpgrade 方法最后（第 321 行后）添加
// 版本 7 -> 8: 新增 settings 表
if (oldVersion < 8) {
  await db.execute('''
    CREATE TABLE $tableSettings (
      key TEXT PRIMARY KEY,
      value TEXT NOT NULL,
      updated_at TEXT NOT NULL
    )
  ''');
}
```

- [ ] **Step 7: 运行测试验证通过**

Run: `cd mysic_flutter && flutter test test/database_helper_settings_test.dart`
Expected: PASS

- [ ] **Step 8: 提交**

```bash
git add lib/core/database/database_helper.dart test/database_helper_settings_test.dart
git commit -m "feat(db): 添加 settings 表存储扫描目录配置"
```

---

## Task 2: 创建 ScanDirectoryProvider 类

**Files:**
- Create: `lib/shared/utils/scan_directory_provider.dart`
- Test: `test/scan_directory_provider_test.dart`

- [ ] **Step 1: 写失败的测试**

```dart
// test/scan_directory_provider_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mysic_flutter/core/database/database_helper.dart';
import 'package:mysic_flutter/shared/utils/scan_directory_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ScanDirectoryProvider', () {
    late ScanDirectoryProvider provider;
    late DatabaseHelper dbHelper;

    setUp(() async {
      dbHelper = DatabaseHelper();
      await dbHelper.deleteDatabase();
      provider = ScanDirectoryProvider();
    });

    tearDown(() async {
      await dbHelper.close();
    });

    test('getDirectories returns default directories when empty', () async {
      final directories = await provider.getDirectories();
      expect(directories, isNotEmpty);
      expect(directories, contains('Music'));
      expect(directories, contains('音乐'));
    });

    test('addDirectory adds a new directory', () async {
      await provider.addDirectory('MyMusic');
      final directories = await provider.getDirectories();
      expect(directories, contains('MyMusic'));
    });

    test('removeDirectory removes a directory', () async {
      await provider.addDirectory('TestDir');
      await provider.removeDirectory('TestDir');
      final directories = await provider.getDirectories();
      expect(directories, isNot(contains('TestDir')));
    });

    test('resetToDefault resets to default directories', () async {
      await provider.addDirectory('CustomDir');
      await provider.resetToDefault();
      final directories = await provider.getDirectories();
      expect(directories, isNot(contains('CustomDir')));
      expect(directories, contains('Music'));
    });
  });
}
```

- [ ] **Step 2: 运行测试验证失败**

Run: `cd mysic_flutter && flutter test test/scan_directory_provider_test.dart`
Expected: FAIL - 类不存在

- [ ] **Step 3: 创建 ScanDirectoryProvider 类**

```dart
// lib/shared/utils/scan_directory_provider.dart
import 'dart:convert';
import '../../core/database/database_helper.dart';

/// 默认扫描目录列表
const List<String> kDefaultScanDirectories = [
  'Music',
  '音乐',
  'Downloads',
  '下载',
  'Download',
  'Audio',
  '音频',
  'Songs',
  '歌曲',
];

/// 扫描目录配置管理类
class ScanDirectoryProvider {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  static const String _keyScanDirectories = 'scan_directories';

  /// 获取扫描目录列表
  Future<List<String>> getDirectories() async {
    final db = await _dbHelper.database;
    final result = await db.query(
      DatabaseHelper.tableSettings,
      where: 'key = ?',
      whereArgs: [_keyScanDirectories],
    );

    if (result.isEmpty) {
      // 首次访问，初始化默认目录
      await _saveDirectories(kDefaultScanDirectories);
      return List.from(kDefaultScanDirectories);
    }

    final value = result.first['value'] as String;
    final List<dynamic> jsonList = jsonDecode(value);
    return jsonList.cast<String>();
  }

  /// 添加扫描目录
  Future<void> addDirectory(String directory) async {
    final directories = await getDirectories();
    if (!directories.contains(directory)) {
      directories.add(directory);
      await _saveDirectories(directories);
    }
  }

  /// 移除扫描目录
  Future<void> removeDirectory(String directory) async {
    final directories = await getDirectories();
    directories.remove(directory);
    await _saveDirectories(directories);
  }

  /// 重置为默认目录
  Future<void> resetToDefault() async {
    await _saveDirectories(kDefaultScanDirectories);
  }

  /// 保存目录列表到数据库
  Future<void> _saveDirectories(List<String> directories) async {
    final db = await _dbHelper.database;
    final now = DateTime.now().toIso8601String();
    final value = jsonEncode(directories);

    await db.insert(
      DatabaseHelper.tableSettings,
      {
        'key': _keyScanDirectories,
        'value': value,
        'updated_at': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
```

- [ ] **Step 4: 添加缺失的导入**

需要在 `scan_directory_provider.dart` 顶部添加：

```dart
import 'package:sqflite/sqflite.dart';
```

- [ ] **Step 5: 运行测试验证通过**

Run: `cd mysic_flutter && flutter test test/scan_directory_provider_test.dart`
Expected: PASS

- [ ] **Step 6: 提交**

```bash
git add lib/shared/utils/scan_directory_provider.dart test/scan_directory_provider_test.dart
git commit -m "feat(scanner): 添加 ScanDirectoryProvider 管理扫描目录配置"
```

---

## Task 3: 修改 WindowsMusicScanner 应用目录过滤

**Files:**
- Modify: `lib/shared/utils/windows_music_scanner.dart`
- Test: `test/windows_scanner_directory_test.dart`

- [ ] **Step 1: 写失败的测试**

```dart
// test/windows_scanner_directory_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mysic_flutter/shared/utils/scan_directory_provider.dart';
import 'package:mysic_flutter/shared/utils/windows_music_scanner.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WindowsMusicScanner directory filtering', () {
    test('_getScanRoots returns only configured directories', () async {
      final provider = ScanDirectoryProvider();
      await provider.resetToDefault();

      final scanner = WindowsMusicScanner();
      // 添加 getter 用于测试
      final roots = await scanner.getScanRootsForTest();

      // 验证返回的根目录都在配置的目录名列表中
      final dirNames = await provider.getDirectories();
      for (final root in roots) {
        final dirName = root.split('\\').last;
        expect(dirNames, contains(dirName));
      }
    });
  });
}
```

- [ ] **Step 2: 运行测试验证失败**

Run: `cd mysic_flutter && flutter test test/windows_scanner_directory_test.dart`
Expected: FAIL - 方法不存在

- [ ] **Step 3: 修改 WindowsMusicScanner 添加 ScanDirectoryProvider**

```dart
// 在 windows_music_scanner.dart 顶部添加导入
import 'scan_directory_provider.dart';

// 在类中添加成员变量
class WindowsMusicScanner extends PlatformMusicScanner {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final ScanDirectoryProvider _directoryProvider = ScanDirectoryProvider();

  // ... 其他代码
}
```

- [ ] **Step 4: 添加 _getScanRoots 方法**

```dart
// 在 WindowsMusicScanner 类中添加（替换原有的 _getAvailableDrives 调用逻辑）
/// 获取扫描根目录列表
Future<List<String>> _getScanRoots() async {
  final directoryNames = await _directoryProvider.getDirectories();
  final drives = await _getAvailableDrives();

  final roots = <String>[];
  for (final drive in drives) {
    for (final dirName in directoryNames) {
      final path = '$drive$dirName';
      try {
        if (await Directory(path).exists()) {
          roots.add(path);
        }
      } catch (_) {
        // 忽略无权限目录
      }
    }
  }
  return roots;
}

/// 测试用：获取扫描根目录
Future<List<String>> getScanRootsForTest() => _getScanRoots();
```

- [ ] **Step 5: 修改 scanMusic 方法使用 _getScanRoots**

```dart
// 修改 scanMusic 方法中的扫描逻辑（约第 145-169 行）
// 替换：
// for (int i = 0; i < drives.length; i++) {
//   ...
//   await _scanDirectory(drive, songs, ...);
// }

// 改为：
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

for (int i = 0; i < scanRoots.length; i++) {
  if (isCancelled) break;

  final root = scanRoots[i];
  final rootProgress = i / scanRoots.length;

  await _scanDirectory(root, songs, (path, count) {
    filesScanned += count;
    progressCounter++;

    if (progressCounter % 100 == 0 || songs.length % 50 == 0) {
      updateProgress(ScanProgress(
        currentPath: path,
        filesScanned: filesScanned,
        songsFound: songs.length,
        progress: rootProgress + (1 / scanRoots.length) * 0.9,
      ));
    }
  });
}
```

- [ ] **Step 6: 运行测试验证通过**

Run: `cd mysic_flutter && flutter test test/windows_scanner_directory_test.dart`
Expected: PASS

- [ ] **Step 7: 提交**

```bash
git add lib/shared/utils/windows_music_scanner.dart test/windows_scanner_directory_test.dart
git commit -m "feat(scanner): WindowsMusicScanner 应用目录过滤逻辑"
```

---

## Task 4: 重写 MobileMusicScanner 为文件系统扫描

**Files:**
- Modify: `lib/shared/utils/mobile_music_scanner.dart`
- Test: `test/mobile_scanner_directory_test.dart`

- [ ] **Step 1: 写失败的测试**

```dart
// test/mobile_scanner_directory_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mysic_flutter/shared/utils/scan_directory_provider.dart';
import 'package:mysic_flutter/shared/utils/mobile_music_scanner.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MobileMusicScanner directory filtering', () {
    test('_getScanRoots returns only configured directories', () async {
      final provider = ScanDirectoryProvider();
      await provider.resetToDefault();

      final scanner = MobileMusicScanner();
      final roots = await scanner.getScanRootsForTest();

      // 验证返回的根目录都在配置的目录名列表中
      final dirNames = await provider.getDirectories();
      for (final root in roots) {
        final parts = root.split('/');
        final dirName = parts.isNotEmpty ? parts.last : '';
        expect(dirNames, contains(dirName));
      }
    });
  });
}
```

- [ ] **Step 2: 运行测试验证失败**

Run: `cd mysic_flutter && flutter test test/mobile_scanner_directory_test.dart`
Expected: FAIL - 方法不存在

- [ ] **Step 3: 重写 MobileMusicScanner**

```dart
// lib/shared/utils/mobile_music_scanner.dart
import 'dart:async';
import 'dart:io';
import 'package:audiotags/audiotags.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/database/database_helper.dart';
import '../../features/player/data/models/song.dart';
import 'platform_music_scanner.dart';
import 'scan_directory_provider.dart';

/// 移动端平台音乐扫描器
class MobileMusicScanner extends PlatformMusicScanner {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final ScanDirectoryProvider _directoryProvider = ScanDirectoryProvider();

  /// 支持的音频格式
  static const Set<String> _audioExtensions = {
    '.mp3', '.flac', '.wav', '.m4a', '.aac', '.ogg', '.wma',
  };

  /// 最小文件大小 (2.5MB)
  static const int _minFileSizeBytes = 2500 * 1024;

  /// 最小时长（秒）- 2分45秒 = 165秒
  static const int _minDurationSec = 165;

  /// 最大时长（秒）- 25分钟 = 1500秒
  static const int _maxDurationSec = 25 * 60;

  /// 跳过的目录名
  static const Set<String> _skipDirectories = {
    '.cache', 'cache', 'Cache', 'Android', 'DCIM', 'Camera',
    'Pictures', 'Movies', 'Video', 'Videos', 'Documents',
  };

  /// 非音乐文件名关键词
  static const Set<String> _nonMusicKeywords = {
    'notification', 'alert', 'alarm', 'ringtone',
    'message', 'startup', 'shutdown', 'logon', 'logoff',
    'click', 'tap', 'button', 'menu', 'cursor',
    'error', 'warning', 'critical', 'test',
    'sfx', 'sound_fx', 'soundfx', 'fx_',
    'footstep', 'explosion', 'gunshot', 'reload',
    'hit', 'miss', 'damage', 'heal', 'death',
    'jump', 'land', 'walk', 'attack',
    'ui_', 'gui_', 'interface_',
    'ambience', 'ambient', 'environment',
    'voiceover', 'voice_over', 'vo_',
    'tts_', 'speech', 'prompt',
  };

  bool _isLikelyNonMusicFile(String filePath) {
    final fileName = filePath.toLowerCase();
    for (final keyword in _nonMusicKeywords) {
      if (fileName.contains(keyword)) {
        return true;
      }
    }
    return false;
  }

  @override
  Future<bool> requestPermission() async {
    final status = await Permission.storage.request();
    if (status.isGranted) return true;

    final audioStatus = await Permission.audio.request();
    return audioStatus.isGranted;
  }

  @override
  Future<bool> hasPermission() async {
    final status = await Permission.storage.status;
    if (status.isGranted) return true;

    final audioStatus = await Permission.audio.status;
    return audioStatus.isGranted;
  }

  /// 获取外部存储根目录
  Future<String> _getExternalStorageRoot() async {
    // Android 外部存储根目录
    return '/storage/emulated/0';
  }

  /// 获取扫描根目录列表
  Future<List<String>> _getScanRoots() async {
    final directoryNames = await _directoryProvider.getDirectories();
    final storageRoot = await _getExternalStorageRoot();

    final roots = <String>[];
    for (final dirName in directoryNames) {
      final path = '$storageRoot/$dirName';
      try {
        if (await Directory(path).exists()) {
          roots.add(path);
        }
      } catch (_) {
        // 忽略无权限目录
      }
    }
    return roots;
  }

  /// 测试用：获取扫描根目录
  Future<List<String>> getScanRootsForTest() => _getScanRoots();

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

    try {
      final hasPerm = await hasPermission();
      if (!hasPerm) {
        final granted = await requestPermission();
        if (!granted) {
          return const ScanResult(
            totalFound: 0,
            newAdded: 0,
            duplicates: 0,
            scanDuration: Duration.zero,
            errorMessage: '未获得存储权限',
          );
        }
      }

      updateState(ScanState.scanning);

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

      final songs = <File>[];
      int filesScanned = 0;
      int progressCounter = 0;

      for (int i = 0; i < scanRoots.length; i++) {
        if (isCancelled) break;

        final root = scanRoots[i];
        final rootProgress = i / scanRoots.length;

        await _scanDirectory(root, songs, (path, count) {
          filesScanned += count;
          progressCounter++;

          if (progressCounter % 100 == 0 || songs.length % 50 == 0) {
            updateProgress(ScanProgress(
              currentPath: path,
              filesScanned: filesScanned,
              songsFound: songs.length,
              progress: rootProgress + (1 / scanRoots.length) * 0.9,
            ));
          }
        });
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
        currentPath: '正在保存...',
        filesScanned: filesScanned,
        songsFound: totalFound,
        progress: 0.95,
      ));

      updateState(ScanState.saving);

      final result = await _saveSongsToDatabase(songs);

      updateState(ScanState.completed);
      stopwatch.stop();

      updateProgress(ScanProgress(
        currentPath: '完成',
        filesScanned: filesScanned,
        songsFound: totalFound,
        progress: 1.0,
      ));

      return ScanResult(
        totalFound: totalFound,
        newAdded: result['newAdded']!,
        duplicates: result['duplicates']!,
        scanDuration: stopwatch.elapsed,
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

  /// 递归扫描目录
  Future<void> _scanDirectory(
    String path,
    List<File> songs,
    void Function(String path, int count) onProgress,
  ) async {
    if (isCancelled) return;

    try {
      final dir = Directory(path);
      if (!await dir.exists()) return;

      await for (final entity in dir.list(followLinks: false)) {
        if (isCancelled) return;

        if (entity is Directory) {
          final dirName = entity.path.split('/').last;
          if (_skipDirectories.contains(dirName)) continue;

          try {
            await _scanDirectory(entity.path, songs, onProgress);
          } catch (_) {
            // 忽略无权限目录
          }
        } else if (entity is File) {
          final extension = entity.path.toLowerCase();
          for (final ext in _audioExtensions) {
            if (extension.endsWith(ext)) {
              if (_isLikelyNonMusicFile(entity.path)) {
                break;
              }
              try {
                final fileSize = await entity.length();
                if (fileSize >= _minFileSizeBytes) {
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
    } catch (_) {
      // 忽略无权限目录
    }
  }

  String _cleanTitleFromFileName(String fileName) {
    var title = fileName.replaceAll(RegExp(r'\.[^.]+$'), '');
    title = title.replaceFirst(RegExp(r'^\d+[\s.\-_]+'), '');
    return title.trim();
  }

  Future<_AudioMetadata> _extractMetadata(String filePath) async {
    try {
      final tag = await AudioTags.read(filePath);
      if (tag != null) {
        return _AudioMetadata(
          title: tag.title,
          artist: tag.trackArtist,
          album: tag.album,
          duration: tag.duration,
        );
      }
    } catch (e) {
      print('读取元数据失败: $filePath, 错误: $e');
    }

    final fileName = filePath.split('/').last;
    return _AudioMetadata(
      title: _cleanTitleFromFileName(fileName),
      artist: null,
      album: null,
      duration: null,
    );
  }

  Future<Map<String, int>> _saveSongsToDatabase(List<File> songs) async {
    final db = await _dbHelper.database;
    int newAdded = 0;
    int duplicates = 0;
    int filtered = 0;
    int skipped = 0;
    final now = DateTime.now();
    final nowIso = now.toIso8601String();

    final allExisting = await db.query(
      DatabaseHelper.tableSongs,
      columns: ['file_path'],
    );
    final existingPaths = allExisting.map((row) => row['file_path'] as String).toSet();

    final deletedPathsResult = await db.query(
      DatabaseHelper.tableSongs,
      columns: ['file_path'],
      where: 'is_deleted = ?',
      whereArgs: [1],
    );
    final deletedPaths = deletedPathsResult
        .map((row) => row['file_path'] as String)
        .toSet();

    await db.transaction((txn) async {
      for (final file in songs) {
        if (isCancelled) break;

        final filePath = file.path;

        if (deletedPaths.contains(filePath)) {
          skipped++;
          continue;
        }

        if (existingPaths.contains(filePath)) {
          duplicates++;
        } else {
          final metadata = await _extractMetadata(filePath);

          if (metadata.duration != null) {
            if (metadata.duration! < _minDurationSec || metadata.duration! > _maxDurationSec) {
              filtered++;
              continue;
            }
          }

          final fileName = filePath.split('/').last;
          final title = metadata.title?.isNotEmpty == true
              ? metadata.title
              : _cleanTitleFromFileName(fileName);

          await txn.insert(
            DatabaseHelper.tableSongs,
            {
              'title': title,
              'artist': metadata.artist,
              'album': metadata.album,
              'duration': metadata.duration ?? 0,
              'file_path': filePath,
              'album_art_path': null,
              'date_added': null,
              'created_at': nowIso,
              'updated_at': nowIso,
            },
          );
          newAdded++;
        }
      }
    });

    print('Mobile扫描完成: newAdded=$newAdded, duplicates=$duplicates, filtered=$filtered, skipped=$skipped');
    return {'newAdded': newAdded, 'duplicates': duplicates};
  }

  @override
  Future<void> deleteSong(int songId) async {
    final db = await _dbHelper.database;
    await db.delete(
      DatabaseHelper.tableSongs,
      where: 'id = ?',
      whereArgs: [songId],
    );
  }

  @override
  Future<List<Song>> getAllSongs() async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      DatabaseHelper.tableSongs,
      orderBy: 'title ASC',
    );
    return maps.map((map) => Song.fromMap(map)).toList();
  }

  @override
  Future<int> getSongCount() async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM ${DatabaseHelper.tableSongs}',
    );
    if (result.isEmpty) return 0;
    return result.first['count'] as int? ?? 0;
  }

  @override
  Future<void> clearAllSongs() async {
    final db = await _dbHelper.database;
    await db.delete(DatabaseHelper.tableSongs);
  }
}

class _AudioMetadata {
  const _AudioMetadata({
    this.title,
    this.artist,
    this.album,
    this.duration,
  });

  final String? title;
  final String? artist;
  final String? album;
  final int? duration;
}
```

- [ ] **Step 4: 运行测试验证通过**

Run: `cd mysic_flutter && flutter test test/mobile_scanner_directory_test.dart`
Expected: PASS

- [ ] **Step 5: 提交**

```bash
git add lib/shared/utils/mobile_music_scanner.dart test/mobile_scanner_directory_test.dart
git commit -m "feat(scanner): MobileMusicScanner 改为文件系统扫描并应用目录过滤"
```

---

## Task 5: 创建扫描目录管理 UI 组件

**Files:**
- Create: `lib/features/settings/presentation/widgets/scan_directory_list.dart`

- [ ] **Step 1: 创建 ScanDirectoryList 组件**

```dart
// lib/features/settings/presentation/widgets/scan_directory_list.dart
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/utils/scan_directory_provider.dart';

/// 扫描目录管理组件
class ScanDirectoryList extends StatefulWidget {
  const ScanDirectoryList({super.key});

  @override
  State<ScanDirectoryList> createState() => _ScanDirectoryListState();
}

class _ScanDirectoryListState extends State<ScanDirectoryList> {
  final ScanDirectoryProvider _provider = ScanDirectoryProvider();
  List<String> _directories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDirectories();
  }

  Future<void> _loadDirectories() async {
    final directories = await _provider.getDirectories();
    if (mounted) {
      setState(() {
        _directories = directories;
        _isLoading = false;
      });
    }
  }

  Future<void> _addDirectory() async {
    final controller = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text(
          '添加扫描目录',
          style: TextStyle(color: AppColors.white),
        ),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: AppColors.white),
          decoration: const InputDecoration(
            hintText: '输入目录名称',
            hintStyle: TextStyle(color: AppColors.muted),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: AppColors.muted),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: AppColors.accent),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消', style: TextStyle(color: AppColors.muted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('添加', style: TextStyle(color: AppColors.accent)),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      await _provider.addDirectory(result);
      await _loadDirectories();
    }
  }

  Future<void> _removeDirectory(String directory) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text(
          '确认删除',
          style: TextStyle(color: AppColors.white),
        ),
        content: Text(
          '确定要删除目录 "$directory" 吗？',
          style: const TextStyle(color: AppColors.muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消', style: TextStyle(color: AppColors.muted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _provider.removeDirectory(directory);
      await _loadDirectories();
    }
  }

  Future<void> _resetToDefault() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text(
          '恢复默认',
          style: TextStyle(color: AppColors.white),
        ),
        content: const Text(
          '确定要恢复默认扫描目录吗？',
          style: TextStyle(color: AppColors.muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消', style: TextStyle(color: AppColors.muted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('恢复', style: TextStyle(color: AppColors.accent)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _provider.resetToDefault();
      await _loadDirectories();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.accent),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 标题
        const Text(
          '扫描目录管理',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.white,
          ),
        ),

        const SizedBox(height: 8),

        const Text(
          '仅扫描以下目录中的音乐文件',
          style: TextStyle(fontSize: 14, color: AppColors.muted),
        ),

        const SizedBox(height: 16),

        // 目录列表
        Container(
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _directories.length,
            separatorBuilder: (context, index) => const Divider(
              color: AppColors.surface,
              height: 1,
            ),
            itemBuilder: (context, index) {
              final directory = _directories[index];
              return ListTile(
                title: Text(
                  directory,
                  style: const TextStyle(color: AppColors.white),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, color: AppColors.muted),
                  onPressed: () => _removeDirectory(directory),
                ),
              );
            },
          ),
        ),

        const SizedBox(height: 16),

        // 操作按钮
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _addDirectory,
                icon: const Icon(Icons.add, color: AppColors.accent),
                label: const Text(
                  '添加目录',
                  style: TextStyle(color: AppColors.accent),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.accent),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _resetToDefault,
                icon: const Icon(Icons.restore, color: AppColors.muted),
                label: const Text(
                  '恢复默认',
                  style: TextStyle(color: AppColors.muted),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.muted),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
```

- [ ] **Step 2: 提交**

```bash
git add lib/features/settings/presentation/widgets/scan_directory_list.dart
git commit -m "feat(settings): 添加扫描目录管理 UI 组件"
```

---

## Task 6: 在设置面板中集成目录管理

**Files:**
- Modify: `lib/main.dart` (SettingsSheet 类)

- [ ] **Step 1: 在 SettingsSheet 中添加目录管理入口**

```dart
// 在 main.dart 顶部添加导入
import 'features/settings/presentation/widgets/scan_directory_list.dart';

// 在 SettingsSheet 的 build 方法中，在 ListTile 列表后添加
// 约第 1105 行后添加：

ListTile(
  leading: const Icon(Icons.folder_rounded, color: Color(0xFF6366F1)),
  title: const Text('扫描目录', style: TextStyle(color: Colors.white)),
  subtitle: const Text('管理音乐扫描目录', style: TextStyle(color: Color(0xFF9CA3AF))),
  onTap: () {
    Navigator.pop(context);
    _showScanDirectorySheet(context);
  },
),
```

- [ ] **Step 2: 添加 _showScanDirectorySheet 方法**

```dart
// 在 _MyHomePageState 类中添加方法
void _showScanDirectorySheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    backgroundColor: AppColors.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) => Container(
        padding: const EdgeInsets.all(20),
        child: const ScanDirectoryList(),
      ),
    ),
  );
}
```

- [ ] **Step 3: 运行应用验证 UI**

Run: `cd mysic_flutter && flutter run -d windows`
Expected: 设置面板中出现「扫描目录」选项，点击可进入目录管理页面

- [ ] **Step 4: 提交**

```bash
git add lib/main.dart
git commit -m "feat(settings): 在设置面板中集成扫描目录管理入口"
```

---

## Task 7: 运行完整测试套件

- [ ] **Step 1: 运行所有测试**

Run: `cd mysic_flutter && flutter test`
Expected: 所有测试通过

- [ ] **Step 2: 运行代码分析**

Run: `cd mysic_flutter && flutter analyze`
Expected: 无错误或警告

- [ ] **Step 3: 最终提交**

```bash
git add -A
git commit -m "feat(scanner): 完成限制音乐扫描目录范围功能"
```

---

## 验收标准

- [ ] Windows 端仅扫描配置的目录
- [ ] Android 端文件系统扫描正常工作
- [ ] 设置页面可以添加/删除/恢复默认目录
- [ ] 首次启动自动初始化默认目录配置
- [ ] 所有测试通过
- [ ] 代码分析无错误
