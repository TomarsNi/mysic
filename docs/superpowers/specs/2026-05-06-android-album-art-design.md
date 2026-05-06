# Android 歌曲封面获取功能设计

## 问题背景

Android 系统文件管理器打开歌曲目录时，歌曲有预览封面，但应用扫描播放时没有封面显示。

### 根因分析

1. **Android MediaStore** 已经提取并缓存了专辑封面
2. **应用扫描逻辑** 使用 `on_audio_query` 包扫描时，只获取了歌曲基本信息（标题、艺术家、专辑、时长等）
3. **缺失封面获取** 没有调用 `queryArtwork` 方法获取封面数据

## 解决方案

在 `MobileMusicScanner` 扫描歌曲时，同步获取封面并保存为图片文件。

## 技术设计

### 封面获取流程

```
MediaStore 歌曲列表
       ↓
遍历每首歌曲
       ↓
调用 queryArtwork(songId, ArtworkType.AUDIO)
       ↓
   有封面数据？
    ├── 是 → 保存为文件 → 更新 album_art_path
    └── 否 → album_art_path = null
```

### 文件存储

**存储位置：**
- 应用私有文档目录：`<app_doc_dir>/album_art/`
- Android 路径示例：`/storage/emulated/0/Android/data/com.example.mysic/files/album_art/`

**文件命名规则：**
- 格式：`<song_id>.jpg`
- 使用数据库自增 ID 作为文件名，避免文件名冲突

**优势：**
- 应用私有目录，无需额外存储权限
- 卸载应用时自动清理
- 文件可复用，避免重复获取

### 数据库

**现有字段：**
- `album_art_path` (TEXT, nullable) - 封面文件路径
- `album_art_base64` (TEXT, nullable) - Base64 编码封面（备用）

**本次变更：**
- 无需修改表结构
- 扫描时填充 `album_art_path` 字段

### 代码变更

#### 1. MobileMusicScanner 新增方法

```dart
/// 获取歌曲封面并保存为文件
///
/// 返回封面文件路径，获取失败返回 null
Future<String?> _fetchAndSaveArtwork(int songId, int mediaId) async {
  try {
    // 使用 on_audio_query 获取封面
    final artwork = await _audioQuery.queryArtwork(
      mediaId,
      ArtworkType.AUDIO,
      quality: 100, // 原始质量
    );

    if (artwork == null || artwork.isEmpty) {
      return null;
    }

    // 保存为文件
    final appDir = await getApplicationDocumentsDirectory();
    final artDir = Directory('${appDir.path}/album_art');
    if (!await artDir.exists()) {
      await artDir.create(recursive: true);
    }

    final filePath = '${artDir.path}/$songId.jpg';
    final file = File(filePath);
    await file.writeAsBytes(artwork);

    return filePath;
  } catch (e) {
    debugPrint('获取封面失败: songId=$songId, error=$e');
    return null;
  }
}
```

#### 2. 修改 _saveMediaSongsToDatabase 方法

在插入歌曲后，获取封面并更新：

```dart
await db.transaction((txn) async {
  for (final mediaSong in mediaSongs) {
    // ... 现有的过滤和插入逻辑 ...

    final songId = await txn.insert(...);
    newSongIds.add(songId);
    newAdded++;

    // 获取封面（在事务外执行，避免阻塞）
    // 注意：需要在事务外调用，因为 queryArtwork 是异步操作
  }
});

// 事务完成后批量获取封面
for (final songId in newSongIds) {
  final mediaSong = mediaSongs.firstWhere((s) => /* 匹配逻辑 */);
  final artPath = await _fetchAndSaveArtwork(songId, mediaSong.id);
  if (artPath != null) {
    await db.update(
      DatabaseHelper.tableSongs,
      {'album_art_path': artPath},
      where: 'id = ?',
      whereArgs: [songId],
    );
  }
}
```

#### 3. 依赖添加

```yaml
# pubspec.yaml
dependencies:
  path_provider: ^2.1.0  # 获取应用目录
```

### 性能影响

| 操作 | 原耗时 | 新增耗时 | 说明 |
|------|--------|----------|------|
| 扫描 100 首歌 | ~2s | +3~5s | 每首歌额外获取封面 |
| 存储空间 | 0 | +5~20MB | 取决于封面数量和大小 |

### 错误处理

1. **封面获取失败** - 记录日志，继续处理下一首，不影响扫描流程
2. **文件写入失败** - 记录日志，album_art_path 保持 null
3. **目录创建失败** - 记录日志，跳过封面保存

### 兼容性

- **Android 10+**：使用 MediaStore API，兼容分区存储
- **Android 9 及以下**：兼容传统存储模式
- **应用私有目录**：所有版本均可正常写入

## 测试计划

1. **单元测试**
   - 封面获取成功场景
   - 封面获取失败场景（无封面、网络错误等）
   - 文件保存成功/失败场景

2. **集成测试**
   - 扫描包含封面的歌曲，验证封面显示
   - 扫描不含封面的歌曲，验证默认封面显示
   - 重复扫描，验证封面不重复获取

3. **手动测试**
   - Android 10+ 设备测试
   - Android 9 及以下设备测试
   - 大量歌曲扫描性能测试

## 实现范围

### 本次实现

- [x] MobileMusicScanner 新增封面获取逻辑
- [x] 封面文件存储到应用私有目录
- [x] 数据库 album_art_path 字段更新
- [x] 错误处理和日志记录

### 不在范围

- Windows 平台封面获取（已有 audiotags 实现）
- 封面压缩/缩略图生成
- 封面缓存清理机制
