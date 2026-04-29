# 歌曲编辑 - 图片与歌词选择功能设计

## 概述

扩展现有的歌曲编辑对话框，支持用户选择本地图片作为专辑封面、选择本地 .lrc 文件作为歌词。

## 数据模型变更

### Song 模型

新增字段：
- `lyricsPath: String?` — 歌词文件路径（应用目录内的路径）

### 数据库迁移

- 版本：6 → 7
- 变更：`songs` 表新增 `lyrics_path TEXT` 字段

## 文件存储结构

```
应用数据目录/
├── album_covers/              # 专辑封面图片
│   └── {song_id}_{timestamp}.{ext}
└── lyrics/                    # 歌词文件
    └── {song_id}_{timestamp}.lrc
```

命名规则：
- 使用 `song_id` + 时间戳命名，避免文件名冲突
- 图片保留原始扩展名（jpg、png、webp）
- 歌词统一使用 .lrc 扩展名

支持的格式：
- 图片：jpg、jpeg、png、webp
- 歌词：lrc

## UI 设计

扩展现有 `SongEditDialog`，布局如下：

```
┌─────────────────────────────────────┐
│ 编辑歌曲信息                         │
├─────────────────────────────────────┤
│ [专辑封面预览区域]                   │
│ ┌─────────────┐                     │
│ │   260x260   │  [选择图片] [清除]  │
│ │   圆形封面   │                     │
│ └─────────────┘                     │
├─────────────────────────────────────┤
│ 歌曲名称: [________________]        │
│ 艺术家:   [________________]        │
│ 专辑:     [________________]        │
├─────────────────────────────────────┤
│ 歌词文件: 未选择  [选择歌词] [清除]  │
├─────────────────────────────────────┤
│              [取消] [保存]           │
└─────────────────────────────────────┘
```

### 封面预览区域

- 尺寸：260x260 像素，圆形裁剪
- 无封面时显示占位图标（音乐图标）
- 有封面时显示当前封面图片
- 操作按钮：「选择图片」「清除」

### 歌词文件区域

- 显示当前歌词文件名，未选择时显示「未选择」
- 操作按钮：「选择歌词」「清除」

## 技术实现

### 文件选择

使用 `file_selector` 包实现跨平台文件选择：

```dart
// 图片选择
final result = await FileSelector.openFile(
  acceptedTypeGroups: [
    XTypeGroup(
      label: '图片',
      extensions: ['jpg', 'jpeg', 'png', 'webp'],
    ),
  ],
);

// 歌词选择
final result = await FileSelector.openFile(
  acceptedTypeGroups: [
    XTypeGroup(
      label: '歌词',
      extensions: ['lrc'],
    ),
  ],
);
```

### 文件处理流程

**选择图片**：
1. 用户通过文件选择器选择图片
2. 复制文件到 `{应用目录}/album_covers/{song_id}_{timestamp}.{ext}`
3. 更新 Song 的 `albumArtPath` 字段为新路径
4. 清空 `albumArtBase64` 字段（优先使用文件路径）

**选择歌词**：
1. 用户通过文件选择器选择 .lrc 文件
2. 复制文件到 `{应用目录}/lyrics/{song_id}_{timestamp}.lrc`
3. 更新 Song 的 `lyricsPath` 字段为新路径

**清除封面/歌词**：
1. 删除应用目录内的副本文件（如果存在）
2. 将对应字段置为 null

### 应用目录获取

```dart
// Windows: C:\Users\{user}\AppData\Local\mysic
// Android: /data/data/{package}/app_flutter
final appDir = await getApplicationSupportDirectory();
```

### 文件复制工具

创建 `FileCopyService` 工具类：

```dart
class FileCopyService {
  /// 复制图片到应用目录
  Future<String?> copyAlbumCover(String sourcePath, int songId);

  /// 复制歌词到应用目录
  Future<String?> copyLyrics(String sourcePath, int songId);

  /// 删除文件
  Future<void> deleteFile(String? path);
}
```

## 数据库更新

### SongRepository 扩展

新增方法：
- `updateAlbumArt(int songId, String? albumArtPath)` — 更新专辑封面路径
- `updateLyricsPath(int songId, String? lyricsPath)` — 更新歌词文件路径

### 歌词读取适配

`LyricsParser` 需适配新的歌词来源：
- 优先读取 `Song.lyricsPath`（应用目录内的 .lrc 文件）
- 若无，则查找同名 .lrc 文件（原有逻辑）
- 若无，则从数据库 `lyrics` 表读取（原有逻辑）

## 依赖变更

新增依赖：
- `file_selector` — 跨平台文件选择器

## 测试要点

1. 图片选择、复制、显示、清除流程
2. 歌词选择、复制、读取、清除流程
3. 数据库迁移正确性
4. 文件命名不冲突（多首歌曲、多次选择）
5. 跨平台路径处理（Windows/Android/iOS）