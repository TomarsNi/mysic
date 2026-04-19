# Windows 全盘音乐扫描实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为 Mysic 音乐播放器实现 Windows 平台全盘音乐扫描功能

**Architecture:** 采用平台适配器模式，创建抽象基类 `PlatformMusicScanner`，分别实现 `WindowsMusicScanner`（dart:io 文件遍历）和 `MobileMusicScanner`（on_audio_query）。`MusicScanner` 作为门面类委托给平台实现。

**Tech Stack:** Dart、dart:io、just_audio、sqflite

---

## 文件结构

```
lib/shared/utils/
├── music_scanner.dart           # 门面类（修改）
├── platform_music_scanner.dart  # 抽象基类（新增）
├── windows_music_scanner.dart   # Windows 实现（新增）
└── mobile_music_scanner.dart    # 移动端实现（新增）
```

---

### Task 1: 创建平台扫描器抽象基类

**Files:**
- Create: `mysic_flutter/lib/shared/utils/platform_music_scanner.dart`

- [ ] **Step 1: 创建 platform_music_scanner.dart**

```dart
import 'dart:async';
import '../../features/player/data/models/song.dart';

/// 扫描状态
enum ScanState {
  idle,
  scanning,
  saving,
  completed,
  error,
}

/// 扫描进度
class ScanProgress {
  final String currentPath;
  final int filesScanned;
  final int songsFound;
  final double progress;

  const ScanProgress({
    this.currentPath = '',
    this.filesScanned = 0,
    this.songsFound = 0,
    this.progress = 0.0,
  });

  ScanProgress copyWith({
    String? currentPath,
    int? filesScanned,
    int? songsFound,
    double? progress,
  }) {
    return ScanProgress(
      currentPath: currentPath ?? this.currentPath,
      filesScanned: filesScanned ?? this.filesScanned,
      songsFound: songsFound ?? this.songsFound,
      progress: progress ?? this.progress,
    );
  }
}

/// 扫描结果
class ScanResult {
  final int totalFound;
  final int newAdded;
  final int duplicates;
  final Duration scanDuration;
  final String? errorMessage;

  const ScanResult({
    required this.totalFound,
    required this.newAdded,
    required this.duplicates,
    required this.scanDuration,
    this.errorMessage,
  });

  bool get isSuccess => errorMessage == null;
}

/// 平台音乐扫描器抽象基类
abstract class PlatformMusicScanner {
  // 状态流控制器
  final _stateController = StreamController<ScanState>.broadcast();
  final _progressController = StreamController<ScanProgress>.broadcast();

  // 公开的流
  Stream<ScanState> get stateStream => _stateController.stream;
  Stream<ScanProgress> get progressStream => _progressController.stream;

  // 当前状态
  ScanState _state = ScanState.idle;
  ScanState get state => _state;
  bool get isScanning => _state == ScanState.scanning || _state == ScanState.saving;

  // 取消标志
  bool _cancelled = false;
  bool get isCancelled => _cancelled;

  /// 请求权限
  Future<bool> requestPermission();

  /// 检查权限
  Future<bool> hasPermission();

  /// 扫描音乐
  Future<ScanResult> scanMusic();

  /// 取消扫描
  void cancelScan() {
    _cancelled = true;
  }

  /// 重置取消标志
  void resetCancel() {
    _cancelled = false;
  }

  /// 更新状态
  void updateState(ScanState newState) {
    if (_state != newState) {
      _state = newState;
      _stateController.add(_state);
    }
  }

  /// 更新进度
  void updateProgress(ScanProgress progress) {
    _progressController.add(progress);
  }

  /// 释放资源
  Future<void> dispose() async {
    await _stateController.close();
    await _progressController.close();
  }
}
```

- [ ] **Step 2: 提交**

```bash
git add mysic_flutter/lib/shared/utils/platform_music_scanner.dart
git commit -m "feat(scanner): 添加平台扫描器抽象基类"
```

---

### Task 2: 实现 Windows 平台扫描器

**Files:**
- Create: `mysic_flutter/lib/shared/utils/windows_music_scanner.dart`

- [ ] **Step 1: 创建 windows_music_scanner.dart**

