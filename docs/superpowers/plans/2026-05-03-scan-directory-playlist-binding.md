# 扫描目录与歌单绑定功能实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 实现扫描目录与歌单的绑定功能，使得扫描指定目录后歌曲自动添加到关联的歌单中。

**Architecture:** 扩展 ScanDirectoryProvider 存储结构，引入 ScanDirectoryConfig 模型关联目录与歌单。修改扫描逻辑，遍历目录配置并将歌曲添加到对应歌单。更新 UI 显示关联状态。

**Tech Stack:** Flutter、Dart、SQLite (sqflite)、Provider

---

## 文件结构

```
lib/shared/utils/
├── scan_directory_config.dart      # 新增：目录配置数据模型
├── scan_directory_provider.dart    # 修改：扩展存储和方法
└── windows_music_scanner.dart      # 修改：返回按目录分组的扫描结果

lib/features/settings/presentation/
├── pages/scan_settings_page.dart   # 修改：扫描逻辑调整
└── widgets/scan_directory_list.dart # 修改：UI 显示关联状态

test/
├── scan_directory_config_test.dart      # 新增：模型测试
└── scan_directory_provider_test.dart    # 修改：Provider 测试扩展
```

---

## Task 1: 创建 ScanDirectoryConfig 数据模型

**Files:**
- Create: `lib/shared/utils/scan_directory_config.dart`
- Test: `test/scan_directory_config_test.dart`

- [ ] **Step 1: 编写 ScanDirectoryConfig 模型测试**

```dart
// test/scan_directory_config_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mysic_flutter/shared/utils/scan_directory_config.dart';

void main() {
  group('ScanDirectoryConfig', () {
    test('fromJson parses valid json correctly', () {
      final json = {
        'directory': 'Music',
        'playlistId': 1,
        'playlistName': '本地音乐',
      };
      final config = ScanDirectoryConfig.fromJson(json);
      expect(config.directory, 'Music');
      expect(config.playlistId, 1);
      expect(config.playlistName, '本地音乐');
    });

    test('toJson produces correct json', () {
      const config = ScanDirectoryConfig(
        directory: 'Downloads',
        playlistId: 2,
        playlistName: '下载',
      );
      final json = config.toJson();
      expect(json['directory'], 'Downloads');
      expect(json['playlistId'], 2);
      expect(json['playlistName'], '下载');
    });

    test('copyWith creates modified copy', () {
      const config = ScanDirectoryConfig(directory: 'Music');
      final updated = config.copyWith(playlistId: 1, playlistName: 'Music');
      expect(updated.directory, 'Music');
      expect(updated.playlistId, 1);
      expect(updated.playlistName, 'Music');
    });

    test('handles null playlist fields', () {
      final json = {'directory': 'NewFolder'};
      final config = ScanDirectoryConfig.fromJson(json);
      expect(config.directory, 'NewFolder');
      expect(config.playlistId, isNull);
      expect(config.playlistName, isNull);
    });

    test('isLinked returns correct value', () {
      const linked = ScanDirectoryConfig(
        directory: 'Music',
        playlistId: 1,
        playlistName: 'Music',
      );
      const unlinked = ScanDirectoryConfig(directory: 'NewFolder');
      expect(linked.isLinked, isTrue);
      expect(unlinked.isLinked, isFalse);
    });
  });
}
```

- [ ] **Step 2: 运行测试确认失败**

```bash
cd mysic_flutter && flutter test test/scan_directory_config_test.dart
```

Expected: FAIL (文件不存在)

- [ ] **Step 3: 实现 ScanDirectoryConfig 模型**

