# 扫描音乐时自动关联歌词文件

## 需求概述

在扫描音乐文件时，自动查找同目录下的 .lrc 歌词文件并关联到歌曲记录，提升用户体验。

## 当前状态

### 数据库设计

- `songs` 表有 `lyrics_path` 字段（TEXT，可为空），用于存储歌词文件路径
- `lyrics` 表存储歌词内容（LRC 格式），通过 `song_id` 关联

### 扫描器实现

`WindowsMusicScanner`（位于 `lib/shared/utils/windows_music_scanner.dart`）：
- 扫描音频文件时提取元数据（标题、艺术家、专辑、时长）
- **缺失**：没有扫描 .lrc 歌词文件

### 歌词功能

- `LyricsParser`（`lib/features/lyrics/data/services/lyrics_parser.dart`）：解析 LRC 文件
- `lyrics_search_skill`：AI 技能用于在线搜索歌词

## 设计方案

### 核心逻辑

1. **扫描时机**：在保存歌曲到数据库时，同时查找歌词文件
2. **匹配规则**：
   - 优先同名匹配：`歌曲.mp3` → `歌曲.lrc`
   - 宽松匹配：支持序号前缀变体，如 `01. 歌曲名.lrc`、`1-歌曲名.lrc`
3. **存储方式**：仅在 `songs.lyrics_path` 记录文件路径，不导入内容
4. **播放时读取**：播放器根据 `lyrics_path` 读取 .lrc 文件内容

### 歌词文件查找流程

```
对于每个音频文件（如 D:\Music\流行\告白气球.mp3）
    ↓
获取同目录路径（D:\Music\流行\）
    ↓
获取音频文件名不含扩展名（告白气球）
    ↓
查找策略：
    ├─ 优先：同名匹配（告白气球.lrc）
    ├─ 次选：宽松匹配（遍历目录下所有 .lrc 文件）
    │       - 移除序号前缀后比较（01. 告白气球.lrc → 告白气球.lrc）
    │       - 移除常见分隔符（-、_、空格）后比较
    └─ 找到则返回完整路径，否则返回 null
    ↓
将歌词路径写入 songs.lyrics_path 字段
```

### 宽松匹配规则

| 音频文件名 | 可匹配的歌词文件名 |
|-----------|-------------------|
| `告白气球.mp3` | `告白气球.lrc` |
| `告白气球.mp3` | `01. 告白气球.lrc` |
| `告白气球.mp3` | `1-告白气球.lrc` |
| `告白气球.mp3` | `01告白气球.lrc` |
| `告白气球.mp3` | `告白气球 - 周杰伦.lrc`（含艺术家后缀） |

**匹配算法**：
1. 提取音频文件名（不含扩展名）
2. 清理序号前缀：移除开头的数字和分隔符（`.`、`-`、`_`、空格）
3. 遍历目录下所有 `.lrc` 文件，同样清理后比较
4. 如果清理后的名称与音频文件名匹配，则关联

### 实现细节

#### 修改文件

`lib/shared/utils/windows_music_scanner.dart`

#### 代码变更

1. **新增歌词查找方法**：

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

/// 清理歌词文件名（移除扩展名和序号前缀）
String _cleanLrcFileName(String lrcFileName) {
  // 移除 .lrc 扩展名
  var name = lrcFileName.replaceAll(RegExp(r'\.lrc$', caseSensitive: false), '');
  // 移除开头的数字序号和分隔符
  name = name.replaceFirst(RegExp(r'^\d+[\s.\-_]+'), '');
  // 移除可能的艺术家后缀（如 " - 周杰伦"）
  name = name.replaceFirst(RegExp(r'\s*-\s*.+$'), '');
  return name.toLowerCase().trim();
}
```

2. **修改 `_saveSongsToDatabase` 方法**：

在插入歌曲记录时，同时查找并设置 `lyrics_path`：

```dart
// 在插入歌曲时
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
    'lyrics_path': lyricsPath,  // 新增
    'date_added': null,
    'created_at': nowIso,
    'updated_at': nowIso,
  },
);
```

## 边界情况

| 场景 | 行为 |
|------|------|
| 歌词文件不存在 | `lyrics_path` 为 null |
| 多个歌词文件匹配 | 返回第一个匹配的文件 |
| 歌词文件名含特殊字符（中文、空格） | 正常处理 |
| 歌词文件在其他目录 | 不匹配（仅同目录） |
| 音频文件在根目录 | 正常处理 |

## 性能考虑

- 歌词查找在保存歌曲时进行，不影响扫描进度显示
- 每个音频文件最多遍历一次目录下的 .lrc 文件
- 可考虑缓存已扫描目录的 .lrc 文件列表以优化性能

## 测试要点

1. **单元测试**：
   - `_cleanLrcFileName` 对各种文件名的清理正确性
   - `_findLyricsFile` 的匹配逻辑

2. **集成测试**：
   - 扫描含歌词文件的目录，验证 `lyrics_path` 正确关联
   - 扫描不含歌词文件的目录，验证 `lyrics_path` 为 null

## 不涉及变更

- 不修改 `LyricsParser`
- 不修改播放器逻辑
- 不修改数据库表结构（`lyrics_path` 字段已存在）