```dart
import 'dart:async';
import 'dart:io';
import 'package:sqflite/sqflite.dart';
import '../../core/database/database_helper.dart';
import '../../features/player/data/models/song.dart';
import 'platform_music_scanner.dart';

/// Windows 平台音乐扫描器
class WindowsMusicScanner extends PlatformMusicScanner {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  /// 支持的音频格式
  static const Set<String> _audioExtensions = {
    '.mp3', '.flac', '.wav', '.m4a', '.aac', '.ogg', '.wma',
  };

  /// 跳过的目录名
  static const Set<String> _skipDirectories = {
    '\$RECYCLE.BIN',
    'System Volume Information',
    'Windows',
    'Program Files',
    'Program Files (x86)',
    'ProgramData',
    '.git',
    '.svn',
    'node_modules',
  };

  @override
  Future<bool> requestPermission() async {
    // Windows 不需要特殊权限
    return true;
  }

  @override
  Future<bool> hasPermission() async {
    return true;
  }

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
      updateState(ScanState.scanning);

      // 获取所有驱动器
      final drives = await _getAvailableDrives();
      if (drives.isEmpty) {
        updateState(ScanState.completed);
        stopwatch.stop();
        return ScanResult(
          totalFound: 0,
          newAdded: 0,
          duplicates: 0,
          scanDuration: stopwatch.elapsed,
        );
      }

      // 扫描所有驱动器
      final songs = <File>[];
      int filesScanned = 0;

      for (int i = 0; i < drives.length; i++) {
        if (isCancelled) break;

        final drive = drives[i];
        final driveProgress = i / drives.length;

        await _scanDirectory(drive, songs, (path, count) {
          filesScanned += count;
          updateProgress(ScanProgress(
            currentPath: path,
            filesScanned: filesScanned,
            songsFound: songs.length,
            progress: driveProgress + (1 / drives.length) * 0.9,
          ));
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

      // 保存到数据库
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

  /// 获取所有可用驱动器
  Future<List<String>> _getAvailableDrives() async {
    final drives = <String>[];
    for (final letter in ['C', 'D', 'E', 'F', 'G', 'H']) {
      final drive = '$letter:\\';
      try {
        final dir = Directory(drive);
        if (await dir.exists()) {
          drives.add(drive);
        }
      } catch (_) {
        // 忽略无法访问的驱动器
      }
    }
    return drives;
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
          final dirName = entity.path.split(Platform.pathSeparator).last;
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
              songs.add(entity);
              onProgress(entity.path, 1);
              break;
            }
          }
        }
      }
    } catch (_) {
      // 忽略无权限目录
    }
  }

  /// 保存歌曲到数据库
  Future<Map<String, int>> _saveSongsToDatabase(List<File> songs) async {
    final db = await _dbHelper.database;
    int newAdded = 0;
    int duplicates = 0;
    final now = DateTime.now();
    final nowTimestamp = now.millisecondsSinceEpoch;

    for (final file in songs) {
      if (isCancelled) break;

      final filePath = file.path;

      // 检查是否已存在
      final existing = await db.query(
        DatabaseHelper.tableSongs,
        where: 'file_path = ?',
        whereArgs: [filePath],
        limit: 1,
      );

      if (existing.isNotEmpty) {
        duplicates++;
      } else {
        // 从文件名提取标题
        final fileName = filePath.split(Platform.pathSeparator).last;
        final title = fileName.replaceAll(RegExp(r'\.[^.]+$'), '');

        await db.insert(
          DatabaseHelper.tableSongs,
          {
            'title': title,
            'artist': null,
            'album': null,
            'duration': 0,
            'file_path': filePath,
            'album_art_path': null,
            'date_added': null,
            'created_at': nowTimestamp,
            'updated_at': nowTimestamp,
          },
        );
        newAdded++;
      }
    }

    return {'newAdded': newAdded, 'duplicates': duplicates};
  }

  /// 从数据库获取所有歌曲
  Future<List<Song>> getAllSongs() async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      DatabaseHelper.tableSongs,
      orderBy: 'title ASC',
    );
    return maps.map((map) => Song.fromMap(map)).toList();
  }

  /// 获取歌曲数量
  Future<int> getSongCount() async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM ${DatabaseHelper.tableSongs}',
    );
    if (result.isEmpty) return 0;
    return result.first['count'] as int? ?? 0;
  }

  /// 清空所有歌曲
  Future<void> clearAllSongs() async {
    final db = await _dbHelper.database;
    await db.delete(DatabaseHelper.tableSongs);
  }
}
```

- [ ] **Step 2: 提交**

```bash
git add mysic_flutter/lib/shared/utils/windows_music_scanner.dart
git commit -m "feat(scanner): 实现 Windows 平台音乐扫描器"
```

---

### Task 3: 实现移动端平台扫描器

