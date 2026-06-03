# 歌词页面初始自动居中修复 实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 修复歌词页面首次进入时当前播放行未自动垂直居中的问题

**Architecture:** 在 `_scrollToCurrentLine` 方法中增加降级路径——当 `Scrollable.ensureVisible` 因目标 widget 未构建而失败时，用预估行高计算偏移量通过 `ScrollController.jumpTo` 滚动到目标区域，再在下一帧用 `ensureVisible` 修正到精确居中。

**Tech Stack:** Flutter, Dart, just_audio, Provider

---

### Task 1: 修改 `_scrollToCurrentLine` 方法增加降级路径

**Files:**
- Modify: `mysic_flutter/lib/features/lyrics/presentation/pages/lyrics_page.dart:39-49`

- [ ] **Step 1: 添加预估行高常量**

在 `_LyricsPageState` 类中（第 19 行附近），添加常量：

```dart
static const double _estimatedLineHeight = 48.0;
```

- [ ] **Step 2: 替换 `_scrollToCurrentLine` 方法**

将第 39-49 行的现有方法替换为：

```dart
void _scrollToCurrentLine(int index) {
  final key = _lineKeys[index];
  if (key != null && key.currentContext != null) {
    Scrollable.ensureVisible(
      key.currentContext!,
      alignment: 0.5,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
    return;
  }

  // 降级：目标行未构建，预估位置滚动
  if (!_scrollController.hasClients) return;
  final maxScroll = _scrollController.position.maxScrollExtent;
  final halfHeight = _scrollController.position.viewportDimension / 2;
  final targetOffset =
      (index * _estimatedLineHeight - halfHeight).clamp(0.0, maxScroll);
  _scrollController.jumpTo(targetOffset);

  // 下一帧用 ensureVisible 精确修正
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!mounted) return;
    final key = _lineKeys[index];
    if (key != null && key.currentContext != null) {
      Scrollable.ensureVisible(
        key.currentContext!,
        alignment: 0.5,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
      );
    }
  });
}
```

- [ ] **Step 3: 运行代码分析确认无错误**

Run: `cd mysic_flutter && flutter analyze lib/features/lyrics/presentation/pages/lyrics_page.dart`
Expected: No issues found

- [ ] **Step 4: 提交**

```bash
cd mysic_flutter
git add lib/features/lyrics/presentation/pages/lyrics_page.dart
git commit -m "fix(lyrics): 修复歌词页面初始进入时当前播放行未自动居中"
```

---

### Task 2: 手动验证

**Files:** 无代码改动

- [ ] **Step 1: 启动应用**

Run: `cd mysic_flutter && flutter run -d windows`

- [ ] **Step 2: 验证初始居中**

1. 在主页播放一首有歌词的歌曲
2. 等歌曲播放到中间位置
3. 点击主页歌词预览区域进入歌词页面
4. 确认当前播放行自动居中显示

- [ ] **Step 3: 验证行切换滚动无回归**

1. 在歌词页面等待歌曲播放到下一行
2. 确认新行自动滚动居中

- [ ] **Step 4: 验证空歌词无回归**

1. 播放一首没有歌词的歌曲
2. 进入歌词页面
3. 确认显示"暂无歌词"占位

- [ ] **Step 5: 验证点击跳转无回归**

1. 在歌词页面点击某一行歌词
2. 确认播放位置跳转到对应时间
