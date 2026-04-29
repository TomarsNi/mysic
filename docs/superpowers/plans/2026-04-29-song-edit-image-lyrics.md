# 歌曲编辑图片与歌词选择功能实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 扩展现有歌曲编辑对话框，支持用户选择本地图片作为专辑封面、选择本地 .lrc 文件作为歌词。

**Architecture:** 在现有分层架构基础上，新增 `FileCopyService` 工具类处理文件复制，扩展 `Song` 模型和数据库，修改 `SongEditDialog` UI 组件。

**Tech Stack:** Flutter、Dart、SQLite (sqflite)、file_selector、path_provider

---

## 文件结构

```
lib/
├── core/
│   ├── database/
│   │   └── database_helper.dart      # 修改：数据库版本升级 6→7
│   └── services/
│       └── file_copy_service.dart    # 新增：文件复制服务
├── features/
│   ├── player/
│   │   ├── data/
│   │   │   ├── models/
│   │   │   │   └── song.dart         # 修改：新增 lyricsPath 字段
│   │   │   └── repositories/
│   │   │       └── song_repository.dart  # 修改：新增更新封面/歌词路径方法
│   │   └── presentation/
│   │       └── widgets/
│   │           └── song_edit_dialog.dart  # 修改：新增封面和歌词选择 UI
│   └── lyrics/
│       └── data/
│           └── services/
│               └── lyrics_parser.dart    # 修改：适配新的歌词来源优先级
test/
├── core/
│   └── services/
│       └── file_copy_service_test.dart   # 新增：文件复制服务测试
└── features/
    └── player/
        └── presentation/
            └── widgets/
                └── song_edit_dialog_test.dart  # 新增：对话框测试
```

---

### Task 1: 添加 file_selector 依赖

**Files:**
- Modify: `mysic_flutter/pubspec.yaml`

- [ ] **Step 1: 添加 file_selector 依赖到 pubspec.yaml**

在 `dependencies` 部分添加 `file_selector`:

```yaml
dependencies:
  flutter:
    sdk: flutter
  # ... 现有依赖 ...
  
  # 文件选择
  file_selector: ^1.0.3
```

- [ ] **Step 2: 运行 flutter pub get**

Run: `cd mysic_flutter && flutter pub get`
Expected: 成功获取依赖

- [ ] **Step 3: 提交**

```bash
git add mysic_flutter/pubspec.yaml mysic_flutter/pubspec.lock
git commit -m "chore: 添加 file_selector 依赖"
```

---

### Task 2: 扩展 Song 模型

**Files:**
- Modify: `mysic_flutter/lib/features/player/data/models/song.dart`

- [ ] **Step 1: 在 Song 类中添加 lyricsPath 字段**

修改 `song.dart`，在 `albumArtBase64` 字段后添加：

```dart
class Song {
  final int? id;
  final String title;
  final String? artist;
  final String? album;
  final int? duration; // 毫秒
  final String filePath;
  final String? albumArtPath;
  final String? albumArtBase64;
  final String? lyricsPath; // 新增：歌词文件路径
  final int? dateAdded;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Song({
    this.id,
    required this.title,
    this.artist,
    this.album,
    this.duration,
    required this.filePath,
    this.albumArtPath,
    this.albumArtBase64,
    this.lyricsPath, // 新增
    this.dateAdded,
    required this.createdAt,
    required this.updatedAt,
  });
```

- [ ] **Step 2: 更新 fromMap 方法**

在 `Song.fromMap` 中添加 `lyricsPath` 解析：

```dart
factory Song.fromMap(Map<String, dynamic> map) {
  // ... 现有代码 ...
  return Song(
    id: map['id'] as int?,
    title: map['title'] as String,
    artist: map['artist'] as String?,
    album: map['album'] as String?,
    duration: map['duration'] as int?,
    filePath: map['file_path'] as String,
    albumArtPath: map['album_art_path'] as String?,
    albumArtBase64: map['album_art_base64'] as String?,
    lyricsPath: map['lyrics_path'] as String?, // 新增
    dateAdded: map['date_added'] as int?,
    createdAt: parseTimestamp(map['created_at']),
    updatedAt: parseTimestamp(map['updated_at']),
  );
}
```

- [ ] **Step 3: 更新 toMap 方法**

