# 歌词自动居中滚动设计

## 问题

点击主页歌词进入歌词页面后，当前歌唱的歌词行没有在屏幕可视区域的中间位置。这个问题在任何时刻都存在——刚进入页面时和播放过程中都不居中。

## 根因

`_scrollToCurrentLine()` 使用 `Scrollable.ensureVisible(alignment: 0.5)` 将当前歌词行对齐到视口中心。但 `alignment: 0.5` 要求列表有足够的滚动空间才能将目标行推到视口中间。当目标行在列表首部或尾部时，ListView 没有足够的滚动空间，导致无法真正居中。

此外，ListView 只有 `vertical: 16` 的固定 padding，在首尾行附近无法提供居中所需的虚拟空间。

## 方案

### 选中方案：上下半屏 padding

在 ListView 顶部和底部各添加等于视口高度一半的 padding/空白区域。这样即使当前歌词是第一行或最后一行，也有足够的空间将其推到视口中间。

### 改动范围

仅修改 `lib/features/lyrics/presentation/pages/lyrics_page.dart` 中的 `_buildLyricsList` 方法：

- 将 `padding: const EdgeInsets.symmetric(vertical: 16)` 替换为动态 padding
- 顶部 padding = `MediaQuery.of(context).size.height / 2`
- 底部 padding = `MediaQuery.of(context).size.height / 2`

### 不改动的部分

- `_scrollToCurrentLine()` 方法：保持 `ensureVisible` + `alignment: 0.5`
- 歌词行渲染逻辑
- 歌词解析逻辑

### 效果

- 所有场景下当前歌词行都在视口中间：刚进入页面、播放中切换行、首行/末行
- 用户仍可自由上下滚动查看其他歌词
- 松手后自动滚动会重新将当前行居中（现有行为）
