# 删除歌曲时同时删除原文件功能实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在删除歌曲确认弹窗中新增「同时删除原文件」选项，用户勾选后记住状态并执行文件删除。

**Architecture:** 使用 SharedPreferences 存储用户偏好，修改 PlaylistProvider 支持删除文件，更新 UI 组件添加勾选框。

**Tech Stack:** Flutter, Dart, SharedPreferences, dart:io

---

## 文件结构

| 文件 | 责任 |
|------|------|
| `lib/core/utils/file_utils.dart` | 文件删除工具类（新建） |
| `lib/features/settings/data/delete_preference.dart` | 删除偏好存储（新建） |
| `lib/features/playlist/presentation/providers/playlist_provider.dart` | 扩展 deleteSong 方法 |
| `lib/main.dart` | 修改 _DeleteConfirmSheet 组件 |
| `test/core/utils/file_utils_test.dart` | 文件删除工具测试（新建） |
| `test/features/settings/data/delete_preference_test.dart` | 删除偏好测试（新建） |

---

### Task 1: 创建文件删除工具类

**Files:**
- Create: `lib/core/utils/file_utils.dart`
- Create: `test/core/utils/file_utils_test.dart`

- [ ] **Step 1: 创建文件删除工具类**

```dart
// lib/core/utils/file_utils.dart
import 'dart:io';

/// 文件操作工具类
class FileUtils {
  /// 删除文件
  /// 静默处理错误，不抛出异常
  /// 返回 true 表示删除成功，false 表示文件不存在或删除失败
  static Future<bool> deleteFile(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        return true;
      }
      // 文件不存在，视为成功（幂等）
      return false;
    } catch (e) {
      // 文件删除失败不阻塞流程，仅记录日志
      debugPrint('删除文件失败: $e');
      return false;
    }
  }
}
```

- [ ] **Step 2: 创建文件删除工具测试**

```dart
// test/core/utils/file_utils_test.dart
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mysic_flutter/core/utils/file_utils.dart';

void main() {
  group('FileUtils', () {
    test('删除存在的文件', () async {
      // 创建临时文件
      final tempDir = await Directory.systemTemp.createTemp('file_utils_test_');
      final tempFile = File('${tempDir.path}/test.txt');
      await tempFile.writeAsString('test content');

      expect(await tempFile.exists(), isTrue);

      // 删除文件
      final result = await FileUtils.deleteFile(tempFile.path);
      expect(result, isTrue);
      expect(await tempFile.exists(), isFalse);

      // 清理
      await tempDir.delete(recursive: true);
    });

    test('删除不存在的文件返回 false', () async {
      final result = await FileUtils.deleteFile('/non/existent/file.txt');
      expect(result, isFalse);
    });
  });
}
```

- [ ] **Step 3: 运行测试验证**

Run: `cd mysic_flutter && flutter test test/core/utils/file_utils_test.dart`
Expected: PASS

- [ ] **Step 4: 提交**

```bash
cd mysic_flutter
git add lib/core/utils/file_utils.dart test/core/utils/file_utils_test.dart
git commit -m "feat: 添加文件删除工具类 FileUtils"
```

---

### Task 2: 创建删除偏好存储类

**Files:**
- Create: `lib/features/settings/data/delete_preference.dart`
- Create: `test/features/settings/data/delete_preference_test.dart`

- [ ] **Step 1: 创建删除偏好存储类**

```dart
// lib/features/settings/data/delete_preference.dart
import 'package:shared_preferences/shared_preferences.dart';

/// 删除操作偏好设置
/// 用于存储用户在删除确认弹窗中的勾选状态
class DeletePreference {
  static const _keyDeleteWithFile = 'delete_song_with_file';

  /// 获取是否同时删除文件
  /// 默认为 false（不同时删除）
  static Future<bool> getDeleteWithFile() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyDeleteWithFile) ?? false;
  }

  /// 设置是否同时删除文件
  static Future<void> setDeleteWithFile(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyDeleteWithFile, value);
  }
}
```

- [ ] **Step 2: 创建删除偏好测试**

```dart
// test/features/settings/data/delete_preference_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mysic_flutter/features/settings/data/delete_preference.dart';

void main() {
  group('DeletePreference', () {
    setUp(() async {
      // 初始化测试用的 SharedPreferences
      SharedPreferences.setMockInitialValues({});
    });

    test('默认值为 false', () async {
      final value = await DeletePreference.getDeleteWithFile();
      expect(value, isFalse);
    });

    test('设置后可正确读取', () async {
      await DeletePreference.setDeleteWithFile(true);
      final value = await DeletePreference.getDeleteWithFile();
      expect(value, isTrue);
    });

    test('可以修改回 false', () async {
      await DeletePreference.setDeleteWithFile(true);
      expect(await DeletePreference.getDeleteWithFile(), isTrue);

      await DeletePreference.setDeleteWithFile(false);
      expect(await DeletePreference.getDeleteWithFile(), isFalse);
    });
  });
}
```