在 `toMap` 中添加 `lyricsPath`:

```dart
Map<String, dynamic> toMap() {
  return {
    if (id != null) 'id': id,
    'title': title,
    'artist': artist,
    'album': album,
    'duration': duration,
    'file_path': filePath,
    'album_art_path': albumArtPath,
    'album_art_base64': albumArtBase64,
    'lyrics_path': lyricsPath, // 新增
    'date_added': dateAdded,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };
}
```

- [ ] **Step 4: 更新 copyWith 方法**

在 `copyWith` 中添加 `lyricsPath`:

```dart
Song copyWith({
  int? id,
  String? title,
  String? artist,
  String? album,
  int? duration,
  String? filePath,
  String? albumArtPath,
  String? albumArtBase64,
  String? lyricsPath, // 新增
  int? dateAdded,
  DateTime? createdAt,
  DateTime? updatedAt,
}) {
  return Song(
    id: id ?? this.id,
    title: title ?? this.title,
    artist: artist ?? this.artist,
    album: album ?? this.album,
    duration: duration ?? this.duration,
    filePath: filePath ?? this.filePath,
    albumArtPath: albumArtPath ?? this.albumArtPath,
    albumArtBase64: albumArtBase64 ?? this.albumArtBase64,
    lyricsPath: lyricsPath ?? this.lyricsPath, // 新增
    dateAdded: dateAdded ?? this.dateAdded,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
}
```

- [ ] **Step 5: 提交**

```bash
git add mysic_flutter/lib/features/player/data/models/song.dart
git commit -m "feat(song): 添加 lyricsPath 字段"
```

---

### Task 3: 数据库迁移

**Files:**
- Modify: `mysic_flutter/lib/core/database/database_helper.dart`

- [ ] **Step 1: 更新数据库版本号**

将 `_databaseVersion` 从 6 改为 7：

```dart
static const int _databaseVersion = 7;
```

- [ ] **Step 2: 在 _onUpgrade 中添加迁移逻辑**

在 `_onUpgrade` 方法末尾添加版本 6→7 的迁移：

```dart
/// 数据库升级
Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
  // ... 现有迁移代码 ...

  // 版本 6 -> 7: 新增 lyrics_path 字段
  if (oldVersion < 7) {
    await db.execute(
      'ALTER TABLE $tableSongs ADD COLUMN lyrics_path TEXT',
    );
  }
}
```

- [ ] **Step 3: 提交**

```bash
git add mysic_flutter/lib/core/database/database_helper.dart
git commit -m "feat(db): 数据库版本升级至 7，新增 lyrics_path 字段"
```

---

### Task 4: 创建 FileCopyService

**Files:**
- Create: `mysic_flutter/lib/core/services/file_copy_service.dart`
- Create: `mysic_flutter/test/core/services/file_copy_service_test.dart`

- [ ] **Step 1: 编写 FileCopyService 测试**

创建测试文件 `test/core/services/file_copy_service_test.dart`:

