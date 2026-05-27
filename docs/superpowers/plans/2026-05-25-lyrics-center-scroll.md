# 歌词自动居中滚动 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 修复歌词页面当前歌唱行不在视口中间的问题，通过添加上下半屏 padding 确保 ensureVisible(alignment: 0.5) 在所有情况下都能将当前行居中。

**Architecture:** 在 ListView 的 padding 中添加上下各等于视口高度一半的空白区域，为列表首尾行提供足够的滚动空间，使 ensureVisible(alignment: 0.5) 始终能将当前歌词行推到视口中心。

**Tech Stack:** Flutter/Dart, MediaQuery, ListView.builder

---

### Task 1: 修改 ListView padding 为动态半屏高度

**Files:**
- Modify: `mysic_flutter/lib/features/lyrics/presentation/pages/lyrics_page.dart` — `_buildLyricsList` 方法中的 ListView padding

- [ ] **Step 1: 修改 ListView 的 padding 参数**

在 `_buildLyricsList` 方法中，找到 `ListView.builder` 的 `padding` 参数：

当前代码：
```dart
padding: const EdgeInsets.symmetric(vertical: 16),
```

替换为：
```dart
padding: EdgeInsets.only(
  top: MediaQuery.of(context).size.height / 2,
  bottom: MediaQuery.of(context).size.height / 2,
),
```

注意：移除 `const` 关键字，因为 padding 值现在是运行时计算的。

- [ ] **Step 2: 运行应用验证**

Run: `cd mysic_flutter && flutter run -d windows`

验证步骤：
1. 扫描音乐并播放一首歌
2. 点击主页歌词区域进入歌词页面
3. 确认当前歌唱的歌词行在屏幕可视区域中间
4. 滚动到歌词列表顶部，确认第一行歌词也能居中
5. 滚动到歌词列表底部，确认最后一行歌词也能居中
6. 等待歌曲播放到下一行，确认自动滚动仍然将新行居中

- [ ] **Step 3: 运行分析检查**

Run: `cd mysic_flutter && flutter analyze`

Expected: 无新增 warning 或 error

- [ ] **Step 4: 提交**

```bash
cd mysic_flutter && git add lib/features/lyrics/presentation/pages/lyrics_page.dart
cd mysic_flutter && git commit -m "fix(lyrics): 修复歌词页当前行不在视口中间的问题

- 将 ListView padding 从固定 16px 改为上下各半屏高度
- 确保 ensureVisible(alignment: 0.5) 在首尾行也能居中"
```
