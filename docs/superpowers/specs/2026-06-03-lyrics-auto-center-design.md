# 歌词页面初始自动居中修复

## 问题

Android 上点击主页预览歌词进入歌词页面后，当前正在播放的歌词行没有自动垂直居中，页面显示在歌词列表开头。

### 根因

`ListView.builder` 使用懒加载，进入歌词页面时当前播放行可能不在可视区域，对应的 widget 未被构建。`_scrollToCurrentLine` 依赖 `GlobalKey.currentContext` 定位，当 `currentContext` 为 null 时直接 return，导致初始滚动失败。

后续行切换时目标行已在可视区域附近，`ensureVisible` 正常工作，因此只有首次进入页面时出现问题。

## 方案

在 `_scrollToCurrentLine` 中增加降级路径：当 `ensureVisible` 不可用时，用预估位置通过 `ScrollController.jumpTo` 滚动到目标区域，再在下一帧用 `ensureVisible` 修正到精确居中。

### 预估行高

歌词行组件 padding `vertical: 8`（16px），活跃行字体 18px / 普通行 14px，`maxLines: 2` 余量，预估行高 **48px**。

### 代码改动

仅修改 `lib/features/lyrics/presentation/pages/lyrics_page.dart`：

1. 添加常量 `_estimatedLineHeight = 48.0`
2. 修改 `_scrollToCurrentLine` 方法：
   - 首选路径：`Scrollable.ensureVisible`（现有逻辑不变）
   - 降级路径：`currentContext` 为 null 时，计算 `index * _estimatedLineHeight - halfViewportHeight`，`clamp` 到合法范围后 `jumpTo`，然后在下一帧 `ensureVisible` 精确修正

```dart
static const double _estimatedLineHeight = 48.0;

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
  final maxScroll = _scrollController.position.maxScrollExtent;
  final halfHeight = _scrollController.position.viewportDimension / 2;
  final targetOffset = (index * _estimatedLineHeight - halfHeight)
      .clamp(0.0, maxScroll);
  _scrollController.jumpTo(targetOffset);

  // 下一帧用 ensureVisible 精确修正
  WidgetsBinding.instance.addPostFrameCallback((_) {
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

### 不改动的部分

- 行切换时的自动滚动逻辑（已有且正常工作）
- 用户手动滚动行为（不在本次修复范围）
- 歌词行组件、Provider、数据层

## 验证标准

1. 进入歌词页面时，当前播放行自动居中显示
2. 歌曲播放中行切换时，自动滚动居中（无回归）
3. 歌词为空时，显示"暂无歌词"占位（无回归）
4. 点击歌词行跳转到对应时间（无回归）