```dart
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:mysic_flutter/core/services/file_copy_service.dart';

class FakePathProviderPlatform extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  late Directory _appDir;

  Future<void> setup() async {
    _appDir = await Directory.systemTemp.createTemp('mysic_test_');
  }

  Future<void> cleanup() async {
    if (await _appDir.exists()) {
      await _appDir.delete(recursive: true);
    }
  }

  @override
  Future<String?> getApplicationSupportPath() async => _appDir.path;
}

void main() {
  late FileCopyService service;
  late FakePathProviderPlatform fakePlatform;
  late Directory testDir;

  setUpAll(() async {
    fakePlatform = FakePathProviderPlatform();
    await fakePlatform.setup();
    PathProviderPlatform.instance = fakePlatform;
    service = FileCopyService();
  });

  tearDownAll(() async {
    await fakePlatform.cleanup();
  });

  setUp(() async {
    testDir = await Directory.systemTemp.createTemp('test_files_');
  });

  tearDown(() async {
    if (await testDir.exists()) {
      await testDir.delete(recursive: true);
    }
  });

  group('copyAlbumCover', () {
    test('复制图片到应用目录并返回新路径', () async {
      // 创建测试图片文件
      final sourceFile = File(p.join(testDir.path, 'test.jpg'));
      await sourceFile.writeAsBytes([0xFF, 0xD8, 0xFF, 0xE0]); // JPEG header

      final result = await service.copyAlbumCover(sourceFile.path, 1);

      expect(result, isNotNull);
      expect(result, contains('album_covers'));
      expect(result, contains('1_'));
      expect(result, endsWith('.jpg'));

      // 验证文件已复制
      final copiedFile = File(result!);
      expect(await copiedFile.exists(), isTrue);
    });

    test('支持 png 扩展名', () async {
      final sourceFile = File(p.join(testDir.path, 'cover.png'));
      await sourceFile.writeAsBytes([0x89, 0x50, 0x4E, 0x47]); // PNG header

      final result = await service.copyAlbumCover(sourceFile.path, 2);

      expect(result, endsWith('.png'));
    });

    test('源文件不存在时返回 null', () async {
      final result = await service.copyAlbumCover('/nonexistent/file.jpg', 1);
      expect(result, isNull);
    });
  });

  group('copyLyrics', () {
    test('复制歌词文件到应用目录并返回新路径', () async {
      final sourceFile = File(p.join(testDir.path, 'test.lrc'));
      await sourceFile.writeAsString('[00:00.00]Test lyrics');

      final result = await service.copyLyrics(sourceFile.path, 1);

      expect(result, isNotNull);
      expect(result, contains('lyrics'));
      expect(result, contains('1_'));
      expect(result, endsWith('.lrc'));

      // 验证文件内容
      final copiedFile = File(result!);
      expect(await copiedFile.readAsString(), equals('[00:00.00]Test lyrics'));
    });

    test('源文件不存在时返回 null', () async {
      final result = await service.copyLyrics('/nonexistent/file.lrc', 1);
      expect(result, isNull);
    });
  });

  group('deleteFile', () {
    test('删除存在的文件', () async {
      final sourceFile = File(p.join(testDir.path, 'to_delete.lrc'));
      await sourceFile.writeAsString('test');

      final result = await service.copyLyrics(sourceFile.path, 1);
      expect(result, isNotNull);

      await service.deleteFile(result);
      expect(await File(result!).exists(), isFalse);
    });

    test('路径为 null 时不执行任何操作', () async {
      // 不应抛出异常
      await service.deleteFile(null);
    });
  });
}
```

- [ ] **Step 2: 运行测试确认失败**

Run: `cd mysic_flutter && flutter test test/core/services/file_copy_service_test.dart`
Expected: FAIL - FileCopyService 类不存在

- [ ] **Step 3: 实现 FileCopyService**

创建 `lib/core/services/file_copy_service.dart`:

```dart
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// 文件复制服务
/// 负责将用户选择的文件复制到应用目录
class FileCopyService {
  static final FileCopyService _instance = FileCopyService._internal();
  factory FileCopyService() => _instance;
  FileCopyService._internal();

  /// 支持的图片扩展名
  static const List<String> _supportedImageExtensions = ['jpg', 'jpeg', 'png', 'webp'];

  /// 复制专辑封面图片到应用目录
  /// [sourcePath] 源文件路径
  /// [songId] 歌曲 ID，用于命名
  /// 返回复制后的文件路径，失败返回 null
  Future<String?> copyAlbumCover(String sourcePath, int songId) async {
    try {
      final sourceFile = File(sourcePath);
      if (!await sourceFile.exists()) {
        return null;
      }

      // 获取文件扩展名
      final extension = p.extension(sourcePath).toLowerCase();
      final extWithoutDot = extension.isEmpty ? 'jpg' : extension.substring(1);

      // 验证扩展名
      if (!_supportedImageExtensions.contains(extWithoutDot)) {
        return null;
      }

      // 获取应用目录
      final appDir = await getApplicationSupportDirectory();
      final coversDir = Directory(p.join(appDir.path, 'album_covers'));
      if (!await coversDir.exists()) {
        await coversDir.create(recursive: true);
      }

      // 生成目标文件名: {song_id}_{timestamp}.{ext}
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final targetPath = p.join(coversDir.path, '${songId}_$timestamp.$extWithoutDot');

      // 复制文件
      await sourceFile.copy(targetPath);

      return targetPath;
    } catch (e) {
      return null;
    }
  }

  /// 复制歌词文件到应用目录
  /// [sourcePath] 源文件路径
  /// [songId] 歌曲 ID，用于命名
  /// 返回复制后的文件路径，失败返回 null
  Future<String?> copyLyrics(String sourcePath, int songId) async {
    try {
      final sourceFile = File(sourcePath);
      if (!await sourceFile.exists()) {
        return null;
      }

      // 验证扩展名
      final extension = p.extension(sourcePath).toLowerCase();
      if (extension != '.lrc') {
        return null;
      }

      // 获取应用目录
      final appDir = await getApplicationSupportDirectory();
      final lyricsDir = Directory(p.join(appDir.path, 'lyrics'));
      if (!await lyricsDir.exists()) {
        await lyricsDir.create(recursive: true);
      }

      // 生成目标文件名: {song_id}_{timestamp}.lrc
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final targetPath = p.join(lyricsDir.path, '${songId}_$timestamp.lrc');

      // 复制文件
      await sourceFile.copy(targetPath);

      return targetPath;
    } catch (e) {
      return null;
    }
  }

  /// 删除文件
  /// [path] 文件路径，为 null 时不执行任何操作
  Future<void> deleteFile(String? path) async {
    if (path == null || path.isEmpty) return;

    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      // 忽略删除失败
    }
  }
}
```