- [ ] **Step 3: 运行测试验证**

Run: `cd mysic_flutter && flutter test test/features/settings/data/delete_preference_test.dart`
Expected: PASS

- [ ] **Step 4: 提交**

```bash
cd mysic_flutter
git add lib/features/settings/data/delete_preference.dart test/features/settings/data/delete_preference_test.dart
git commit -m "feat: 添加删除偏好存储类 DeletePreference"
```

---

### Task 3: 扩展 PlaylistProvider 支持删除文件

**Files:**
- Modify: `lib/features/playlist/presentation/providers/playlist_provider.dart`
- Modify: `test/playlist_provider_test.dart`

- [ ] **Step 1: 修改 PlaylistProvider 的 deleteSong 方法**

在 `lib/features/playlist/presentation/providers/playlist_provider.dart` 文件顶部添加导入：

```dart
import '../../../core/utils/file_utils.dart';
```

修改 `deleteSong` 方法（约第 305 行）：

```dart
/// 删除歌曲
/// [songId] 歌曲 ID
/// [deleteFile] 是否同时删除文件系统中的原文件
Future<bool> deleteSong(int songId, {bool deleteFile = false}) async {
  try {
    // 如果需要删除文件，先获取歌曲信息
    if (deleteFile) {
      final song = await _repository.getSongById(songId);
      if (song != null) {
        await FileUtils.deleteFile(song.filePath);
      }
    }

    final success = await _repository.deleteSong(songId);
    if (success) {
      _allSongs.removeWhere((s) => s.id == songId);
      _playHistory.removeWhere((s) => s.id == songId);
      // 从所有歌单中移除
      for (var i = 0; i < _playlists.length; i++) {
        if (_playlists[i].songs != null) {
          final updatedSongs = _playlists[i].songs!
              .where((s) => s.id != songId)
              .toList();
          _playlists[i] = _playlists[i].copyWith(songs: updatedSongs);
        }
      }
      if (_selectedPlaylistSongs.any((s) => s.id == songId)) {
        _selectedPlaylistSongs.removeWhere((s) => s.id == songId);
      }
      notifyListeners();
    }
    return success;
  } catch (e) {
    _setError('删除歌曲失败: $e');
    return false;
  }
}
```

- [ ] **Step 2: 添加测试用例**

在 `test/playlist_provider_test.dart` 的删除歌曲测试后添加：

```dart
test('删除歌曲时可以选择同时删除文件', () async {
  final song = await provider.saveSong(createTestSong('歌曲A'));
  expect(song, isNotNull);

  // 注意：这里只测试数据库删除逻辑
  // 文件删除由 FileUtils 单独测试
  final success = await provider.deleteSong(song!.id!, deleteFile: true);

  expect(success, isTrue);
  expect(provider.allSongs, isEmpty);
});
```

- [ ] **Step 3: 运行测试验证**

Run: `cd mysic_flutter && flutter test test/playlist_provider_test.dart`
Expected: PASS

- [ ] **Step 4: 提交**

```bash
cd mysic_flutter
git add lib/features/playlist/presentation/providers/playlist_provider.dart test/playlist_provider_test.dart
git commit -m "feat: PlaylistProvider.deleteSong 支持 deleteFile 参数"
```

---

### Task 4: 修改删除确认弹窗 UI

**Files:**
- Modify: `lib/main.dart`

- [ ] **Step 1: 添加导入**

在 `lib/main.dart` 文件顶部添加导入：

```dart
import 'features/settings/data/delete_preference.dart';
```

- [ ] **Step 2: 修改 _DeleteConfirmSheet 为 StatefulWidget**

找到 `_DeleteConfirmSheet` 类（约第 1322 行），替换为：