**Files:**
- Create: `mysic_flutter/lib/shared/utils/mobile_music_scanner.dart`

- [ ] **Step 1: 创建 mobile_music_scanner.dart**

```dart
import 'dart:async';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sqflite/sqflite.dart';
import '../../core/database/database_helper.dart';
import '../../features/player/data/models/song.dart';
import 'platform_music_scanner.dart';

/// 移动端平台音乐扫描器
class MobileMusicScanner extends PlatformMusicScanner {
  final OnAudioQuery _audioQuery = OnAudioQuery();
  final DatabaseHelper _dbHelper = DatabaseHelper();

  @override
  Future<bool> requestPermission() async {
    final status = await Permission.storage.request();
    if (status.isGranted) return true;

    // Android 13+ 需要请求音频权限
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
      // 检查权限
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

      // 查询所有歌曲
      final songs = await _audioQuery.querySongs(
        sortType: SongSortType.TITLE,
        orderType: OrderType.ASC_OR_SMALLER,
        uriType: UriType.EXTERNAL,
      );

      final totalFound = songs.length;

      updateProgress(ScanProgress(
        currentPath: '找到 $totalFound 首歌曲',
        filesScanned: totalFound,
        songsFound: totalFound,
        progress: 0.5,
      ));

      if (totalFound == 0) {
        updateState(ScanState.completed);
        stopwatch.stop();
        return ScanResult(
          totalFound: 0,
          newAdded: 0,
          duplicates: 0,
          scanDuration: stopwatch.elapsed,
        );
      }

      updateState(ScanState.saving);

      // 保存到数据库
      final result = await _saveSongsToDatabase(songs);

      updateState(ScanState.completed);
      stopwatch.stop();

      updateProgress(ScanProgress(
        currentPath: '完成',
        filesScanned: totalFound,
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

  /// 保存歌曲到数据库
  Future<Map<String, int>> _saveSongsToDatabase(List<SongModel> songs) async {
    final db = await _dbHelper.database;
    int newAdded = 0;
    int duplicates = 0;
    final now = DateTime.now();
    final nowTimestamp = now.millisecondsSinceEpoch;

    for (int i = 0; i < songs.length; i++) {
      if (isCancelled) break;

      final songModel = songs[i];

      // 检查是否已存在
      final existing = await db.query(
        DatabaseHelper.tableSongs,
        where: 'file_path = ?',
        whereArgs: [songModel.data],
        limit: 1,
      );

      if (existing.isNotEmpty) {
        duplicates++;
      } else {
        await db.insert(
          DatabaseHelper.tableSongs,
          {
            'title': songModel.title ?? '未知歌曲',
            'artist': songModel.artist,
            'album': songModel.album,
            'duration': songModel.duration ?? 0,
            'file_path': songModel.data,
            'album_art_path': null,
            'date_added': songModel.dateAdded,
            'created_at': nowTimestamp,
            'updated_at': nowTimestamp,
          },
        );
        newAdded++;
      }

      // 更新进度
      updateProgress(ScanProgress(
        currentPath: '保存中 ${i + 1}/${songs.length}',
        filesScanned: songs.length,
        songsFound: i + 1,
        progress: 0.5 + (i + 1) / songs.length * 0.5,
      ));
    }

    return {'newAdded': newAdded, 'duplicates': duplicates};
  }

  /// 从数据库获取所有歌曲
  Future<List<Song>> getAllSongs() async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      DatabaseHelper.tableSongs,
      orderBy: 'title ASC',
    );
    return maps.map((map) => Song.fromMap(map)).toList();
  }

  /// 获取歌曲数量
  Future<int> getSongCount() async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM ${DatabaseHelper.tableSongs}',
    );
    if (result.isEmpty) return 0;
    return result.first['count'] as int? ?? 0;
  }

  /// 清空所有歌曲
  Future<void> clearAllSongs() async {
    final db = await _dbHelper.database;
    await db.delete(DatabaseHelper.tableSongs);
  }
}
```

- [ ] **Step 2: 提交**

```bash
git add mysic_flutter/lib/shared/utils/mobile_music_scanner.dart
git commit -m "feat(scanner): 实现移动端平台音乐扫描器"
```

---

### Task 4: 修复 Song 模型时间戳解析

**Files:**
- Modify: `mysic_flutter/lib/features/player/data/models/song.dart`

- [ ] **Step 1: 修改 Song.fromMap 支持 INTEGER 时间戳**

数据库存储的是毫秒时间戳（INTEGER），但 fromMap 期望 ISO8601 字符串。修改 fromMap 方法：