- [ ] **Step 4: 运行测试确认通过**

Run: `cd mysic_flutter && flutter test test/core/services/file_copy_service_test.dart`
Expected: PASS

- [ ] **Step 5: 提交**

```bash
git add mysic_flutter/lib/core/services/file_copy_service.dart
git add mysic_flutter/test/core/services/file_copy_service_test.dart
git commit -m "feat: 添加 FileCopyService 文件复制服务"
```

---

### Task 5: 扩展 SongRepository

**Files:**
- Modify: `mysic_flutter/lib/features/player/data/repositories/song_repository.dart`

- [ ] **Step 1: 添加更新封面路径方法**

在 `SongRepository` 类中添加：

```dart
/// 更新专辑封面路径
/// 同时清空 albumArtBase64（优先使用文件路径）
Future<void> updateAlbumArt(int songId, String? albumArtPath) async {
  final db = await _dbHelper.database;
  await db.update(
    DatabaseHelper.tableSongs,
    {
      'album_art_path': albumArtPath,
      'album_art_base64': null, // 清空 base64，优先使用文件路径
      'updated_at': DateTime.now().toIso8601String(),
    },
    where: 'id = ?',
    whereArgs: [songId],
  );
}
```

- [ ] **Step 2: 添加更新歌词路径方法**

在 `SongRepository` 类中添加：

```dart
/// 更新歌词文件路径
Future<void> updateLyricsPath(int songId, String? lyricsPath) async {
  final db = await _dbHelper.database;
  await db.update(
    DatabaseHelper.tableSongs,
    {
      'lyrics_path': lyricsPath,
      'updated_at': DateTime.now().toIso8601String(),
    },
    where: 'id = ?',
    whereArgs: [songId],
  );
}
```

- [ ] **Step 3: 提交**

```bash
git add mysic_flutter/lib/features/player/data/repositories/song_repository.dart
git commit -m "feat(song-repo): 添加更新封面和歌词路径方法"
```

---

### Task 6: 适配歌词读取优先级

**Files:**
- Modify: `mysic_flutter/lib/features/player/presentation/providers/player_provider.dart`

- [ ] **Step 1: 修改 _loadLyricsForSong 方法**

更新歌词加载逻辑，优先读取 `lyricsPath`：

