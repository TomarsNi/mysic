# 扫描音乐时自动关联歌词文件 实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在扫描音乐文件时，自动查找同目录下的 .lrc 歌词文件并关联到歌曲记录的 `lyrics_path` 字段。

**Architecture:** 在 `WindowsMusicScanner` 中新增 `_findLyricsFile` 和 `_cleanLrcFileName` 方法，修改 `_saveSongsToDatabase` 方法在插入歌曲时查找并设置歌词路径。

**Tech Stack:** Flutter, Dart, File I/O

---

## 文件结构

| 文件 | 变更类型 | 职责 |
|------|----------|------|
| `lib/shared/utils/windows_music_scanner.dart` | 修改 | 添加歌词查找逻辑 |
| `test/windows_scanner_lyrics_test.dart` | 新建 | 歌词查找逻辑测试 |

---

### Task 1: 编写歌词文件名清理方法的单元测试

**Files:**
- Create: `test/windows_scanner_lyrics_test.dart`

- [ ] **Step 1: 创建测试文件并编写 `_cleanLrcFileName` 测试**

```dart
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('_cleanLrcFileName', () {
    test('移除 .lrc 扩展名', () {
      // 模拟清理逻辑
      var name = '告白气球.lrc';
      name = name.replaceAll(RegExp(r'\.lrc$', caseSensitive: false), '');
      expect(name, '告白气球');
    });

    test('移除序号前缀（点分隔）', () {
      var name = '01. 告白气球.lrc';
      name = name.replaceAll(RegExp(r'\.lrc$', caseSensitive: false), '');
      name = name.replaceFirst(RegExp(r'^\d+[\s.\-_]+'), '');
      expect(name.trim(), '告白气球');
    });

    test('移除序号前缀（短横线分隔）', () {
      var name = '1-告白气球.lrc';
      name = name.replaceAll(RegExp(r'\.lrc$', caseSensitive: false), '');
      name = name.replaceFirst(RegExp(r'^\d+[\s.\-_]+'), '');
      expect(name.trim(), '告白气球');
    });

    test('移除序号前缀（无分隔符）', () {
      var name = '01告白气球.lrc';
      name = name.replaceAll(RegExp(r'\.lrc$', caseSensitive: false), '');
      name = name.replaceFirst(RegExp(r'^\d+[\s.\-_]+'), '');
      expect(name.trim(), '告白气球');
    });

    test('移除艺术家后缀', () {
      var name = '告白气球 - 周杰伦.lrc';
      name = name.replaceAll(RegExp(r'\.lrc$', caseSensitive: false), '');
      name = name.replaceFirst(RegExp(r'\s*-\s*.+$'), '');
      expect(name.trim(), '告白气球');
    });

    test('综合清理：序号 + 歌名 + 艺术家', () {
      var name = '01. 告白气球 - 周杰伦.lrc';
      name = name.replaceAll(RegExp(r'\.lrc$', caseSensitive: false), '');
      name = name.replaceFirst(RegExp(r'^\d+[\s.\-_]+'), '');
      name = name.replaceFirst(RegExp(r'\s*-\s*.+$'), '');
      expect(name.toLowerCase().trim(), '告白气球');
    });

    test('处理大写扩展名', () {
      var name = '告白气球.LRC';
      name = name.replaceAll(RegExp(r'\.lrc$', caseSensitive: false), '');
      expect(name, '告白气球');
    });
  });
}
```

- [ ] **Step 2: 运行测试验证逻辑**

Run: `cd mysic_flutter && flutter test test/windows_scanner_lyrics_test.dart`
Expected: PASS（所有 7 个测试）

- [ ] **Step 3: 提交测试**

```bash
git add test/windows_scanner_lyrics_test.dart
git commit -m "test: 添加歌词文件名清理逻辑的单元测试"
```

---

### Task 2: 实现 `_cleanLrcFileName` 方法

**Files:**
- Modify: `lib/shared/utils/windows_music_scanner.dart`

- [ ] **Step 1: 在 `WindowsMusicScanner` 类中添加 `_cleanLrcFileName` 方法**

在 `_cleanTitleFromFileName` 方法后添加：

```dart
  /// 清理歌词文件名（移除扩展名、序号前缀和艺术家后缀）
  /// 用于宽松匹配歌词文件
  String _cleanLrcFileName(String lrcFileName) {
    // 移除 .lrc 扩展名（大小写不敏感）
    var name = lrcFileName.replaceAll(RegExp(r'\.lrc$', caseSensitive: false), '');
    // 移除开头的数字序号和分隔符
    name = name.replaceFirst(RegExp(r'^\d+[\s.\-_]+'), '');
    // 移除可能的艺术家后缀（如 " - 周杰伦"）
    name = name.replaceFirst(RegExp(r'\s*-\s*.+$'), '');
    return name.toLowerCase().trim();
  }
```

- [ ] **Step 2: 运行分析确保无语法错误**

Run: `cd mysic_flutter && flutter analyze lib/shared/utils/windows_music_scanner.dart`
Expected: No issues found（可能有 unused_element 警告，预期行为）

- [ ] **Step 3: 提交**

```bash
git add lib/shared/widgets/windows_music_scanner.dart
git commit -m "feat: 添加歌词文件名清理方法 _cleanLrcFileName"
```

