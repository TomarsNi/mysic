# Android 目录扫描性能优化实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 优化 `scanMusicInDirectory()` 方法的同名图片查找性能，减少 40-60% 扫描时间。

**Architecture:** 在 MediaStore 查询后预先扫描目录收集图片文件到 `ImageCache`，然后用缓存查找替代逐个 `File.exists()` 检查。

**Tech Stack:** Dart, Flutter, sqflite, on_audio_query

---

## 文件结构

| 文件 | 操作 | 说明 |
|------|------|------|
| `lib/shared/utils/mobile_music_scanner.dart` | 修改 | 添加图片预收集逻辑，修改同名图片查找 |

---

### Task 1: 添加图片预收集方法

**Files:**
- Modify: `lib/shared/utils/mobile_music_scanner.dart`

- [ ] **Step 1: 添加 `_scanDirectoryForImages` 方法**

在 `_isImageFile` 方法后（约第 99 行后）添加新方法：

```dart
/// 扫描目录收集图片文件到缓存
/// 用于 scanMusicInDirectory 的图片预收集
Future<void> _scanDirectoryForImages(String directory) async {
  final dir = Directory(directory);
  if (!await dir.exists()) {
    debugPrint('目录不存在: $directory');
    return;
  }

  final imageFiles = <String, String>{};

  try {
    final entities = dir.list(recursive: true);
    await for (final entity in entities) {
      if (isCancelled) break;

      if (entity is File) {
        final extension = entity.path.toLowerCase();
        if (_isImageFile(extension)) {
          final fileName = entity.path.split(Platform.pathSeparator).last;
          imageFiles[fileName.toLowerCase()] = entity.path;
        }
      }
    }

    _imageCache.addDirectory(directory, imageFiles);
    debugPrint('图片预收集完成: 目录=$directory, 图片数=${imageFiles.length}');
  } catch (e) {
    debugPrint('图片预收集失败: $directory, 错误=$e');
  }
}
```

- [ ] **Step 2: 运行静态分析**

Run: `cd F:/opc/mysic/mysic_flutter && flutter analyze lib/shared/utils/mobile_music_scanner.dart`
Expected: No errors

- [ ] **Step 3: Commit**

```bash
git add mysic_flutter/lib/shared/utils/mobile_music_scanner.dart
git commit -m "feat(scanner): 添加图片预收集方法 _scanDirectoryForImages

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

### Task 2: 在 scanMusicInDirectory 中调用图片预收集

**Files:**
- Modify: `lib/shared/utils/mobile_music_scanner.dart:658-670`

- [ ] **Step 1: 清空图片缓存并调用预收集**

找到 `scanMusicInDirectory` 方法中 `_saveMediaSongsToDatabase` 调用前的位置（约第 658-670 行），修改代码：

**当前代码（约第 658-670 行）：**
```dart
      final totalFound = mediaSongs.length;
      updateProgress(ScanProgress(
        currentPath: '正在保存...',
        filesScanned: totalFound,
        songsFound: totalFound,
        progress: 0.95,
      ));

      updateState(ScanState.saving);

      // 保存到数据库
      final result = await _saveMediaSongsToDatabase(mediaSongs, actualPath);
```

**修改后：**
```dart
      final totalFound = mediaSongs.length;
      updateProgress(ScanProgress(
        currentPath: '正在收集图片...',
        filesScanned: totalFound,
        songsFound: totalFound,
        progress: 0.7,
      ));

      // 预收集图片文件到缓存（优化同名图片查找性能）
      _imageCache.clear();
      await _scanDirectoryForImages(actualPath);

      updateProgress(ScanProgress(
        currentPath: '正在保存...',
        filesScanned: totalFound,
        songsFound: totalFound,
        progress: 0.95,
      ));

      updateState(ScanState.saving);

      // 保存到数据库
      final result = await _saveMediaSongsToDatabase(mediaSongs, actualPath);
```

- [ ] **Step 2: 运行静态分析**

Run: `cd F:/opc/mysic/mysic_flutter && flutter analyze lib/shared/utils/mobile_music_scanner.dart`
Expected: No errors

- [ ] **Step 3: Commit**

```bash
git add mysic_flutter/lib/shared/utils/mobile_music_scanner.dart
git commit -m "feat(scanner): 在目录扫描中添加图片预收集步骤

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

### Task 3: 修改同名图片查找逻辑

**Files:**
- Modify: `lib/shared/utils/mobile_music_scanner.dart:791-809`

- [ ] **Step 1: 替换同名图片查找逻辑**

找到 `_saveMediaSongsToDatabase` 方法中的同名图片查找逻辑（约第 791-809 行），替换为使用缓存：

**当前代码：**
```dart
          // 查找同名图片（优先于 MediaStore 封面）
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

**修改后：**
```dart
          // 查找同名图片（优先于 MediaStore 封面）
          // 使用 ImageCache 快速查找，避免逐个 File.exists() I/O 操作
          final sourceImagePath = _imageCache.findImagePath(filePath);
          if (sourceImagePath != null) {
            debugPrint('找到同名图片: $sourceImagePath');
          }
```

- [ ] **Step 2: 运行静态分析**

Run: `cd F:/opc/mysic/mysic_flutter && flutter analyze lib/shared/utils/mobile_music_scanner.dart`
Expected: No errors

- [ ] **Step 3: Commit**

```bash
git add mysic_flutter/lib/shared/utils/mobile_music_scanner.dart
git commit -m "perf(scanner): 使用 ImageCache 替代逐个 File.exists 查找同名图片

- 移除事务内的异步 I/O 操作
- 使用内存缓存快速查找同名图片
- 预估性能提升 40-60%

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

### Task 4: 验证和测试

**Files:**
- Test: 手动测试

- [ ] **Step 1: 运行完整静态分析**

Run: `cd F:/opc/mysic/mysic_flutter && flutter analyze`
Expected: No errors

- [ ] **Step 2: 构建验证**

Run: `cd F:/opc/mysic/mysic_flutter && flutter build apk --debug`
Expected: Build success

- [ ] **Step 3: 手动测试清单**

在 Android 设备上测试以下场景：

1. **目录扫描功能**
   - 选择包含音频文件的目录
   - 验证歌曲正确添加到歌单
   - 验证扫描时间明显缩短

2. **同名图片封面**
   - 选择包含同名图片文件的目录（如 `song.mp3` + `song.jpg`）
   - 验证封面正确显示

3. **内嵌封面**
   - 选择包含内嵌封面的音频文件
   - 验证封面正确显示

4. **无封面情况**
   - 选择无同名图片、无内嵌封面的音频文件
   - 验证使用 MediaStore 封面或显示默认封面

- [ ] **Step 4: 最终 Commit**

```bash
git add -A
git commit -m "test(scanner): 验证目录扫描性能优化

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## 预期效果

| 指标 | 优化前 | 优化后 |
|------|--------|--------|
| 图片查找 I/O | 最多 2500 次 | 1 次目录扫描 |
| 查找方式 | File.exists() | 内存 Map |
| 预估时间减少 | - | 40-60% |

## 回滚方案

如果出现问题，可以通过以下命令回滚：

```bash
git revert HEAD~3  # 回滚 Task 1-3 的提交
```
