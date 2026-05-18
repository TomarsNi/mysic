# 播放列表自动滚动优化设计

## 问题描述

首页歌单歌曲列表页面（`PlaylistQueueSheet`）打开时，有时没有自动滚动到当前播放的歌曲位置，需要手动滑动查找。

## 根本原因

当前实现使用 `GlobalKey` + `Scrollable.ensureVisible` 的方式滚动到当前歌曲，存在以下问题：

1. **GlobalKey context 可能为空**：在 `initState` 中调用滚动逻辑，但 ListView 的 item 可能还未渲染完成。
2. **延迟重试机制不可靠**：100ms 延迟可能不够，且只重试一次。
3. **DraggableScrollableSheet 展开动画干扰**：底部弹窗有约 300ms 的展开动画，期间滚动可能被动画打断。

## 解决方案

使用 `ScrollController` 精确计算滚动位置，并等待 `DraggableScrollableSheet` 展开动画完成后再执行滚动。

### 核心改动

1. **使用 ScrollController 计算滚动偏移**
   - 根据 `currentIndex` 和固定 item 高度（64px）计算目标滚动位置
   - 使用 `scrollController.animateTo` 执行滚动

2. **等待展开动画完成**
   - 延迟 350ms 等待 `DraggableScrollableSheet` 展开动画完成
   - 避免滚动被动画打断

3. **移除 GlobalKey 依赖**
   - 删除 `_currentItemKey` 字段
   - 删除 `_SongListTile` 中的 `key` 参数

### 代码修改

**文件**: `lib/shared/widgets/playlist_queue_sheet.dart`

```dart
class _PlaylistQueueSheetState extends State<PlaylistQueueSheet> {
  // 移除: final GlobalKey _currentItemKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _scrollToCurrentSong();
  }

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

  @override
  void didUpdateWidget(PlaylistQueueSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex) {
      _scrollToCurrentSong();
    }
  }

  @override
  Widget build(BuildContext context) {
    // ... 保持不变，移除 ListView.builder 中的 key 参数
    ListView.builder(
      controller: widget.scrollController,
      shrinkWrap: true,
      itemCount: widget.songs.length,
      itemBuilder: (context, index) {
        return _SongListTile(
          // 移除: key: index == widget.currentIndex ? _currentItemKey : null,
          song: widget.songs[index],
          isPlaying: index == widget.currentIndex,
          onTap: () => widget.onSongTap(index),
        );
      },
    ),
  }
}
```

### 测试验证

1. 打开播放列表弹窗，验证是否自动滚动到当前播放歌曲
2. 切换歌曲后重新打开弹窗，验证滚动位置是否正确
3. 当前歌曲在列表顶部/底部时，验证滚动边界处理是否正确
4. 快速连续打开/关闭弹窗，验证无异常

## 风险评估

- **低风险**：改动范围小，仅修改一个文件，逻辑清晰
- **边界情况**：已处理空列表、索引越界、scrollController 未挂载等情况
