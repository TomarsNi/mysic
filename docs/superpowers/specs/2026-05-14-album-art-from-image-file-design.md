# 同名图片文件封面获取策略设计

## 概述

扫描音频文件时，在同级目录查找同名图片文件，将路径存入 `albumArtPath` 字段，作为封面显示的优先来源。

## 需求

- 支持格式：`.jpg`、`.png`、`.webp`、`.gif`
- 匹配规则：严格同名（`song.mp3` 匹配 `song.jpg`，不匹配 `song-cover.jpg`）
- 格式优先级：jpg > png > webp > gif
- 应用范围：所有扫描方式（全盘扫描、扫描指定文件夹）
- 平台支持：Windows、Linux、Android、iOS

## 封面显示优先级

`AlbumCover` 组件的显示优先级：

1. **同名图片文件**（`albumArtPath`）— 最高优先
2. **内嵌封面**（`albumArtBase64`）— 备选
3. **默认封面**（渐变背景 + 音乐图标）

## 架构设计

### 新增组件

**ImageCache**（`lib/shared/utils/image_cache.dart`）

```
┌─────────────────────────────────────────────────────┐
│                    ImageCache                        │
├─────────────────────────────────────────────────────┤
│ - _cache: Map<String, Map<String, String>>          │
├─────────────────────────────────────────────────────┤
│ + addDirectory(directory, images)                   │
│ + findImagePath(audioFilePath): String?             │
│ + clear()                                           │
└─────────────────────────────────────────────────────┘
```

- 缓存结构：`目录路径 -> {文件名 -> 图片完整路径}`
- 查找时按格式优先级返回最高优先级的匹配

### 扫描流程变更

```
阶段1：文件发现
├── 扫描目录
├── 收集音频文件
├── 收集歌词文件 → LyricsCache
└── 收集图片文件 → ImageCache  [新增]

阶段2：元数据提取
├── 提取音频元数据
├── 查找歌词路径 → LyricsCache
└── 查找封面路径 → ImageCache  [新增]

阶段3：保存数据库
└── 写入 album_art_path 字段  [新增]
```

## 文件变更清单

| 文件 | 变更类型 | 说明 |
|------|----------|------|
| `lib/shared/utils/image_cache.dart` | 新增 | 图片缓存类 |
| `lib/shared/utils/windows_music_scanner.dart` | 修改 | 集成 ImageCache |
| `lib/shared/utils/mobile_music_scanner.dart` | 修改 | 集成 ImageCache |
| `test/music_scanner_test.dart` | 修改 | 新增测试用例 |

## 详细实现

### ImageCache 类

```dart
/// 图片文件缓存
/// 用于扫描过程中缓存发现的图片文件，支持按音频文件名查找同名图片
class ImageCache {
  /// 目录路径 -> {文件名（不含扩展名） -> 图片文件完整路径}
  final Map<String, Map<String, String>> _cache = {};

  /// 支持的图片格式（按优先级排序）
  static const _extensions = ['.jpg', '.jpeg', '.png', '.webp', '.gif'];

  /// 添加目录下的图片到缓存
  void addDirectory(String directory, Map<String, String> images) {
    _cache[directory] = images;
  }

  /// 查找音频文件对应的图片路径
  /// 返回优先级最高的匹配图片路径，无匹配返回 null
  String? findImagePath(String audioFilePath) {
    final file = File(audioFilePath);
    final directory = file.parent.path;
    final fileName = file.uri.pathSegments.last;
    final nameWithoutExt = fileName.replaceAll(RegExp(r'\.[^.]+$'), '');

    final images = _cache[directory];
    if (images == null) return null;

    // 按优先级查找
    for (final ext in _extensions) {
      final key = '$nameWithoutExt$ext'.toLowerCase();
      if (images.containsKey(key)) {
        return images[key];
      }
    }
    return null;
  }

  /// 清空缓存
  void clear() {
    _cache.clear();
  }
}
```

### WindowsMusicScanner 变更

1. **新增成员变量**

```dart
final ImageCache _imageCache = ImageCache();
```

