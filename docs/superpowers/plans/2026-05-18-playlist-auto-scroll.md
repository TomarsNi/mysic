# 播放列表自动滚动优化实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 修复播放列表弹窗打开时不自动滚动到当前播放歌曲的问题

**Architecture:** 使用 ScrollController 精确计算滚动位置，等待 DraggableScrollableSheet 展开动画完成后再执行滚动，移除不可靠的 GlobalKey 依赖

**Tech Stack:** Flutter, Dart, ScrollController

---

## 文件结构

| 文件 | 操作 | 说明 |
|------|------|------|
| `lib/shared/widgets/playlist_queue_sheet.dart` | 修改 | 修改滚动逻辑，移除 GlobalKey |

---

### Task 1: 修改 _scrollToCurrentSong 方法

**Files:**
- Modify: `lib/shared/widgets/playlist_queue_sheet.dart`

- [ ] **Step 1: 删除 GlobalKey 字段**

删除 `_PlaylistQueueSheetState` 类中的 `_currentItemKey` 字段：

```dart
// 删除这一行
final GlobalKey _currentItemKey = GlobalKey();
```

- [ ] **Step 2: 替换 _scrollToCurrentSong 方法**

将 `_scrollToCurrentSong` 方法替换为：

```dart
void _scrollToCurrentSong() {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!mounted) return;
    if (widget.songs.isEmpty) return;
    if (widget.currentIndex < 0 || widget.currentIndex >= widget.songs.length) return;
    if (widget.scrollController == null || !widget.scrollController!.hasClients) return;

    // item 高度：padding(24) + 内容(40) = 约 64px
    const itemHeight = 64.0;
    // 计算目标滚动位置，使当前项居中
    final targetOffset = (widget.currentIndex * itemHeight) -
        (widget.scrollController!.position.viewportDimension / 2) +
        (itemHeight / 2);

    // 等待 DraggableScrollableSheet 展开动画完成（约 300ms）
    Future.delayed(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      if (widget.scrollController == null || !widget.scrollController!.hasClients) return;

      final maxScroll = widget.scrollController!.position.maxScrollExtent;
      final clampedOffset = targetOffset.clamp(0.0, maxScroll);

      widget.scrollController!.animateTo(
        clampedOffset,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  });
}
```

- [ ] **Step 3: 移除 ListView.builder 中的 key 参数**

在 `build` 方法的 `ListView.builder` 中，移除 `_SongListTile` 的 `key` 参数：

```dart
// 修改前
return _SongListTile(
  key: index == widget.currentIndex ? _currentItemKey : null,
  song: widget.songs[index],
  isPlaying: index == widget.currentIndex,
  onTap: () => widget.onSongTap(index),
);

// 修改后
return _SongListTile(
  song: widget.songs[index],
  isPlaying: index == widget.currentIndex,
  onTap: () => widget.onSongTap(index),
);
```

- [ ] **Step 4: 运行代码分析**

Run: `cd mysic_flutter && flutter analyze`
Expected: No issues found

- [ ] **Step 5: 手动测试**

1. 运行应用：`cd mysic_flutter && flutter run -d windows`
2. 播放一首歌曲
3. 打开播放列表弹窗，验证是否自动滚动到当前播放歌曲
4. 切换到其他歌曲，重新打开弹窗，验证滚动位置是否正确
5. 当前歌曲在列表顶部/底部时，验证滚动边界处理是否正确

- [ ] **Step 6: 提交**

```bash
git add lib/shared/widgets/playlist_queue_sheet.dart
git commit -m "fix(player): 修复播放列表弹窗不自动滚动到当前歌曲的问题

- 使用 ScrollController 计算滚动位置替代 GlobalKey
- 等待 DraggableScrollableSheet 展开动画完成后再滚动
- 移除不可靠的延迟重试机制"
```