```dart
// lib/shared/utils/scan_directory_config.dart
/// 扫描目录配置
/// 关联扫描目录与歌单
class ScanDirectoryConfig {
  /// 目录名称/路径
  final String directory;

  /// 关联的歌单 ID（null 表示未关联）
  final int? playlistId;

  /// 关联的歌单名称（冗余存储，便于显示）
  final String? playlistName;

  const ScanDirectoryConfig({
    required this.directory,
    this.playlistId,
    this.playlistName,
  });

  /// 是否已关联歌单
  bool get isLinked => playlistId != null && playlistName != null;

  /// 从 JSON 解析
  factory ScanDirectoryConfig.fromJson(Map<String, dynamic> json) {
    return ScanDirectoryConfig(
      directory: json['directory'] as String,
      playlistId: json['playlistId'] as int?,
      playlistName: json['playlistName'] as String?,
    );
  }

  /// 转换为 JSON
  Map<String, dynamic> toJson() {
    return {
      'directory': directory,
      if (playlistId != null) 'playlistId': playlistId,
      if (playlistName != null) 'playlistName': playlistName,
    };
  }

  /// 创建副本
  ScanDirectoryConfig copyWith({
    String? directory,
    int? playlistId,
    String? playlistName,
    bool clearPlaylist = false,
  }) {
    return ScanDirectoryConfig(
      directory: directory ?? this.directory,
      playlistId: clearPlaylist ? null : (playlistId ?? this.playlistId),
      playlistName: clearPlaylist ? null : (playlistName ?? this.playlistName),
    );
  }

  @override
  String toString() {
    return 'ScanDirectoryConfig(directory: $directory, playlistId: $playlistId, playlistName: $playlistName)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ScanDirectoryConfig &&
        other.directory == directory &&
        other.playlistId == playlistId &&
        other.playlistName == playlistName;
  }

  @override
  int get hashCode => Object.hash(directory, playlistId, playlistName);
}
```

- [ ] **Step 4: 运行测试确认通过**

```bash
cd mysic_flutter && flutter test test/scan_directory_config_test.dart
```

Expected: PASS

- [ ] **Step 5: 提交**

```bash
git add lib/shared/utils/scan_directory_config.dart test/scan_directory_config_test.dart
git commit -m "feat: 添加 ScanDirectoryConfig 数据模型"
```

---

## Task 2: 扩展 ScanDirectoryProvider

**Files:**
- Modify: `lib/shared/utils/scan_directory_provider.dart`
- Modify: `test/scan_directory_provider_test.dart`

- [ ] **Step 1: 编写 Provider 扩展测试**

在 `test/scan_directory_provider_test.dart` 末尾添加：

```dart
import 'package:mysic_flutter/shared/utils/scan_directory_config.dart';

// 在现有 group 后添加新的 group
group('ScanDirectoryProvider with configs', () {
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

  test('getConfigs returns empty list initially', () async {
    final configs = await provider.getConfigs();
    expect(configs, isEmpty);
  });

  test('addDirectoryWithPlaylist creates config with playlist', () async {
    await provider.addDirectoryWithPlaylist(
      'Music',
      playlistId: 1,
      playlistName: 'Music',
    );
    final configs = await provider.getConfigs();
    expect(configs.length, 1);
    expect(configs.first.directory, 'Music');
    expect(configs.first.playlistId, 1);
    expect(configs.first.playlistName, 'Music');
  });

  test('updateDirectoryPlaylist updates existing config', () async {
    await provider.addDirectoryWithPlaylist('Music', playlistId: 1, playlistName: 'Music');
    await provider.updateDirectoryPlaylist('Music', 2, 'NewMusic');
    final configs = await provider.getConfigs();
    expect(configs.first.playlistId, 2);
    expect(configs.first.playlistName, 'NewMusic');
  });

  test('getConfigByDirectory returns correct config', () async {
    await provider.addDirectoryWithPlaylist('Music', playlistId: 1, playlistName: 'Music');
    await provider.addDirectoryWithPlaylist('Downloads', playlistId: 2, playlistName: '下载');
    final config = await provider.getConfigByDirectory('Music');
    expect(config, isNotNull);
    expect(config!.directory, 'Music');
    expect(config.playlistId, 1);
  });

  test('removeConfig removes correct config', () async {
    await provider.addDirectoryWithPlaylist('Music', playlistId: 1, playlistName: 'Music');
    await provider.addDirectoryWithPlaylist('Downloads', playlistId: 2, playlistName: '下载');
    await provider.removeConfig('Music');
    final configs = await provider.getConfigs();
    expect(configs.length, 1);
    expect(configs.first.directory, 'Downloads');
  });

  test('migrates old string list to new config format', () async {
    // 先写入旧格式数据
    final db = await dbHelper.database;
    await db.insert(
      DatabaseHelper.tableSettings,
      {
        'key': 'scan_directories',
        'value': jsonEncode(['Music', 'Downloads']),
        'updated_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    // 创建新 provider 触发迁移
    final newProvider = ScanDirectoryProvider();
    final configs = await newProvider.getConfigs();
    expect(configs.length, 2);
    expect(configs.any((c) => c.directory == 'Music'), isTrue);
    expect(configs.any((c) => c.directory == 'Downloads'), isTrue);
  });
});
```