```dart
/// 删除确认 BottomSheet
class _DeleteConfirmSheet extends StatefulWidget {
  final Song song;
  final void Function(bool deleteWithFile) onConfirm;

  const _DeleteConfirmSheet({
    required this.song,
    required this.onConfirm,
  });

  @override
  State<_DeleteConfirmSheet> createState() => _DeleteConfirmSheetState();
}

class _DeleteConfirmSheetState extends State<_DeleteConfirmSheet> {
  bool _deleteWithFile = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPreference();
  }

  Future<void> _loadPreference() async {
    final value = await DeletePreference.getDeleteWithFile();
    if (mounted) {
      setState(() {
        _deleteWithFile = value;
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleDeleteWithFile(bool value) async {
    setState(() {
      _deleteWithFile = value;
    });
    await DeletePreference.setDeleteWithFile(value);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF27272A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 拖拽指示条
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFF71717A),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),

          // 警告图标
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: const Color(0xFFEF4444).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(32),
            ),
            child: const Icon(
              Icons.warning_rounded,
              color: Color(0xFFEF4444),
              size: 32,
            ),
          ),
          const SizedBox(height: 16),

          // 标题
          const Text(
            '确认删除歌曲？',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),

          // 歌曲名称
          Text(
            widget.song.title,
            style: const TextStyle(
              color: Color(0xFF71717A),
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),

          // 同时删除文件勾选框
          if (!_isLoading)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF3F3F46),
                borderRadius: BorderRadius.circular(12),
              ),
              child: CheckboxListTile(
                value: _deleteWithFile,
                onChanged: (value) => _toggleDeleteWithFile(value ?? false),
                title: const Text(
                  '同时删除原文件',
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
                subtitle: const Text(
                  '文件删除后无法恢复',
                  style: TextStyle(color: Color(0xFF71717A), fontSize: 12),
                ),
                activeColor: const Color(0xFFEF4444),
                checkColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),

          // 警告提示
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFEF4444).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _deleteWithFile
                  ? '歌曲和原文件都将被删除，且无法恢复'
                  : '删除后歌曲将从所有歌单移除，且不会在下次扫描时重新添加',
              style: const TextStyle(
                color: Color(0xFFEF4444),
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 24),

          // 操作按钮
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    backgroundColor: const Color(0xFF3F3F46),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    '算了吧',
                    style: TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    widget.onConfirm(_deleteWithFile);
                  },
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    backgroundColor: const Color(0xFFEF4444),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    '删了吧',
                    style: TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 3: 修改调用处**

找到 `_showDeleteConfirmSheet` 方法（约第 836 行），修改为：

```dart
void _showDeleteConfirmSheet(BuildContext context, Song song) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => _DeleteConfirmSheet(
      song: song,
      onConfirm: (deleteWithFile) async {
        final playerProvider = context.read<PlayerProvider>();
        final playlistProvider = context.read<PlaylistProvider>();

        // 删除歌曲
        await playlistProvider.deleteSong(
          song.id!,
          deleteFile: deleteWithFile,
        );

        // 刷新歌单数据
        await playlistProvider.refresh();

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                deleteWithFile ? '歌曲和原文件已删除' : '歌曲已删除',
              ),
              backgroundColor: const Color(0xFF10B981),
            ),
          );
        }
      },
    ),
  );
}
```

- [ ] **Step 4: 运行分析验证**

Run: `cd mysic_flutter && flutter analyze lib/main.dart`
Expected: No issues found

- [ ] **Step 5: 提交**

```bash
cd mysic_flutter
git add lib/main.dart
git commit -m "feat: 删除确认弹窗添加「同时删除原文件」选项"
```

---

### Task 5: 集成测试验证

**Files:**
- Modify: `test/widgets/bottom_sheet_test.dart`

- [ ] **Step 1: 添加删除确认弹窗测试**

在 `test/widgets/bottom_sheet_test.dart` 末尾添加：

```dart
group('_DeleteConfirmSheet', () {
  testWidgets('显示删除确认弹窗和勾选框', (tester) async {
    final song = Song(
      id: 1,
      title: '测试歌曲',
      artist: '测试艺术家',
      filePath: '/test/path.mp3',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    bool? resultDeleteWithFile;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: _DeleteConfirmSheet(
            song: song,
            onConfirm: (deleteWithFile) {
              resultDeleteWithFile = deleteWithFile;
            },
          ),
        ),
      ),
    );

    // 等待异步加载完成
    await tester.pumpAndSettle();

    // 验证标题显示
    expect(find.text('确认删除歌曲？'), findsOneWidget);
    expect(find.text('测试歌曲'), findsOneWidget);
    expect(find.text('同时删除原文件'), findsOneWidget);
  });
});
```

- [ ] **Step 2: 运行测试验证**

Run: `cd mysic_flutter && flutter test test/widgets/bottom_sheet_test.dart`
Expected: PASS

- [ ] **Step 3: 运行完整测试套件**

Run: `cd mysic_flutter && flutter test`
Expected: All tests PASS

- [ ] **Step 4: 提交**

```bash
cd mysic_flutter
git add test/widgets/bottom_sheet_test.dart
git commit -m "test: 添加删除确认弹窗测试"
```

---

### Task 6: 最终验证和文档更新

- [ ] **Step 1: 运行完整分析**

Run: `cd mysic_flutter && flutter analyze`
Expected: No issues found

- [ ] **Step 2: 运行完整测试**

Run: `cd mysic_flutter && flutter test`
Expected: All tests PASS

- [ ] **Step 3: 本地运行验证**

Run: `cd mysic_flutter && flutter run -d windows`
手动测试：
1. 扫描歌曲
2. 点击加号菜单 -> 删除
3. 验证勾选框显示
4. 勾选后删除，验证文件被删除
5. 再次打开删除弹窗，验证勾选状态保持

- [ ] **Step 4: 最终提交**

```bash
cd mysic_flutter
git add -A
git commit -m "feat: 完成删除歌曲时同时删除原文件功能"
```