```dart
/// 加载当前歌曲的歌词
Future<void> _loadLyricsForSong(Song? song) async {
  if (song == null) {
    _currentLyrics = LyricsResult.empty;
    return;
  }

  // 1. 优先从 songs.lyrics_path 读取（应用目录内的 .lrc 文件）
  if (song.lyricsPath != null && song.lyricsPath!.isNotEmpty) {
    final lyricsFile = File(song.lyricsPath!);
    if (await lyricsFile.exists()) {
      _currentLyrics = await _lyricsParser.parseFile(song.lyricsPath!);
      if (_currentLyrics.isValid) {
        notifyListeners();
        return;
      }
    }
  }

  // 2. 从数据库 lyrics 表加载
  final db = await DatabaseHelper().database;
  final dbResult = await db.query(
    DatabaseHelper.tableLyrics,
    where: 'song_id = ?',
    whereArgs: [song.id],
  );

  if (dbResult.isNotEmpty) {
    final lrcContent = dbResult.first['lrc_content'] as String?;
    if (lrcContent != null && lrcContent.isNotEmpty) {
      _currentLyrics = _lyricsParser.parse(lrcContent);
      notifyListeners();
      return;
    }
  }

  // 3. 从文件系统查找同名 .lrc 文件
  final lyricsPath = _lyricsParser.findLyricsFile(song.filePath);
  if (lyricsPath != null) {
    _currentLyrics = await _lyricsParser.parseFile(lyricsPath);
  } else {
    _currentLyrics = LyricsResult.empty;
  }
  notifyListeners();
}
```

- [ ] **Step 2: 添加 dart:io 导入**

在文件顶部添加：

```dart
import 'dart:io';
```

- [ ] **Step 3: 提交**

```bash
git add mysic_flutter/lib/features/player/presentation/providers/player_provider.dart
git commit -m "feat(player): 歌词加载优先使用 lyricsPath"
```

---

### Task 7: 扩展 SongEditDialog UI

**Files:**
- Modify: `mysic_flutter/lib/features/player/presentation/widgets/song_edit_dialog.dart`

- [ ] **Step 1: 添加必要的导入**

在文件顶部添加：

```dart
import 'dart:io';
import 'package:file_selector/file_selector.dart';
import 'package:path/path.dart' as p;
import '../../../../core/services/file_copy_service.dart';
import '../../../../core/theme/app_colors.dart';
```

- [ ] **Step 2: 添加状态变量和 FileCopyService**

在 `_SongEditDialogState` 类中添加：

```dart
class _SongEditDialogState extends State<SongEditDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _artistController;
  late final TextEditingController _albumController;

  final FileCopyService _fileCopyService = FileCopyService();
  String? _albumArtPath;
  String? _lyricsPath;
  bool _isProcessing = false;
```

- [ ] **Step 3: 更新 initState 初始化路径**

```dart
@override
void initState() {
  super.initState();
  _titleController = TextEditingController(text: widget.song.title);
  _artistController = TextEditingController(text: widget.song.artist ?? '');
  _albumController = TextEditingController(text: widget.song.album ?? '');
  _albumArtPath = widget.song.albumArtPath;
  _lyricsPath = widget.song.lyricsPath;
}
```

- [ ] **Step 4: 添加选择图片方法**

```dart
/// 选择专辑封面图片
Future<void> _selectAlbumCover() async {
  if (_isProcessing) return;
  if (widget.song.id == null) {
    _showError('请先保存歌曲信息');
    return;
  }

  final result = await FileSelector.openFile(
    acceptedTypeGroups: [
      XTypeGroup(
        label: '图片',
        extensions: ['jpg', 'jpeg', 'png', 'webp'],
        uniformTypeIdentifiers: ['public.image'],
      ),
    ],
  );

  if (result == null) return;

  setState(() => _isProcessing = true);

  try {
    // 删除旧封面
    if (_albumArtPath != null) {
      await _fileCopyService.deleteFile(_albumArtPath);
    }

    // 复制新封面
    final newPath = await _fileCopyService.copyAlbumCover(
      result.path,
      widget.song.id!,
    );

    if (newPath != null) {
      setState(() => _albumArtPath = newPath);
    } else {
      _showError('复制图片失败');
    }
  } finally {
    setState(() => _isProcessing = false);
  }
}
```

- [ ] **Step 5: 添加清除封面方法**

```dart
/// 清除专辑封面
Future<void> _clearAlbumCover() async {
  if (_albumArtPath != null) {
    await _fileCopyService.deleteFile(_albumArtPath);
    setState(() => _albumArtPath = null);
  }
}
```

- [ ] **Step 6: 添加选择歌词方法**