- [ ] **Step 2: 运行测试确认失败**

```bash
cd mysic_flutter && flutter test test/scan_directory_provider_test.dart
```

Expected: FAIL (方法不存在)

- [ ] **Step 3: 扩展 ScanDirectoryProvider**

修改 `lib/shared/utils/scan_directory_provider.dart`：

```dart
import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../../core/database/database_helper.dart';
import 'scan_directory_config.dart';

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

  /// 获取扫描目录列表（旧格式，兼容）
  Future<List<String>> getDirectories() async {
    final configs = await getConfigs();
    return configs.map((c) => c.directory).toList();
  }

  /// 获取目录配置列表
  Future<List<ScanDirectoryConfig>> getConfigs() async {
    final db = await _dbHelper.database;
    final result = await db.query(
      DatabaseHelper.tableSettings,
      where: 'key = ?',
      whereArgs: [_keyScanDirectories],
    );

    if (result.isEmpty) {
      return [];
    }

    final value = result.first['value'] as String;
    final List<dynamic> jsonList = jsonDecode(value);

    // 检测旧格式（纯字符串列表）并迁移
    if (jsonList.isNotEmpty && jsonList.first is String) {
      // 旧格式：返回空列表，等待迁移
      return [];
    }

    return jsonList
        .map((json) => ScanDirectoryConfig.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// 检测并迁移旧格式数据
  /// 返回迁移后的配置列表
  Future<List<ScanDirectoryConfig>> migrateIfNeeded() async {
    final db = await _dbHelper.database;
    final result = await db.query(
      DatabaseHelper.tableSettings,
      where: 'key = ?',
      whereArgs: [_keyScanDirectories],
    );

    if (result.isEmpty) {
      return [];
    }

    final value = result.first['value'] as String;
    final List<dynamic> jsonList = jsonDecode(value);

    // 检测旧格式（纯字符串列表）
    if (jsonList.isNotEmpty && jsonList.first is String) {
      // 迁移：转换为新格式（不关联歌单）
      final oldDirs = jsonList.cast<String>();
      final newConfigs = oldDirs
          .map((dir) => ScanDirectoryConfig(directory: dir))
          .toList();
      await _saveConfigs(newConfigs);
      return newConfigs;
    }

    return getConfigs();
  }

  /// 添加扫描目录（旧方法，兼容）
  Future<void> addDirectory(String directory) async {
    final trimmed = directory.trim();
    if (trimmed.isEmpty) return;

    final configs = List<ScanDirectoryConfig>.from(await getConfigs());
    if (!configs.any((c) => c.directory == trimmed)) {
      configs.add(ScanDirectoryConfig(directory: trimmed));
      await _saveConfigs(configs);
    }
  }

  /// 添加目录并关联歌单
  Future<void> addDirectoryWithPlaylist(
    String directory, {
    int? playlistId,
    String? playlistName,
  }) async {
    final trimmed = directory.trim();
    if (trimmed.isEmpty) return;

    final configs = List<ScanDirectoryConfig>.from(await getConfigs());
    final existingIndex = configs.indexWhere((c) => c.directory == trimmed);

    if (existingIndex != -1) {
      // 已存在，更新关联
      configs[existingIndex] = configs[existingIndex].copyWith(
        playlistId: playlistId,
        playlistName: playlistName,
      );
    } else {
      // 新增
      configs.add(ScanDirectoryConfig(
        directory: trimmed,
        playlistId: playlistId,
        playlistName: playlistName,
      ));
    }

    await _saveConfigs(configs);
  }

  /// 更新目录的歌单关联
  Future<void> updateDirectoryPlaylist(
    String directory,
    int playlistId,
    String playlistName,
  ) async {
    final configs = List<ScanDirectoryConfig>.from(await getConfigs());
    final index = configs.indexWhere((c) => c.directory == directory);

    if (index != -1) {
      configs[index] = configs[index].copyWith(
        playlistId: playlistId,
        playlistName: playlistName,
      );
      await _saveConfigs(configs);
    }
  }

  /// 根据目录名获取配置
  Future<ScanDirectoryConfig?> getConfigByDirectory(String directory) async {
    final configs = await getConfigs();
    return configs.cast<ScanDirectoryConfig?>().firstWhere(
      (c) => c?.directory == directory,
      orElse: () => null,
    );
  }

  /// 移除扫描目录（旧方法，兼容）
  Future<void> removeDirectory(String directory) async {
    await removeConfig(directory);
  }

  /// 移除目录配置
  Future<void> removeConfig(String directory) async {
    final configs = List<ScanDirectoryConfig>.from(await getConfigs());
    configs.removeWhere((c) => c.directory == directory);
    await _saveConfigs(configs);
  }

  /// 重置为默认目录
  Future<void> resetToDefault() async {
    final configs = kDefaultScanDirectories
        .map((dir) => ScanDirectoryConfig(directory: dir))
        .toList();
    await _saveConfigs(configs);
  }

  /// 保存配置列表到数据库
  Future<void> _saveConfigs(List<ScanDirectoryConfig> configs) async {
    final db = await _dbHelper.database;
    final now = DateTime.now().toIso8601String();
    final value = jsonEncode(configs.map((c) => c.toJson()).toList());

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

- [ ] **Step 4: 运行测试确认通过**

```bash
cd mysic_flutter && flutter test test/scan_directory_provider_test.dart
```

Expected: PASS

- [ ] **Step 5: 提交**

```bash
git add lib/shared/utils/scan_directory_provider.dart test/scan_directory_provider_test.dart
git commit -m "feat: 扩展 ScanDirectoryProvider 支持目录与歌单关联"
```

---

## Task 3: 修改扫描逻辑支持按目录添加到歌单

**Files:**
- Modify: `lib/features/settings/presentation/pages/scan_settings_page.dart`

- [ ] **Step 1: 修改 _startScan 方法**

在 `scan_settings_page.dart` 中，修改 `_startScan` 方法的扫描完成处理逻辑：

找到以下代码段（约第 397-405 行）：
```dart
if (mounted && result.isSuccess) {
  // 刷新 PlaylistProvider 数据
  final playlistProvider = context.read<PlaylistProvider>();
  await playlistProvider.refresh();

  // 确保"本地音乐"歌单存在并添加歌曲
  if (playlistProvider.allSongs.isNotEmpty) {
    await _ensureLocalMusicPlaylist(playlistProvider, result.newAdded);
  }
```

替换为：
```dart
if (mounted && result.isSuccess) {
  // 刷新 PlaylistProvider 数据
  final playlistProvider = context.read<PlaylistProvider>();
  await playlistProvider.refresh();

  // 将歌曲添加到各目录关联的歌单
  await _addSongsToLinkedPlaylists(playlistProvider);

  // 确保"本地音乐"歌单存在并添加所有歌曲（作为总览）
  if (playlistProvider.allSongs.isNotEmpty) {
    await _ensureLocalMusicPlaylist(playlistProvider, result.newAdded);
  }
```

- [ ] **Step 2: 添加 _addSongsToLinkedPlaylists 方法**

在 `_ensureLocalMusicPlaylist` 方法前添加：

```dart
/// 将扫描的歌曲添加到各目录关联的歌单
Future<void> _addSongsToLinkedPlaylists(PlaylistProvider playlistProvider) async {
  final directoryProvider = ScanDirectoryProvider();
  final configs = await directoryProvider.getConfigs();

  if (configs.isEmpty) return;

  // 获取所有歌曲
  final allSongs = playlistProvider.allSongs;
  if (allSongs.isEmpty) return;

  // 按目录分组添加歌曲
  for (final config in configs) {
    if (!config.isLinked) continue;

    final playlistId = config.playlistId;
    if (playlistId == null) continue;

    // 筛选该目录下的歌曲
    final directorySongs = allSongs.where((song) {
      final filePath = song.filePath.toLowerCase();
      final dirName = config.directory.toLowerCase();
      return filePath.contains('/$dirName/') ||
             filePath.contains('\\$dirName\\') ||
             filePath.contains('/$dirName\\') ||
             filePath.contains('\\$dirName/');
    }).toList();

    if (directorySongs.isNotEmpty) {
      await playlistProvider.addSongsToPlaylist(playlistId, directorySongs);
    }
  }
}
```

- [ ] **Step 3: 添加必要的 import**

确保文件顶部有：
```dart
import '../../../../shared/utils/scan_directory_provider.dart';
import '../../../../shared/utils/scan_directory_config.dart';
```

- [ ] **Step 4: 运行分析确认无错误**

```bash
cd mysic_flutter && flutter analyze lib/features/settings/presentation/pages/scan_settings_page.dart
```

Expected: No issues found

- [ ] **Step 5: 提交**

```bash
git add lib/features/settings/presentation/pages/scan_settings_page.dart
git commit -m "feat: 扫描后将歌曲添加到目录关联的歌单"
```

---

## Task 4: 修改目录列表 UI 显示关联状态

**Files:**
- Modify: `lib/features/settings/presentation/widgets/scan_directory_list.dart`

- [ ] **Step 1: 修改 _ScanDirectoryListState 状态**

将 `_directories` 从 `List<String>` 改为 `List<ScanDirectoryConfig>`：

```dart
// 修改状态变量
List<ScanDirectoryConfig> _configs = [];
bool _isLoading = true;
```

- [ ] **Step 2: 修改 _loadDirectories 方法**

```dart
Future<void> _loadDirectories() async {
  try {
    // 先尝试迁移旧数据
    await _provider.migrateIfNeeded();
    final configs = await _provider.getConfigs();
    if (mounted) {
      setState(() {
        _configs = configs;
        _isLoading = false;
      });
    }
  } on Exception catch (e) {
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('加载目录失败: $e')),
      );
    }
  }
}
```

- [ ] **Step 3: 修改目录列表显示**

找到 `_buildBody` 方法中的目录列表部分，修改为：

```dart
// 替换目录列表显示部分
if (_configs.isEmpty)
  Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(12),
    ),
    child: const Text(
      '暂无扫描目录，请添加',
      style: TextStyle(color: AppColors.muted),
      textAlign: TextAlign.center,
    ),
  )