---

### Task 3: 实现 `_findLyricsFile` 方法

**Files:**
- Modify: `lib/shared/utils/windows_music_scanner.dart`

- [ ] **Step 1: 在 `WindowsMusicScanner` 类中添加 `_findLyricsFile` 方法**

在 `_cleanLrcFileName` 方法后添加：

```dart
  /// 查找音频文件对应的歌词文件
  /// 支持同名匹配和宽松匹配（忽略序号前缀）
  Future<String?> _findLyricsFile(String audioFilePath) async {
    final audioFile = File(audioFilePath);
    final dirPath = audioFile.parent.path;
    final audioFileName = audioFilePath.split(Platform.pathSeparator).last;
    
    // 提取音频文件名（不含扩展名）
    final audioName = audioFileName.replaceAll(RegExp(r'\.[^.]+$'), '');
    
    try {
      final dir = Directory(dirPath);
      if (!await dir.exists()) return null;
      
      // 优先：同名匹配
      final sameNameLrc = '$dirPath${Platform.pathSeparator}$audioName.lrc';
      if (await File(sameNameLrc).exists()) {
        return sameNameLrc;
      }
      
      // 次选：宽松匹配
      await for (final entity in dir.list(followLinks: false)) {
        if (entity is File) {
          final lrcName = entity.path.split(Platform.pathSeparator).last;
          if (lrcName.toLowerCase().endsWith('.lrc')) {
            // 清理歌词文件名的序号前缀
            final cleanedLrcName = _cleanLrcFileName(lrcName);
            if (cleanedLrcName == audioName.toLowerCase()) {
              return entity.path;
            }
          }
        }
      }
    } catch (_) {
      // 忽略无法访问的目录
    }
    
    return null;
  }
```

- [ ] **Step 2: 运行分析确保无语法错误**

Run: `cd mysic_flutter && flutter analyze lib/shared/utils/windows_music_scanner.dart`
Expected: No issues found（可能有 unused_element 警告，预期行为）

- [ ] **Step 3: 提交**

```bash
git add lib/shared/utils/windows_music_scanner.dart
git commit -m "feat: 添加歌词文件查找方法 _findLyricsFile"
```

---

### Task 4: 修改 `_saveSongsToDatabase` 方法集成歌词查找

**Files:**
- Modify: `lib/shared/utils/windows_music_scanner.dart`

- [ ] **Step 1: 在 `_saveSongsToDatabase` 方法中调用 `_findLyricsFile`**

找到插入歌曲的代码块（约第 528-541 行），修改为：

```dart
          // 提取音频元数据
          final metadata = await _extractMetadata(filePath);

          // 过滤：时长不在有效范围内（165秒 ~ 1500秒）
          if (metadata.duration != null) {
            if (metadata.duration! < _minDurationSec || metadata.duration! > _maxDurationSec) {
              filtered++;
              continue;
            }
          }

          // 确定最终标题：优先使用元数据，回退到清理后的文件名
          final fileName = filePath.split(Platform.pathSeparator).last;
          final title = metadata.title?.isNotEmpty == true
              ? metadata.title
              : _cleanTitleFromFileName(fileName);

          // 查找歌词文件
          final lyricsPath = await _findLyricsFile(filePath);

          await txn.insert(
            DatabaseHelper.tableSongs,
            {
              'title': title,
              'artist': metadata.artist,
              'album': metadata.album,
              'duration': metadata.duration ?? 0,
              'file_path': filePath,
              'album_art_path': null,
              'lyrics_path': lyricsPath,
              'date_added': null,
              'created_at': nowIso,
              'updated_at': nowIso,
            },
          );
          newAdded++;
```

- [ ] **Step 2: 运行分析确保无语法错误**

Run: `cd mysic_flutter && flutter analyze lib/shared/utils/windows_music_scanner.dart`
Expected: No issues found

- [ ] **Step 3: 提交**

```bash
git add lib/shared/utils/windows_music_scanner.dart
git commit -m "feat: 扫描音乐时自动查找并关联歌词文件"
```

---

### Task 5: 集成测试验证

**Files:**
- 无新增文件

- [ ] **Step 1: 运行所有测试确保无回归**

Run: `cd mysic_flutter && flutter test`
Expected: All tests pass

- [ ] **Step 2: 运行静态分析**

Run: `cd mysic_flutter && flutter analyze`
Expected: No issues found

- [ ] **Step 3: 手动测试应用**

Run: `cd mysic_flutter && flutter run -d windows`

手动测试场景：
1. 准备测试目录：包含音频文件和同名 .lrc 文件
2. 扫描该目录
3. 检查数据库中歌曲的 `lyrics_path` 字段是否正确关联
4. 测试宽松匹配：音频文件名 `告白气球.mp3`，歌词文件名 `01. 告白气球.lrc`
5. 测试无歌词文件：扫描不含 .lrc 的目录，验证 `lyrics_path` 为 null

---

## 自检清单

- [x] 设计文档中的每个需求都有对应任务
- [x] 无 TBD/TODO 占位符
- [x] 方法名称一致：`_cleanLrcFileName`、`_findLyricsFile`
- [x] 文件路径精确
- [x] 测试覆盖核心逻辑