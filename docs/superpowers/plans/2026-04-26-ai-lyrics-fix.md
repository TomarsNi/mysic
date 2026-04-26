# AI 歌词功能修复实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 修复 AI 歌词搜索功能的三个问题：歌词预览无法滚动、点击外部弹框隐藏、应用歌词后播放页面无歌词。

**Architecture:** 修改 `ResultPreviewSheet` 支持歌词滚动，修改 `showModalBottomSheet` 禁止下拉关闭，修改 `PlayerProvider` 优先从数据库加载歌词。

**Tech Stack:** Flutter, Dart, SQLite

---

## 文件结构

| 文件 | 改动类型 | 说明 |
|------|----------|------|
| `mysic_flutter/lib/features/ai_skills/presentation/widgets/result_preview_sheet.dart` | 修改 | 歌词预览支持滚动 |
| `mysic_flutter/lib/main.dart` | 修改 | 禁止下拉关闭 + 应用后重载歌词 |
| `mysic_flutter/lib/features/player/presentation/providers/player_provider.dart` | 修改 | 歌词加载优先从数据库读取 |

---

### Task 1: 修改歌词预览支持滚动

**Files:**
- Modify: `mysic_flutter/lib/features/ai_skills/presentation/widgets/result_preview_sheet.dart:187-246`

- [ ] **Step 1: 修改 `_buildLyricsResult` 方法，支持完整歌词显示和滚动**

将 `_buildLyricsResult` 方法修改为：

```dart
/// 歌词搜索结果
Widget _buildLyricsResult(Map<String, dynamic> data) {
  final lyrics = data['lyrics'] as String? ?? '';
  final lines = lyrics.split('\n');

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      const Text(
        '歌词搜索结果',
        style: TextStyle(
          color: AppColors.white,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(height: 16),

      // 匹配信息
      if (data['matchedSong'] != null)
        Text(
          '匹配歌曲：${data['matchedSong']['title']} - ${data['matchedSong']['artist']}',
          style: const TextStyle(
            color: AppColors.muted,
            fontSize: 14,
          ),
        ),
      const SizedBox(height: 12),

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
              children: lines
                  .map((line) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          line,
                          style: const TextStyle(
                            color: AppColors.white,
                            fontSize: 14,
                          ),
                        ),
                      ))
                  .toList(),
            ),
          ),
        ),
      ),
      const SizedBox(height: 24),

      // 操作按钮
      _buildActionButtons(confirmText: '应用歌词'),
    ],
  );
}
```

- [ ] **Step 2: 验证修改**

运行: `cd mysic_flutter && flutter analyze lib/features/ai_skills/presentation/widgets/result_preview_sheet.dart`

预期: 无错误

- [ ] **Step 3: 提交**

```bash
git add mysic_flutter/lib/features/ai_skills/presentation/widgets/result_preview_sheet.dart
git commit -m "fix(ai-skills): 歌词预览支持完整显示和滚动"
```

---

### Task 2: 禁止下拉手势关闭弹框

**Files:**
- Modify: `mysic_flutter/lib/main.dart:833-837`

- [ ] **Step 1: 在 `showModalBottomSheet` 添加 `enableDrag: false`**

找到 `_executeSkill` 方法中的 `showModalBottomSheet`（约第 833 行），添加 `enableDrag: false`：

```dart
// 显示结果预览
showModalBottomSheet(
  context: context,
  backgroundColor: Colors.transparent,
  isScrollControlled: true,
  isDismissible: false,
  enableDrag: false, // 禁止下拉手势关闭
  builder: (context) => ListenableBuilder(
    // ... 其余代码不变
```

- [ ] **Step 2: 验证修改**

运行: `cd mysic_flutter && flutter analyze lib/main.dart`

预期: 无错误

- [ ] **Step 3: 提交**

```bash
git add mysic_flutter/lib/main.dart
git commit -m "fix(ai-skills): 禁止下拉手势关闭结果预览弹框"
```

---

### Task 3: 修改 PlayerProvider 支持从数据库加载歌词

**Files:**
- Modify: `mysic_flutter/lib/features/player/presentation/providers/player_provider.dart`
- 需要添加 `DatabaseHelper` 导入

- [ ] **Step 1: 添加 DatabaseHelper 导入**

在文件顶部添加导入：

```dart
import 'package:flutter/foundation.dart';
import '../../data/models/song.dart';
import '../../data/services/audio_player_service.dart';
import '../../data/repositories/song_repository.dart';
import '../../../lyrics/data/services/lyrics_parser.dart';
import '../../../playlist/data/playlist_repository.dart';
import '../../../../core/database/database_helper.dart'; // 新增
```

- [ ] **Step 2: 修改 `_loadLyricsForSong` 方法，优先从数据库加载**

将 `_loadLyricsForSong` 方法修改为：

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
      _currentLyrics = _lyricsParser.parse(lrcContent);
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
```

- [ ] **Step 3: 添加公开方法 `reloadLyrics`**

在 `_loadLyricsForSong` 方法后添加：

```dart
/// 重新加载当前歌曲的歌词（供外部调用）
Future<void> reloadLyrics() async {
  await _loadLyricsForSong(_currentSong);
}
```

- [ ] **Step 4: 验证修改**

运行: `cd mysic_flutter && flutter analyze lib/features/player/presentation/providers/player_provider.dart`

预期: 无错误

- [ ] **Step 5: 提交**

```bash
git add mysic_flutter/lib/features/player/presentation/providers/player_provider.dart
git commit -m "feat(player): 歌词加载优先从数据库读取，添加 reloadLyrics 方法"
```

---

### Task 4: 应用歌词后重新加载到播放器

**Files:**
- Modify: `mysic_flutter/lib/main.dart:906-933`

- [ ] **Step 1: 在 `_applyResult` 的歌词保存逻辑中添加重载调用**

找到 `_applyResult` 方法中 `skill.id == 'lyrics_search'` 分支（约第 906 行），修改为：

```dart
} else if (skill.id == 'lyrics_search') {
  // 保存歌词
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

  // 刷新播放器状态
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

- [ ] **Step 2: 验证修改**

运行: `cd mysic_flutter && flutter analyze lib/main.dart`

预期: 无错误

- [ ] **Step 3: 提交**

```bash
git add mysic_flutter/lib/main.dart
git commit -m "fix(ai-skills): 应用歌词后立即重新加载到播放器"
```

---

### Task 5: 运行测试验证

- [ ] **Step 1: 运行 Flutter 分析**

运行: `cd mysic_flutter && flutter analyze`

预期: 无错误

- [ ] **Step 2: 运行测试**

运行: `cd mysic_flutter && flutter test`

预期: 所有测试通过

- [ ] **Step 3: 最终提交（如有遗漏）**

```bash
git status
# 如有未提交的更改，提交它们
```

---

## 测试验证清单

手动测试以下场景：

1. **歌词预览滚动**：搜索歌词 → 结果页面显示完整歌词，可上下滚动
2. **弹框不关闭**：点击弹框外部或下拉 → 弹框不关闭
3. **歌词立即显示**：点击"应用歌词" → 播放页面立即显示歌词
