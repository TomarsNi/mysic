# 移除歌词页面歌曲信息栏 实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 删除歌词页面 AppBar 下方的 `_buildSongInfoBar()` 方法及其调用，为歌词区域释放更多空间。

**Architecture:** 单文件改动，删除 `lyrics_page.dart` 中的歌曲信息栏方法和调用。

**Tech Stack:** Flutter/Dart

---

### Task 1: 删除歌曲信息栏调用和方法

**Files:**
- Modify: `mysic_flutter/lib/features/lyrics/presentation/pages/lyrics_page.dart:84-85` (删除调用)
- Modify: `mysic_flutter/lib/features/lyrics/presentation/pages/lyrics_page.dart:172-252` (删除方法)

- [ ] **Step 1: 删除 build 方法中的调用**

在 `lyrics_page.dart` 的 `build()` 方法中，删除第 84-85 行：

```dart
// 删除这两行:
                // 歌曲信息栏 - 设计稿新增
                _buildSongInfoBar(context, currentSong),
```

- [ ] **Step 2: 删除 `_buildSongInfoBar` 方法**

删除第 172-252 行的整个 `_buildSongInfoBar` 方法：

```dart
// 删除从这行开始:
  /// 歌曲信息栏
  /// 与首页一致的颜色方案
  Widget _buildSongInfoBar(BuildContext context, Song? currentSong) {
    ...
  }
// 到这行结束（含闭合大括号）
```

- [ ] **Step 3: 验证编译通过**

Run: `cd mysic_flutter && flutter analyze`
Expected: No errors

- [ ] **Step 4: 提交**

```bash
cd mysic_flutter && git add lib/features/lyrics/presentation/pages/lyrics_page.dart
git commit -m "refactor(lyrics): 移除歌曲信息栏，为歌词区域释放更多空间"
```