```dart
/// 选择歌词文件
Future<void> _selectLyrics() async {
  if (_isProcessing) return;
  if (widget.song.id == null) {
    _showError('请先保存歌曲信息');
    return;
  }

  final result = await FileSelector.openFile(
    acceptedTypeGroups: [
      XTypeGroup(
        label: '歌词',
        extensions: ['lrc'],
        uniformTypeIdentifiers: ['public.plain-text'],
      ),
    ],
  );

  if (result == null) return;

  setState(() => _isProcessing = true);

  try {
    // 删除旧歌词
    if (_lyricsPath != null) {
      await _fileCopyService.deleteFile(_lyricsPath);
    }

    // 复制新歌词
    final newPath = await _fileCopyService.copyLyrics(
      result.path,
      widget.song.id!,
    );

    if (newPath != null) {
      setState(() => _lyricsPath = newPath);
    } else {
      _showError('复制歌词文件失败');
    }
  } finally {
    setState(() => _isProcessing = false);
  }
}
```

- [ ] **Step 7: 添加清除歌词方法**

```dart
/// 清除歌词文件
Future<void> _clearLyrics() async {
  if (_lyricsPath != null) {
    await _fileCopyService.deleteFile(_lyricsPath);
    setState(() => _lyricsPath = null);
  }
}
```

- [ ] **Step 8: 添加辅助方法**

```dart
/// 显示错误提示
void _showError(String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message)),
  );
}

/// 获取歌词文件名
String get _lyricsFileName {
  if (_lyricsPath == null) return '未选择';
  return p.basename(_lyricsPath!);
}
```

- [ ] **Step 9: 更新 _handleSave 方法**

```dart
void _handleSave() {
  final title = _titleController.text.trim();
  if (title.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('歌曲名称不能为空')),
    );
    return;
  }

  final updatedSong = widget.song.copyWith(
    title: title,
    artist: _artistController.text.trim().isEmpty
        ? null
        : _artistController.text.trim(),
    album: _albumController.text.trim().isEmpty
        ? null
        : _albumController.text.trim(),
    albumArtPath: _albumArtPath,
    albumArtBase64: _albumArtPath != null ? null : widget.song.albumArtBase64,
    lyricsPath: _lyricsPath,
    updatedAt: DateTime.now(),
  );

  widget.onSave(updatedSong);
  Navigator.of(context).pop();
}
```

- [ ] **Step 10: 重写 build 方法**

完整替换 build 方法：

```dart
@override
Widget build(BuildContext context) {
  return AlertDialog(
    title: const Text('编辑歌曲信息'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 专辑封面区域
          _buildAlbumCoverSection(),
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 16),

          // 文本输入区域
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: '歌曲名称',
              hintText: '请输入歌曲名称',
            ),
            autofocus: true,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _artistController,
            decoration: const InputDecoration(
              labelText: '艺术家',
              hintText: '请输入艺术家名称',
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _albumController,
            decoration: const InputDecoration(
              labelText: '专辑',
              hintText: '请输入专辑名称',
            ),
          ),
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 16),

          // 歌词文件区域
          _buildLyricsSection(),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: _isProcessing ? null : () => Navigator.of(context).pop(),
        child: const Text('取消'),
      ),
      FilledButton(
        onPressed: _isProcessing ? null : _handleSave,
        child: _isProcessing
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Text('保存'),
      ),
    ],
  );
}
```

- [ ] **Step 11: 添加 _buildAlbumCoverSection 方法**

```dart
/// 构建专辑封面区域
Widget _buildAlbumCoverSection() {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        '专辑封面',
        style: Theme.of(context).textTheme.titleSmall,
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          // 封面预览
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: _albumArtPath != null
                  ? null
                  : AppColors.accentGradient,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: ClipOval(
              child: _albumArtPath != null
                  ? Image.file(
                      File(_albumArtPath!),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _buildDefaultCoverIcon(),
                    )
                  : _buildDefaultCoverIcon(),
            ),
          ),
          const SizedBox(width: 16),
          // 操作按钮
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  TextButton.icon(
                    onPressed: _isProcessing ? null : _selectAlbumCover,
                    icon: const Icon(Icons.image_outlined, size: 18),
                    label: const Text('选择图片'),
                  ),
                  const SizedBox(width: 8),
                  if (_albumArtPath != null)
                    TextButton.icon(
                      onPressed: _isProcessing ? null : _clearAlbumCover,
                      icon: const Icon(Icons.delete_outline, size: 18),
                      label: const Text('清除'),
                      style: TextButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.error,
                      ),
                    ),
                ],
              ),
              Text(
                '支持 JPG、PNG、WebP',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.muted,
                ),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

/// 构建默认封面图标
Widget _buildDefaultCoverIcon() {
  return Container(
    decoration: const BoxDecoration(
      gradient: AppColors.accentGradient,
      shape: BoxShape.circle,
    ),
    child: const Center(
      child: Icon(
        Icons.music_note_rounded,
        color: AppColors.white,
        size: 32,
      ),
    ),
  );
}
```

