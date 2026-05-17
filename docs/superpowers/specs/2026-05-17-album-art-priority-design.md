# 专辑封面关联功能设计

## 概述

扫描歌曲时，按优先级关联专辑封面：元数据内嵌封面 > 同名图片文件 > MediaStore 封面（仅 Android）。

## 封面获取优先级

```
┌─────────────────────────────────────────────────────────────┐
│                      封面获取流程                            │
├─────────────────────────────────────────────────────────────┤
│  1. 元数据内嵌封面                                           │
│     └─ 从音频文件内部提取（audiotags）                        │
│         └─ 成功 → 保存到私有目录，记录路径                    │
│         └─ 失败 → 进入步骤 2                                 │
│                                                              │
│  2. 同名图片文件                                             │
│     └─ 查找与音频同名的图片文件                               │
│         └─ 找到 → 复制到私有目录，记录路径                    │
│         └─ 未找到 → 进入步骤 3                               │
│                                                              │
│  3. MediaStore 封面（仅 Android）                            │
│     └─ 从系统媒体库获取封面                                   │
│         └─ 成功 → 保存到私有目录，记录路径                    │
│         └─ 失败 → album_art_path 为 null                     │
└─────────────────────────────────────────────────────────────┘
```

## 技术方案

### 提取时机

扫描时提取封面，保存到应用私有目录。

### 存储方式

- 封面文件保存为 `{私有目录}/album_art/{songId}.jpg`
- 数据库 `album_art_path` 字段存储文件路径

### 平台差异

| 平台 | 内嵌封面 | 同名图片 | MediaStore |
|------|----------|----------|------------|
| Windows | audiotags | ImageCache | 不适用 |
| Android | audiotags | ImageCache + SAF | on_audio_query |

## 修改范围

### 1. metadata_extractor.dart

新增 `extractArtwork()` 静态方法：

```dart
/// 从音频文件提取内嵌封面
///
/// [filePath] 音频文件路径
/// 返回封面图片字节数据，无封面返回 null
static Future<Uint8List?> extractArtwork(String filePath) async {
  // WAV 文件：RIFF INFO 不包含封面，直接返回 null
  // 其他格式：使用 audiotags 提取 pictures
}
```

### 2. windows_music_scanner.dart

修改 `_extractMetadataParallel()` 方法：

1. 提取元数据后，调用 `MetadataExtractor.extractArtwork()` 获取内嵌封面
2. 如果内嵌封面存在，保存到私有目录
3. 如果内嵌封面不存在，使用 `ImageCache` 查找同名图片
4. 更新 `albumArtPath` 字段

### 3. mobile_music_scanner.dart

修改 `_saveMediaSongsToDatabase()` 方法：

1. 插入歌曲后，优先调用 `MetadataExtractor.extractArtwork()` 获取内嵌封面
2. 如果内嵌封面存在，保存到私有目录
3. 如果内嵌封面不存在，查找同名图片（现有逻辑）
4. 如果同名图片也不存在，回退到 MediaStore（现有逻辑）

## 实现步骤

1. **扩展 MetadataExtractor**
   - 新增 `extractArtwork()` 方法
   - 处理 WAV 文件特殊情况（无内嵌封面）

2. **修改 WindowsMusicScanner**
   - 新增 `_saveArtworkToFile()` 方法保存封面到私有目录
   - 调整 `_extractMetadataParallel()` 中的封面获取逻辑

3. **修改 MobileMusicScanner**
   - 复用现有的 `_fetchAndSaveArtwork()` 和 `_copyImageToPrivateDir()` 方法
   - 调整 `_saveMediaSongsToDatabase()` 中的封面优先级逻辑

## 测试要点

- [ ] MP3 文件内嵌封面提取
- [ ] FLAC 文件内嵌封面提取
- [ ] WAV 文件同名图片兜底
- [ ] 无封面歌曲的 MediaStore 回退（Android）
- [ ] 封面文件正确保存到私有目录
- [ ] 数据库 `album_art_path` 正确记录