else
  Container(
    decoration: BoxDecoration(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(12),
    ),
    child: ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _configs.length,
      separatorBuilder: (context, index) => const Divider(
        color: AppColors.surface,
        height: 1,
      ),
      itemBuilder: (context, index) {
        final config = _configs[index];
        return ListTile(
          title: Text(
            config.directory,
            style: const TextStyle(color: AppColors.white),
          ),
          trailing: _buildPlaylistTrailing(config),
          onTap: () => _showEditPlaylistDialog(config),
        );
      },
    ),
  ),
```

- [ ] **Step 4: 添加 _buildPlaylistTrailing 方法**

```dart
Widget _buildPlaylistTrailing(ScanDirectoryConfig config) {
  if (config.isLinked) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          config.playlistName!,
          style: const TextStyle(color: AppColors.accent, fontSize: 12),
        ),
        const SizedBox(width: 8),
        const Icon(Icons.link, color: AppColors.accent, size: 16),
      ],
    );
  } else {
    return Text(
      '未关联',
      style: TextStyle(color: AppColors.muted.withValues(alpha: 0.5), fontSize: 12),
    );
  }
}
```

- [ ] **Step 5: 修改 _addDirectory 方法**

```dart
Future<void> _addDirectory() async {
  final controller = TextEditingController();

  try {
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
      // 检查是否已存在
      if (_configs.any((c) => c.directory == result)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('该目录已存在')),
          );
        }
        return;
      }

      // 创建同名歌单
      final playlistProvider = context.read<PlaylistProvider>();
      final playlist = await playlistProvider.createPlaylist(
        name: result,
        description: '扫描目录 "$result" 自动创建',
      );

      if (playlist != null) {
        // 添加目录并关联歌单
        await _provider.addDirectoryWithPlaylist(
          result,
          playlistId: playlist.id,
          playlistName: playlist.name,
        );
        await _loadDirectories();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('已添加目录 "$result" 并创建歌单')),
          );
        }
      }
    }
  } on Exception catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('添加目录失败: $e')),
      );
    }
  } finally {
    controller.dispose();
  }
}
```

- [ ] **Step 6: 添加 _showEditPlaylistDialog 方法**

```dart
Future<void> _showEditPlaylistDialog(ScanDirectoryConfig config) async {
  final playlistProvider = context.read<PlaylistProvider>();

  final result = await showDialog<int>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: AppColors.surface,
      title: Text(
        '关联歌单: ${config.directory}',
        style: const TextStyle(color: AppColors.white),
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: playlistProvider.playlists.length,
          itemBuilder: (context, index) {
            final playlist = playlistProvider.playlists[index];
            final isSelected = playlist.id == config.playlistId;
            return ListTile(
              title: Text(
                playlist.name,
                style: TextStyle(
                  color: isSelected ? AppColors.accent : AppColors.white,
                ),
              ),
              trailing: isSelected
                  ? const Icon(Icons.check, color: AppColors.accent)
                  : null,
              onTap: () => Navigator.pop(context, playlist.id),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, -1), // -1 表示取消关联
          child: const Text('取消关联', style: TextStyle(color: AppColors.muted)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('关闭', style: TextStyle(color: AppColors.accent)),
        ),
      ],
    ),
  );

  if (result != null) {
    if (result == -1) {
      // 取消关联
      await _provider.updateDirectoryPlaylist(
        config.directory,
        0,
        '',
      );
      // 实际上是清除关联
      final configs = List<ScanDirectoryConfig>.from(await _provider.getConfigs());
      final index = configs.indexWhere((c) => c.directory == config.directory);
      if (index != -1) {
        configs[index] = configs[index].copyWith(clearPlaylist: true);
        await _provider.removeConfig(config.directory);
        await _provider.addDirectoryWithPlaylist(config.directory);
      }
    } else {
      // 更新关联
      final playlist = playlistProvider.playlists.firstWhere((p) => p.id == result);
      await _provider.updateDirectoryPlaylist(
        config.directory,
        result,
        playlist.name,
      );
    }
    await _loadDirectories();
  }
}
```

- [ ] **Step 7: 修改 _removeDirectory 方法**

```dart
Future<void> _removeDirectory(String directory) async {
  try {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text(
          '确认删除',
          style: TextStyle(color: AppColors.white),
        ),
        content: Text(
          '确定要删除目录 "$directory" 吗？\n关联的歌单将保留。',
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
      await _provider.removeConfig(directory);
      await _loadDirectories();
    }
  } on Exception catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('删除目录失败: $e')),
      );
    }
  }
}
```

- [ ] **Step 8: 添加必要的 imports**

确保文件顶部有：
```dart
import 'package:provider/provider.dart';
import '../../../../features/playlist/presentation/providers/playlist_provider.dart';
import '../../../../shared/utils/scan_directory_config.dart';
```

- [ ] **Step 9: 运行分析确认无错误**

```bash
cd mysic_flutter && flutter analyze lib/features/settings/presentation/widgets/scan_directory_list.dart
```

Expected: No issues found

- [ ] **Step 10: 提交**

```bash
git add lib/features/settings/presentation/widgets/scan_directory_list.dart
git commit -m "feat: 目录列表显示歌单关联状态，添加目录时自动创建歌单"
```

---

## Task 5: 集成测试

**Files:**
- Create: `test/integration/scan_directory_playlist_binding_test.dart`

- [ ] **Step 1: 编写集成测试**

```dart
// test/integration/scan_directory_playlist_binding_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:mysic_flutter/core/database/database_helper.dart';
import 'package:mysic_flutter/shared/utils/scan_directory_provider.dart';
import 'package:mysic_flutter/shared/utils/scan_directory_config.dart';
import 'package:mysic_flutter/features/playlist/data/playlist_repository.dart';
import 'package:mysic_flutter/features/playlist/presentation/providers/playlist_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('Scan Directory Playlist Binding Integration', () {
    late DatabaseHelper dbHelper;
    late ScanDirectoryProvider scanProvider;
    late PlaylistProvider playlistProvider;

    setUp(() async {
      dbHelper = DatabaseHelper();
      await dbHelper.deleteDatabase();
      scanProvider = ScanDirectoryProvider();
      playlistProvider = PlaylistProvider();
    });

    tearDown(() async {
      await dbHelper.close();
    });

    test('adding directory creates playlist and links them', () async {
      // 添加目录（模拟 UI 操作）
      final playlist = await playlistProvider.createPlaylist(name: 'Music');
      expect(playlist, isNotNull);

      await scanProvider.addDirectoryWithPlaylist(
        'Music',
        playlistId: playlist!.id,
        playlistName: playlist.name,
      );

      // 验证关联
      final configs = await scanProvider.getConfigs();
      expect(configs.length, 1);
      expect(configs.first.directory, 'Music');
      expect(configs.first.playlistId, playlist.id);
    });

    test('multiple directories can be linked to different playlists', () async {
      // 创建两个歌单
      final playlist1 = await playlistProvider.createPlaylist(name: 'Music');
      final playlist2 = await playlistProvider.createPlaylist(name: 'Downloads');

      // 关联目录
      await scanProvider.addDirectoryWithPlaylist(
        'Music',
        playlistId: playlist1!.id,
        playlistName: playlist1.name,
      );
      await scanProvider.addDirectoryWithPlaylist(
        'Downloads',
        playlistId: playlist2!.id,
        playlistName: playlist2.name,
      );

      // 验证
      final configs = await scanProvider.getConfigs();
      expect(configs.length, 2);

      final musicConfig = configs.firstWhere((c) => c.directory == 'Music');
      expect(musicConfig.playlistId, playlist1.id);

      final downloadsConfig = configs.firstWhere((c) => c.directory == 'Downloads');
      expect(downloadsConfig.playlistId, playlist2.id);
    });

    test('updating playlist link works correctly', () async {
      final playlist1 = await playlistProvider.createPlaylist(name: 'Music');
      final playlist2 = await playlistProvider.createPlaylist(name: 'NewMusic');

      await scanProvider.addDirectoryWithPlaylist(
        'Music',
        playlistId: playlist1!.id,
        playlistName: playlist1.name,
      );

      // 更新关联
      await scanProvider.updateDirectoryPlaylist(
        'Music',
        playlist2!.id,
        playlist2.name,
      );

      final config = await scanProvider.getConfigByDirectory('Music');
      expect(config!.playlistId, playlist2.id);
      expect(config.playlistName, 'NewMusic');
    });
  });
}
```

- [ ] **Step 2: 运行集成测试**

```bash
cd mysic_flutter && flutter test test/integration/scan_directory_playlist_binding_test.dart
```

Expected: PASS

- [ ] **Step 3: 提交**

```bash
git add test/integration/scan_directory_playlist_binding_test.dart
git commit -m "test: 添加目录歌单绑定集成测试"
```

---

## Task 6: 最终验证

- [ ] **Step 1: 运行所有测试**

```bash
cd mysic_flutter && flutter test
```

Expected: All tests pass

- [ ] **Step 2: 运行静态分析**

```bash
cd mysic_flutter && flutter analyze
```

Expected: No issues found

- [ ] **Step 3: 最终提交**

```bash
git add -A
git commit -m "feat: 完成扫描目录与歌单绑定功能"
```

---

## 自检清单

- [x] 设计文档覆盖所有需求
- [x] 每个任务都有明确的文件路径
- [x] 每个代码步骤都有完整代码
- [x] 测试覆盖数据模型、Provider、集成场景
- [x] 无 TBD/TODO 占位符
- [x] 方法签名在各任务间一致