```dart
  /// 从数据库 Map 创建 Song 对象
  factory Song.fromMap(Map<String, dynamic> map) {
    // 支持毫秒时间戳或 ISO8601 字符串
    DateTime parseTimestamp(dynamic value) {
      if (value == null) return DateTime.now();
      if (value is int) {
        return DateTime.fromMillisecondsSinceEpoch(value);
      }
      return DateTime.parse(value as String);
    }

    return Song(
      id: map['id'] as int?,
      title: map['title'] as String,
      artist: map['artist'] as String?,
      album: map['album'] as String?,
      duration: map['duration'] as int?,
      filePath: map['file_path'] as String,
      albumArtPath: map['album_art_path'] as String?,
      dateAdded: map['date_added'] as int?,
      createdAt: parseTimestamp(map['created_at']),
      updatedAt: parseTimestamp(map['updated_at']),
    );
  }
```

- [ ] **Step 2: 提交**

```bash
git add mysic_flutter/lib/features/player/data/models/song.dart
git commit -m "fix(song): 修复时间戳解析支持 INTEGER 格式"
```

---

### Task 5: 重构 MusicScanner 门面类

**Files:**
- Modify: `mysic_flutter/lib/shared/utils/music_scanner.dart`

- [ ] **Step 1: 重写 music_scanner.dart**

```dart
import 'dart:async';
import 'dart:io';
import '../../features/player/data/models/song.dart';
import 'platform_music_scanner.dart';
import 'windows_music_scanner.dart';
import 'mobile_music_scanner.dart';

// 导出类型供外部使用
export 'platform_music_scanner.dart' show ScanState, ScanProgress, ScanResult;

/// 音乐扫描服务
/// 根据平台自动选择合适的扫描器实现
class MusicScanner {
  late final PlatformMusicScanner _platformScanner;

  MusicScanner() {
    if (Platform.isWindows || Platform.isLinux) {
      _platformScanner = WindowsMusicScanner();
    } else {
      _platformScanner = MobileMusicScanner();
    }
  }

  // 委托给平台实现
  Stream<ScanState> get stateStream => _platformScanner.stateStream;
  Stream<ScanProgress> get progressStream => _platformScanner.progressStream;
  ScanState get state => _platformScanner.state;
  bool get isScanning => _platformScanner.isScanning;

  /// 请求存储权限
  Future<bool> requestPermission() => _platformScanner.requestPermission();

  /// 检查是否有权限
  Future<bool> hasPermission() => _platformScanner.hasPermission();

  /// 扫描本地音乐
  Future<ScanResult> scanMusic() => _platformScanner.scanMusic();

  /// 取消扫描
  void cancelScan() => _platformScanner.cancelScan();

  /// 从数据库获取所有歌曲
  Future<List<Song>> getAllSongs() => _platformScanner.getAllSongs();

  /// 从数据库获取歌曲数量
  Future<int> getSongCount() => _platformScanner.getSongCount();

  /// 搜索歌曲
  Future<List<Song>> searchSongs(String query) async {
    if (query.isEmpty) return getAllSongs();

    final allSongs = await getAllSongs();
    final lowerQuery = query.toLowerCase();
    return allSongs.where((song) {
      return song.title.toLowerCase().contains(lowerQuery) ||
          (song.artist?.toLowerCase().contains(lowerQuery) ?? false) ||
          (song.album?.toLowerCase().contains(lowerQuery) ?? false);
    }).toList();
  }

  /// 删除歌曲
  Future<void> deleteSong(int songId) async {
    await _platformScanner.deleteSong(songId);
  }

  /// 清空所有歌曲
  Future<void> clearAllSongs() => _platformScanner.clearAllSongs();

  /// 重置状态
  void reset() {
    _platformScanner.updateState(ScanState.idle);
    _platformScanner.updateProgress(const ScanProgress());
  }

  /// 释放资源
  Future<void> dispose() => _platformScanner.dispose();
}
```

- [ ] **Step 2: 为 PlatformMusicScanner 添加 deleteSong 方法**

修改 `platform_music_scanner.dart`，在抽象类中添加：

```dart
  /// 删除歌曲
  Future<void> deleteSong(int songId);
```

- [ ] **Step 3: 为 WindowsMusicScanner 实现 deleteSong**

在 `windows_music_scanner.dart` 中添加：

```dart
  @override
  Future<void> deleteSong(int songId) async {
    final db = await _dbHelper.database;
    await db.delete(
      DatabaseHelper.tableSongs,
      where: 'id = ?',
      whereArgs: [songId],
    );
  }
```

