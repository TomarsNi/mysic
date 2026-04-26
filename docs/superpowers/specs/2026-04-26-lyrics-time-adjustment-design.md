# 歌词时间调整功能设计

## 概述

为歌词页面添加时间调整功能，支持整体偏移和逐行微调，调整后持久化保存到数据库。

## 功能需求

### 整体偏移
- 所有歌词行统一提前或延后
- 范围：-5s 到 +5s
- 步进：0.1s

### 逐行调整
- 单独调整每一行的时间戳
- 步进：0.1s
- 在编辑模式下显示调整按钮

### 持久化
- 保存到 `lyrics` 表的 `lrc_content` 字段
- 下次播放同一首歌时自动应用

## UI 设计

### 底部调整工具栏

编辑模式下在迷你播放器上方显示：

```
┌─────────────────────────────────────────────┐
│ 🎵 时间调整                                  │
├─────────────────────────────────────────────┤
│ 整体偏移                                      │
│ [◄]  -0.5s  [════●════]  +0.5s  [►]         │
│ 当前: +0.30s                    [重置]       │
├─────────────────────────────────────────────┤
│ [逐行调整]                    [保存] [取消]  │
└─────────────────────────────────────────────┘
```

### 逐行调整模式

- 每行歌词右侧显示 `-0.1s` `+0.1s` 按钮
- 当前行高亮显示当前时间戳
- 点击调整按钮实时更新预览

### 入口

在顶部栏右侧添加编辑图标按钮，点击进入编辑模式。

## 技术设计

### 状态管理

```dart
// LyricsPage 状态
bool _isEditMode = false;
bool _isLineEditMode = false;
Duration _globalOffset = Duration.zero;
Map<int, Duration> _lineOffsets = {};
```

### 数据流

```
用户调整 → 更新内存状态 → 实时预览效果
                ↓
         点击保存 → PlayerProvider.saveLyricsAdjustment()
                ↓
         DatabaseHelper 更新 lyrics 表的 lrc_content
                ↓
         刷新 PlayerProvider.currentLyrics
```

### 保存逻辑

1. 根据 `_globalOffset` 和 `_lineOffsets` 重新计算所有时间戳
2. 使用 `LyricsParser.toLrc()` 生成新的 LRC 内容
3. 更新数据库 `lyrics` 表的 `lrc_content` 字段
4. 刷新 `PlayerProvider.currentLyrics`

### 文件变更

| 文件 | 变更 |
|------|------|
| `lib/features/lyrics/presentation/pages/lyrics_page.dart` | 新增编辑模式状态、调整工具栏组件 |
| `lib/features/player/presentation/providers/player_provider.dart` | 新增 `saveLyricsAdjustment()` 方法 |
| `lib/core/database/database_helper.dart` | 新增 `updateLyricsContent()` 方法 |

## 实现要点

### 时间计算

```dart
Duration adjustTimestamp(Duration original, Duration globalOffset, Duration? lineOffset) {
  return original + globalOffset + (lineOffset ?? Duration.zero);
}
```

### LRC 内容生成

使用现有的 `LyricsParser.toLrc()` 方法，传入调整后的 `LyricsResult`。

### 数据库更新

```sql
INSERT OR REPLACE INTO lyrics (song_id, lrc_content, is_synced, source, created_at, updated_at)
VALUES (?, ?, 1, 'manual', datetime('now'), datetime('now'))
```

## 交互流程

1. 用户点击顶部编辑按钮 → 进入编辑模式
2. 显示底部调整工具栏
3. 用户调整整体偏移或进入逐行调整
4. 实时预览调整效果（歌词高亮跟随新时间）
5. 点击保存 → 持久化到数据库
6. 点击取消 → 放弃更改，退出编辑模式