2. **修改 `_scanDirectoryRecursive`**

在收集歌词文件的逻辑后，新增图片文件收集：

```dart
// 收集当前目录的图片文件
final imageFiles = <String, String>{};

await for (final entity in dir.list(followLinks: false)) {
  // ... 现有代码 ...

  // 新增：检查是否是图片文件
  if (_isImageFile(extension)) {
    final fileName = entity.path.split(Platform.pathSeparator).last;
    imageFiles[fileName.toLowerCase()] = entity.path;
    continue;
  }
}

// 将图片文件添加到缓存
_imageCache.addDirectory(path, imageFiles);
```

3. **新增辅助方法**

```dart
bool _isImageFile(String extension) {
  const imageExts = ['.jpg', '.jpeg', '.png', '.webp', '.gif'];
  return imageExts.any((ext) => extension.endsWith(ext));
}
```

4. **修改 `_AudioMetadata` 类**

```dart
class _AudioMetadata {
  // ... 现有字段 ...
  String? albumArtPath;  // 新增
}
```

5. **修改 `_extractMetadataParallel`**

```dart
// 为每个结果添加封面路径
for (var j = 0; j < batchResults.length; j++) {
  final lyricsPath = _lyricsCache.findLyricsPath(batch[j]);
  batchResults[j].lyricsPath = lyricsPath;

  // 新增：查找封面路径
  final albumArtPath = _imageCache.findImagePath(batch[j]);
  batchResults[j].albumArtPath = albumArtPath;
}
```

6. **修改 `_saveSongsToDatabase`**

```dart
songsToInsert.add({
  // ... 现有字段 ...
  'album_art_path': metadata.albumArtPath,  // 新增
});
```

### MobileMusicScanner 变更

与 WindowsMusicScanner 类似的修改：

1. 新增 `ImageCache` 成员变量
2. 在扫描过程中收集图片文件
3. 在元数据提取阶段查找封面路径
4. 保存时写入 `album_art_path` 字段

**Android 特殊处理**：
- 使用 `on_audio_query` 获取媒体文件列表
- 通过文件系统 API 访问同名图片

**iOS 特殊处理**：
- 沙盒限制，仅能访问应用目录内的文件
- 需要用户授权访问音乐库

## 测试用例

### 单元测试

1. **同名 jpg 图片被正确匹配**
   - 输入：`/music/song.mp3`，目录下存在 `song.jpg`
   - 期望：返回 `song.jpg` 的完整路径

2. **多格式共存时按优先级选择**
   - 输入：`/music/song.mp3`，目录下存在 `song.png` 和 `song.gif`
   - 期望：返回 `song.png` 的路径（png > gif）

3. **无同名图片时返回 null**
   - 输入：`/music/song.mp3`，目录下无同名图片
   - 期望：返回 `null`

4. **不同目录同名文件不混淆**
   - 输入：`/music/album1/song.mp3` 和 `/music/album2/song.mp3`
   - 期望：各自返回对应目录下的图片

5. **取消扫描时缓存正确清理**
   - 操作：扫描过程中取消
   - 期望：`ImageCache` 被清空

### 集成测试

1. **完整扫描流程验证**
   - 准备测试目录，包含音频文件和同名图片
   - 执行扫描
   - 验证数据库中 `album_art_path` 字段正确

2. **AlbumCover 组件显示验证**
   - 加载有 `albumArtPath` 的歌曲
   - 验证组件显示外部图片文件

## 风险与缓解

| 风险 | 影响 | 缓解措施 |
|------|------|----------|
| 图片文件被删除 | 封面无法显示 | AlbumCover 组件已有回退逻辑 |
| 大量图片文件占用内存 | 扫描性能下降 | ImageCache 仅存储路径，不加载图片内容 |
| 文件名编码问题 | 匹配失败 | 统一使用小写比较 |

## 后续优化

1. 支持文件夹封面（`folder.jpg`、`cover.jpg`）作为备选
2. 支持专辑级别封面（同一专辑共用一张封面图）
3. 图片格式转换和压缩（减少存储空间）