- [ ] **Step 4: 为 MobileMusicScanner 实现 deleteSong**

在 `mobile_music_scanner.dart` 中添加：

```dart
  @override
  Future<void> deleteSong(int songId) async {
    final db = await _dbHelper.database;
    await db.delete(
      DatabaseHelper.tableSongs,
      where: 'id = ?',
      whereArgs: [songId],
    );
  }
```

- [ ] **Step 5: 提交**

```bash
git add mysic_flutter/lib/shared/utils/music_scanner.dart
git add mysic_flutter/lib/shared/utils/platform_music_scanner.dart
git add mysic_flutter/lib/shared/utils/windows_music_scanner.dart
git add mysic_flutter/lib/shared/utils/mobile_music_scanner.dart
git commit -m "refactor(scanner): 重构 MusicScanner 为平台适配器模式"
```

---

### Task 6: 更新 UI 支持扫描进度显示和取消

**Files:**
- Modify: `mysic_flutter/lib/main.dart`

- [ ] **Step 1: 修改 _HomePageState 添加进度监听**

在 `_HomePageState` 类中添加成员变量：

```dart
class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
  late AnimationController _fabAnimationController;
  bool _isScanning = false;
  String _scanPath = '';
  int _scanFound = 0;
  double _scanProgress = 0.0;
  MusicScanner? _currentScanner;
```

- [ ] **Step 2: 修改 _startScan 方法**

```dart
  Future<void> _startScan() async {
    setState(() {
      _isScanning = true;
      _scanPath = '准备扫描...';
      _scanFound = 0;
      _scanProgress = 0.0;
    });

    try {
      final scanner = MusicScanner();
      _currentScanner = scanner;

      // 监听进度
      scanner.progressStream.listen((progress) {
        if (mounted) {
          setState(() {
            _scanPath = progress.currentPath;
            _scanFound = progress.songsFound;
            _scanProgress = progress.progress;
          });
        }
      });

      final result = await scanner.scanMusic();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result.isSuccess
                  ? '扫描完成: 发现 ${result.totalFound} 首歌曲，新增 ${result.newAdded} 首'
                  : '扫描失败: ${result.errorMessage}',
            ),
            backgroundColor: result.isSuccess ? const Color(0xFF6366F1) : Colors.red,
          ),
        );

        await _loadPlaylists();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('扫描失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isScanning = false;
          _currentScanner = null;
        });
      }
    }
  }
```

- [ ] **Step 3: 添加取消扫描方法**

```dart
  void _cancelScan() {
    _currentScanner?.cancelScan();
    setState(() {
      _isScanning = false;
      _currentScanner = null;
    });
  }
```

- [ ] **Step 4: 修改扫描按钮显示进度**

修改 `_buildEmptyState` 方法中的扫描按钮部分：

```dart
            // 扫描按钮和进度
            if (_isScanning) ...[
              // 进度条
              SizedBox(
                width: 280,
                child: Column(
                  children: [
                    LinearProgressIndicator(
                      value: _scanProgress > 0 ? _scanProgress : null,
                      backgroundColor: const Color(0xFF16213E),
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '已发现 $_scanFound 首歌曲',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF9CA3AF),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _scanPath,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6B7280),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 16),
                    TextButton.icon(
                      onPressed: _cancelScan,
                      icon: const Icon(Icons.cancel_rounded, color: Colors.red),
                      label: const Text('取消扫描', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              ),
            ] else ...[
              ElevatedButton.icon(
                onPressed: _startScan,
                icon: const Icon(Icons.folder_open_rounded),
                label: const Text('扫描本地音乐'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ],
```

- [ ] **Step 5: 提交**

```bash
git add mysic_flutter/lib/main.dart
git commit -m "feat(ui): 添加扫描进度显示和取消功能"
```

---

### Task 7: 测试验证

- [ ] **Step 1: 运行 Flutter 分析**

```bash
cd mysic_flutter && flutter analyze
```

Expected: No issues found

- [ ] **Step 2: 在 Windows 上运行应用**

```bash
cd mysic_flutter && flutter run -d windows
```

- [ ] **Step 3: 手动测试**

1. 点击"扫描本地音乐"按钮
2. 观察进度条和当前扫描路径显示
3. 确认能发现音乐文件
4. 测试取消功能

- [ ] **Step 4: 最终提交**

```bash
git add -A
git commit -m "feat(scanner): 完成 Windows 全盘音乐扫描功能"
```