- [ ] **Step 12: 添加 _buildLyricsSection 方法**

```dart
/// 构建歌词文件区域
Widget _buildLyricsSection() {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        '歌词文件',
        style: Theme.of(context).textTheme.titleSmall,
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(
            child: Row(
              children: [
                const Icon(
                  Icons.lyrics_outlined,
                  size: 20,
                  color: AppColors.muted,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _lyricsFileName,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: _lyricsPath != null ? null : AppColors.muted,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            onPressed: _isProcessing ? null : _selectLyrics,
            icon: const Icon(Icons.folder_open_outlined, size: 18),
            label: const Text('选择歌词'),
          ),
          if (_lyricsPath != null) ...[
            const SizedBox(width: 8),
            TextButton.icon(
              onPressed: _isProcessing ? null : _clearLyrics,
              icon: const Icon(Icons.delete_outline, size: 18),
              label: const Text('清除'),
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
            ),
          ],
        ],
      ),
      Text(
        '支持 LRC 格式歌词文件',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: AppColors.muted,
        ),
      ),
    ],
  );
}
```

- [ ] **Step 13: 提交**

```bash
git add mysic_flutter/lib/features/player/presentation/widgets/song_edit_dialog.dart
git commit -m "feat(song-edit): 添加专辑封面和歌词文件选择功能"
```

---

### Task 8: 更新 PlayerProvider 保存逻辑

**Files:**
- Modify: `mysic_flutter/lib/features/player/presentation/providers/player_provider.dart`

- [ ] **Step 1: 更新 updateSong 方法**

确保 `updateSong` 方法正确处理 `albumArtPath` 和 `lyricsPath` 的更新（现有实现已支持，因为使用 `song.toMap()` 完整更新）。

验证代码无需修改，现有实现已正确处理。

- [ ] **Step 2: 提交（如有修改）**

如无需修改，跳过此步骤。

---

### Task 9: 运行完整测试

**Files:**
- 无文件修改

- [ ] **Step 1: 运行所有单元测试**

Run: `cd mysic_flutter && flutter test`
Expected: 所有测试通过

- [ ] **Step 2: 运行应用进行手动测试**

Run: `cd mysic_flutter && flutter run -d windows`

手动测试清单：
1. 打开歌曲编辑对话框
2. 选择一张图片作为封面，验证显示正确
3. 清除封面，验证恢复默认图标
4. 选择一个 .lrc 文件，验证文件名显示正确
5. 清除歌词，验证显示"未选择"
6. 保存后重新打开，验证数据持久化
7. 播放歌曲，验证歌词正确加载

---

### Task 10: 最终提交

- [ ] **Step 1: 运行代码格式化**

Run: `cd mysic_flutter && dart format .`

- [ ] **Step 2: 运行静态分析**

Run: `cd mysic_flutter && flutter analyze`
Expected: 无错误或警告

- [ ] **Step 3: 创建功能完成提交**

```bash
git add -A
git commit -m "feat(song-edit): 完成专辑封面和歌词文件选择功能

- 新增 FileCopyService 处理文件复制
- Song 模型新增 lyricsPath 字段
- 数据库版本升级至 7
- SongEditDialog 支持选择图片和歌词文件
- 歌词加载优先使用 lyricsPath"
```

---

## 测试清单

- [ ] 图片选择、复制、显示、清除流程
- [ ] 歌词选择、复制、读取、清除流程
- [ ] 数据库迁移正确性（从版本 6 升级）
- [ ] 文件命名不冲突（多首歌曲、多次选择）
- [ ] 跨平台路径处理（Windows/Android/iOS）
- [ ] 编辑对话框 UI 显示正确
- [ ] 保存后数据持久化正确
- [ ] 歌词播放时正确加载
