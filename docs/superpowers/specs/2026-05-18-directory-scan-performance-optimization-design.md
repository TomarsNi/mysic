# Android 目录扫描性能优化设计

> 日期：2026-05-18
> 状态：已批准

## 问题分析

### 现象

用户在 Android 上添加歌单时，选择文件夹扫描歌曲非常慢（500-1000 首歌曲规模）。

### 根因

`scanMusicInDirectory()` 方法在 `_saveMediaSongsToDatabase` 中逐个检查同名图片：

```dart
// mobile_music_scanner.dart:791-809
for (final ext in ['.jpg', '.jpeg', '.png', '.webp', '.gif']) {
  final imageFile = File('${dir.path}/${imageFileName}');
  if (await imageFile.exists()) {  // 每次都是异步 I/O
    sourceImagePath = imageFile.path;
    break;
  }
}
```

**瓶颈分析：**
- 每首歌最多 5 次 `File.exists()` I/O 操作
- 500 首歌 = 最多 2500 次 I/O 操作
- Android 文件系统 I/O 较慢

### 对比

`scanMusic()` 方法已经使用 `ImageCache` 预收集图片，但 `scanMusicInDirectory()` 没有使用。

## 解决方案

### 核心思路

复用已有的 `ImageCache` 机制，在 MediaStore 查询后预先收集图片文件。

### 优化后流程

```
用户选择目录
    ↓
MediaStore.querySongs(path)
    ↓
ImageCache.scanDirectory(path)  ← 新增：预收集图片
    ↓
_saveMediaSongsToDatabase()
    ├─ 用 ImageCache.findImagePath() 查找同名图片
    ├─ WAV 元数据提取（保持现有逻辑）
    └─ 批量插入数据库
    ↓
_processArtworksParallel()  ← 已有：并行提取封面
    ↓
返回新歌曲 ID
```

## 具体改动

### 1. 新增图片预收集步骤

**文件：** `lib/shared/utils/mobile_music_scanner.dart`

**位置：** `scanMusicInDirectory()` 方法，MediaStore 查询后

```dart
// 在 querySongs 后，_saveMediaSongsToDatabase 前
final imageCache = ImageCache();
await imageCache.scanDirectory(actualPath);
```

### 2. 修改 `_saveMediaSongsToDatabase` 方法

**文件：** `lib/shared/utils/mobile_music_scanner.dart`

**位置：** 同名图片查找逻辑（约第 791-809 行）

**当前代码：**
```dart
for (final ext in ['.jpg', '.jpeg', '.png', '.webp', '.gif']) {
  final imageFileName = '$nameWithoutExt$ext'.toLowerCase();
  final imageFile = File('${dir.path}${Platform.pathSeparator}$imageFileName');
  if (await imageFile.exists()) {
    sourceImagePath = imageFile.path;
    break;
  }
}
```

**优化后：**
```dart
final sourceImagePath = _imageCache?.findImagePath(
  dir.path,
  nameWithoutExt,
);
```

### 3. 传递 ImageCache 实例

需要将 `ImageCache` 实例传递给 `_saveMediaSongsToDatabase` 方法：

- 新增参数 `ImageCache? imageCache`
- 在方法内使用缓存查找同名图片

## 预期效果

| 操作 | 当前 | 优化后 |
|------|------|--------|
| 图片查找 I/O | 2500 次 | 1 次目录扫描 |
| 图片查找方式 | 逐个 File.exists() | 内存 Map 查找 |
| 预估时间减少 | - | 40-60% |

## 风险评估

- **改动量：** 小（约 20-30 行代码）
- **风险：** 低（复用已有机制，不影响其他功能）
- **回滚：** 容易（可快速恢复原有逻辑）

## 测试要点

1. 目录扫描功能正常（歌曲正确添加到歌单）
2. 同名图片封面正确提取
3. 内嵌封面正确提取
4. 无同名图片时使用 MediaStore 封面
5. 性能提升符合预期
