# 播放队列弹窗功能实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在首页右下角新增按钮，点击后以底部弹窗展示当前播放歌单的歌曲列表，用户可点击歌曲切换播放。

**Architecture:** 创建独立的 `PlaylistQueueSheet` 组件，通过 `showModalBottomSheet` 调用。从 `PlayerProvider` 获取播放列表数据和当前索引，点击歌曲时调用 `seekToIndex` 方法切换播放。

**Tech Stack:** Flutter, Provider, showModalBottomSheet

---

## 文件结构

```
lib/
├── main.dart                           # 修改：添加 FAB
└── shared/
    └── widgets/
        └── playlist_queue_sheet.dart   # 新增：播放队列弹窗组件
```

---

### Task 1: 创建 PlaylistQueueSheet 组件

**Files:**
- Create: `mysic_flutter/lib/shared/widgets/playlist_queue_sheet.dart`

- [ ] **Step 1: 创建 PlaylistQueueSheet 组件文件**

```dart
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../features/player/data/models/song.dart';

/// 播放队列底部弹窗
/// 展示当前播放歌单的歌曲列表，用户可点击歌曲切换播放
class PlaylistQueueSheet extends StatelessWidget {
  /// 歌曲列表
  final List<Song> songs;

  /// 当前播放索引
  final int currentIndex;

  /// 歌单名称
  final String playlistName;

  /// 歌曲点击回调
  final void Function(int index) onSongTap;

  const PlaylistQueueSheet({
    super.key,
    required this.songs,
    required this.currentIndex,
    required this.playlistName,
    required this.onSongTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 拖拽指示条
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // 标题
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Text(
                  playlistName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.white,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: AppColors.muted),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),

          // 歌曲列表
          Flexible(
            child: songs.isEmpty
                ? const Center(
                    child: Text(
                      '播放列表为空',
                      style: TextStyle(color: AppColors.muted),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: songs.length,
                    itemBuilder: (context, index) {
                      return _SongListTile(
                        song: songs[index],
                        isPlaying: index == currentIndex,
                        onTap: () => onSongTap(index),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// 歌曲列表项
class _SongListTile extends StatelessWidget {
  final Song song;
  final bool isPlaying;
  final VoidCallback onTap;

  const _SongListTile({
    required this.song,
    required this.isPlaying,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: [
              // 播放图标或占位
              SizedBox(
                width: 24,
                child: isPlaying
                    ? const Icon(
                        Icons.volume_up_rounded,
                        color: AppColors.accent,
                        size: 20,
                      )
                    : null,
              ),

              const SizedBox(width: 12),

              // 歌曲信息
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 歌曲名
                    Text(
                      song.title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: isPlaying ? FontWeight.w600 : FontWeight.w500,
                        color: isPlaying ? AppColors.accent : AppColors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    // 艺术家
                    Text(
                      song.displayArtist,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.muted,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 12),

              // 时长
              Text(
                song.formattedDuration,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: 验证组件文件创建成功**

Run: `cd mysic_flutter && flutter analyze lib/shared/widgets/playlist_queue_sheet.dart`
Expected: No issues found

- [ ] **Step 3: 提交组件文件**

```bash
git add mysic_flutter/lib/shared/widgets/playlist_queue_sheet.dart
git commit -m "feat: 添加播放队列弹窗组件 PlaylistQueueSheet"
```

---

### Task 2: 在 main.dart 中添加 FAB 和弹窗调用

**Files:**
- Modify: `mysic_flutter/lib/main.dart`

- [ ] **Step 1: 添加 import 语句**

在 `main.dart` 文件顶部的 import 区域添加：

```dart
import 'shared/widgets/playlist_queue_sheet.dart';
```

位置：在 `import 'shared/widgets/delete_confirm_sheet.dart';` 之后

- [ ] **Step 2: 添加 floatingActionButton**

在 `_HomePageState.build` 方法中，将 `floatingActionButton: null,` 替换为：

```dart
          floatingActionButton: playerProvider.hasPlaylist
              ? Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: IconButton(
                    icon: const Icon(
                      Icons.queue_music_rounded,
                      color: AppColors.white,
                      size: 24,
                    ),
                    onPressed: () => _showPlaylistQueue(context),
                  ),
                )
              : null,
```

- [ ] **Step 3: 添加 _showPlaylistQueue 方法**

在 `_HomePageState` 类中添加方法（在 `_showAddToPlaylist` 方法之后）：

```dart
  void _showPlaylistQueue(BuildContext context) {
    final playerProvider = context.read<PlayerProvider>();
    final playlistProvider = context.read<PlaylistProvider>();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => PlaylistQueueSheet(
          songs: playerProvider.playlist,
          currentIndex: playerProvider.currentIndex,
          playlistName: playlistProvider.selectedPlaylist?.name ?? '播放列表',
          onSongTap: (index) {
            playerProvider.seekToIndex(index);
            Navigator.of(context).pop();
          },
        ),
      ),
    );
  }
```

- [ ] **Step 4: 验证代码无语法错误**

Run: `cd mysic_flutter && flutter analyze lib/main.dart`
Expected: No issues found

- [ ] **Step 5: 提交修改**

```bash
git add mysic_flutter/lib/main.dart
git commit -m "feat: 首页添加播放队列按钮，点击弹出歌曲列表"
```

---

### Task 3: 手动测试验证

- [ ] **Step 1: 运行应用**

Run: `cd mysic_flutter && flutter run -d windows`

- [ ] **Step 2: 验证功能**

手动验证以下功能：
1. 首页右下角显示圆形按钮（播放列表有歌曲时）
2. 点击按钮弹出底部弹窗
3. 弹窗标题显示当前歌单名称
4. 列表正确显示所有歌曲（歌曲名、艺术家、时长）
5. 当前播放歌曲高亮显示（accent 色文字 + 播放图标）
6. 点击歌曲能够切换播放
7. 点击弹窗外部或下滑可关闭弹窗
8. 播放列表为空时按钮不显示

---

## 验收清单

- [ ] 首页右下角显示按钮（播放列表有歌曲时）
- [ ] 点击按钮弹出底部弹窗
- [ ] 弹窗标题显示当前歌单名称
- [ ] 列表正确显示所有歌曲
- [ ] 当前播放歌曲高亮显示（accent 色 + 播放图标）
- [ ] 点击歌曲能够切换播放
- [ ] 点击弹窗外部或下滑可关闭弹窗
- [ ] 视觉效果符合设计稿规范
