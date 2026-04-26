# AI 歌词功能修复设计

## 概述

修复 AI 歌词搜索功能的三个问题：
1. 歌词搜索结果页面歌词显示不全，无法上下滑动
2. 点击外部弹框隐藏，此场景希望用户点击取消才隐藏
3. 应用歌词后，播放页面依然显示"暂无歌词"

## 问题分析

### 问题 1：歌词预览无法滚动

**根因：** `result_preview_sheet.dart` 第 190 行只取前 10 行歌词，且容器是固定高度的 `Column`，没有滚动支持。

**代码位置：**
```dart
// result_preview_sheet.dart:190
final lines = lyrics.split('\n').take(10).toList();
```

### 问题 2：点击外部弹框隐藏

**根因：** `showModalBottomSheet` 虽然设置了 `isDismissible: false`，但缺少 `enableDrag: false`，用户仍可通过下拉手势关闭弹框。

**代码位置：**
```dart
// main.dart:833-837
showModalBottomSheet(
  context: context,
  backgroundColor: Colors.transparent,
  isScrollControlled: true,
  isDismissible: false,  // 阻止点击外部关闭
  // 缺少 enableDrag: false  // 未阻止下拉手势
```

### 问题 3：应用歌词后播放页面无歌词

**根因：** `PlayerProvider._loadLyricsForSong` 只从文件系统加载歌词，没有从数据库加载。保存歌词到数据库后，没有触发重新加载。

**代码位置：**
```dart
// player_provider.dart:77-91
Future<void> _loadLyricsForSong(Song? song) async {
  // 只查找文件系统，没有查询数据库
  final lyricsPath = _lyricsParser.findLyricsFile(song.filePath);
  if (lyricsPath != null) {
    _currentLyrics = await _lyricsParser.parseFile(lyricsPath);
  } else {
    _currentLyrics = LyricsResult.empty;
  }
}
```

## 设计方案

### 修复 1：歌词预览支持滚动

**文件：** `result_preview_sheet.dart`

**改动：**
- 移除 `.take(10)` 限制，显示全部歌词
- 将歌词容器改为 `ConstrainedBox(maxHeight: 200)` + `SingleChildScrollView`
- 添加渐变遮罩提示用户可滚动（当歌词超过最大高度时）

**修改后代码：**
```dart
Widget _buildLyricsResult(Map<String, dynamic> data) {
  final lyrics = data['lyrics'] as String? ?? '';
  final lines = lyrics.split('\n');  // 移除 take(10)

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // ... 标题和匹配信息 ...

      // 歌词预览 - 可滚动
      ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 200),
        child: SingleChildScrollView(
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: lines.map((line) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  line,
                  style: const TextStyle(
                    color: AppColors.white,
                    fontSize: 14,
                  ),
                ),
              )).toList(),
            ),
          ),
        ),
      ),
      const SizedBox(height: 24),
      _buildActionButtons(confirmText: '应用歌词'),
    ],
  );
}
```

### 修复 2：禁止下拉手势关闭弹框

**文件：** `main.dart`

**改动：** 在 `showModalBottomSheet` 添加 `enableDrag: false`

**修改后代码：**
```dart
showModalBottomSheet(
  context: context,
  backgroundColor: Colors.transparent,
  isScrollControlled: true,
  isDismissible: false,  // 禁止点击外部关闭
  enableDrag: false,     // 禁止下拉手势关闭
  builder: (context) => ...
);
```

### 修复 3：歌词加载优先从数据库读取

**文件：** `player_provider.dart`

**改动：**
1. 修改 `_loadLyricsForSong`：优先从数据库查询 → 再从文件系统查找
2. 添加公开方法 `reloadLyrics()` 供外部调用

**修改后代码：**
```dart
/// 加载当前歌曲的歌词
Future<void> _loadLyricsForSong(Song? song) async {
  if (song == null) {
    _currentLyrics = LyricsResult.empty;
    return;
  }

  // 1. 优先从数据库加载
  final db = await DatabaseHelper().database;
  final dbResult = await db.query(
    DatabaseHelper.tableLyrics,
    where: 'song_id = ?',
    whereArgs: [song.id],
  );

  if (dbResult.isNotEmpty) {
    final lrcContent = dbResult.first['lrc_content'] as String?;
    if (lrcContent != null && lrcContent.isNotEmpty) {
      _currentLyrics = _lyricsParser.parseContent(lrcContent);
      notifyListeners();
      return;
    }
  }

  // 2. 再从文件系统查找
  final lyricsPath = _lyricsParser.findLyricsFile(song.filePath);
  if (lyricsPath != null) {
    _currentLyrics = await _lyricsParser.parseFile(lyricsPath);
  } else {
    _currentLyrics = LyricsResult.empty;
  }
  notifyListeners();
}

/// 重新加载当前歌曲的歌词（供外部调用）
Future<void> reloadLyrics() async {
  await _loadLyricsForSong(_currentSong);
}
```

**文件：** `main.dart`

**改动：** 在 `_applyResult` 保存歌词后，调用 `playerProvider.reloadLyrics()`

**修改后代码：**
```dart
} else if (skill.id == 'lyrics_search') {
  // 保存歌词到数据库
  final db = await DatabaseHelper().database;
  await db.insert(
    DatabaseHelper.tableLyrics,
    {
      'song_id': song.id,
      'lrc_content': data['lyrics'] as String,
      'is_synced': 1,
      'source': data['source'] as String?,
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    },
    conflictAlgorithm: ConflictAlgorithm.replace,
  );

  // 重新加载歌词到播放器
  await playerProvider.reloadLyrics();

  // 刷新歌单状态
  await playlistProvider.refresh();

  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('歌词已保存'),
        backgroundColor: Color(0xFF10B981),
      ),
    );
  }
}
```

## 文件变更清单

| 文件 | 改动类型 | 说明 |
|------|----------|------|
| `result_preview_sheet.dart` | 修改 | 歌词预览支持滚动 |
| `main.dart` | 修改 | 禁止下拉关闭 + 应用后重载歌词 |
| `player_provider.dart` | 修改 | 歌词加载优先从数据库读取 |

## 测试验证

1. 搜索歌词 → 结果页面显示完整歌词，可上下滚动
2. 点击弹框外部 → 弹框不关闭
3. 点击"应用歌词" → 播放页面立即显示歌词
