# 创建歌单时选择扫描目录功能设计

## 概述

用户创建歌单时可以选择一个目录进行扫描，扫描到的歌曲自动添加到新创建的歌单中，同时智能合并到"本地音乐"歌单。

## 需求确认

| 需求项 | 决策 |
|--------|------|
| 目录选择方式 | 临时选择，不影响全局扫描配置 |
| 本地音乐合并策略 | 智能合并，跳过已存在的重复歌曲 |
| 空目录处理 | 允许创建空歌单 |
| 目录选择 UI | 系统文件选择器 |
| 目录字段位置 | 歌单名称上方 |
| 扫描进度显示 | 对话框内进度条 |

## UI 设计

### CreatePlaylistDialog 布局

```
┌─────────────────────────────────────┐
│  创建歌单                            │
├─────────────────────────────────────┤
│                                     │
│  扫描目录（可选）                     │
│  ┌─────────────────────┐ ┌──────┐  │
│  │ 未选择目录           │ │ 选择 │  │
│  └─────────────────────┘ └──────┘  │
│                                     │
│  歌单名称 *                          │
│  ┌─────────────────────────────┐   │
│  │                             │   │
│  └─────────────────────────────┘   │
│                                     │
│  描述（可选）                        │
│  ┌─────────────────────────────┐   │
│  │                             │   │
│  └─────────────────────────────┘   │
│                                     │
│  [扫描进度条 - 仅扫描时显示]          │
│                                     │
├─────────────────────────────────────┤
│              [取消]  [创建]          │
└─────────────────────────────────────┘
```

### 扫描状态 UI

| 状态 | 显示内容 |
|------|----------|
| 未选择目录 | 占位文本"未选择目录" |
| 已选择目录 | 目录路径 + 清除按钮 |
| 扫描中 | 进度条 + 百分比 + "正在扫描..." |
| 扫描完成 | "已找到 X 首歌曲" |

## 数据流

```
用户点击"创建歌单"
    ↓
显示 CreatePlaylistDialog
    ↓
用户点击"选择"按钮 → 打开文件选择器
    ↓
用户选择目录 → 显示已选路径
    ↓
用户点击"创建"
    ↓
如果选择了目录：
    ├─ 禁用按钮，显示进度条
    ├─ 启动 MusicScanner 扫描指定目录
    ├─ 接收进度更新 → 更新进度条
    └─ 扫描完成 → 保存歌曲到数据库
    ↓
创建歌单记录
    ↓
将扫描到的歌曲添加到新歌单
    ↓
将歌曲添加到"本地音乐"歌单（智能合并）
    ↓
关闭对话框，返回新歌单
```

## 核心改动文件

| 文件 | 改动内容 |
|------|----------|
| `lib/shared/widgets/bottom_sheet.dart` | `CreatePlaylistDialog` 添加目录选择、进度显示、扫描逻辑 |
| `lib/features/playlist/presentation/providers/playlist_provider.dart` | `createPlaylist` 方法支持可选目录参数和扫描回调 |
| `lib/shared/utils/windows_music_scanner.dart` | 添加指定目录扫描方法 `scanMusicInDirectory` |
| `lib/shared/utils/mobile_music_scanner.dart` | 添加指定目录扫描方法（移动端限制处理） |
| `lib/shared/utils/platform_music_scanner.dart` | 抽象类添加 `scanMusicInDirectory` 方法声明 |

## 平台差异处理

### Windows

- 使用 `file_picker` 包选择文件夹
- `WindowsMusicScanner` 支持指定目录扫描
- 完整功能支持

### Android/iOS

- 移动端文件系统访问受限
- 使用 `on_audio_query` 按文件夹查询（如果支持）
- 或提示用户该功能在移动端有限制

## 技术实现要点

### 1. 目录扫描方法

```dart
// PlatformMusicScanner 新增方法
Future<ScanResult> scanMusicInDirectory(String directory);
```

### 2. CreatePlaylistDialog 状态管理

```dart
class _CreatePlaylistDialogState extends State<CreatePlaylistDialog> {
  String? _selectedDirectory;
  bool _isScanning = false;
  double _scanProgress = 0.0;
  int _songsFound = 0;
  // ...
}
```

### 3. 智能合并逻辑

```dart
// 扫描到的歌曲添加到"本地音乐"时
// 使用现有的 addSongsToPlaylist 方法
// 该方法内部已处理重复检查（通过 addSongToPlaylist 中的 existing 检查）
```

## 测试要点

1. **正常流程**：选择目录 → 扫描 → 创建歌单 → 歌曲添加成功
2. **空目录**：选择无音乐文件的目录 → 创建空歌单
3. **取消扫描**：扫描过程中用户取消（如需要）
4. **重复歌曲**：扫描已存在的歌曲 → 智能跳过
5. **移动端兼容**：验证移动端行为

## 依赖

- `file_picker` 包：用于文件夹选择（如尚未添加需添加依赖）
