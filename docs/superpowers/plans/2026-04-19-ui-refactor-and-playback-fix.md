# UI 重构与播放功能修复实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 重构主页面为播放器布局（与 index.html 一致），修复扫描后无法播放的问题。

**Architecture:** 主页面直接显示播放器界面（圆形专辑封面、歌词预览、播放控制）；抽屉添加播放模式选择；点击歌单自动加载歌曲到播放器并开始播放。

**Tech Stack:** Flutter, Provider, just_audio

---

## Task 1: 修改抽屉组件添加播放模式选择区

**Files:**
- Modify: `mysic_flutter/lib/shared/widgets/app_drawer.dart`

- [ ] **Step 1: 添加播放模式选择区到抽屉**

在 `_buildScanButton` 方法之前添加播放模式选择区：

```dart
Widget _buildPlayModeSection(BuildContext context) {
  return Consumer<PlayerProvider>(
    builder: (context, playerProvider, child) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '播放模式',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.muted,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _ModeButton(
                    icon: Icons.play_arrow_rounded,
                    label: '顺序',
                    isSelected: !playerProvider.isShuffleMode &&
                        playerProvider.loopMode == MysicLoopMode.off,
                    onTap: () => _setPlayMode(
                      context,
                      shuffle: false,
                      loop: MysicLoopMode.off,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ModeButton(
                    icon: Icons.shuffle_rounded,
                    label: '随机',
                    isSelected: playerProvider.isShuffleMode,
                    onTap: () => _setPlayMode(
                      context,
                      shuffle: true,
                      loop: MysicLoopMode.off,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ModeButton(
                    icon: Icons.repeat_rounded,
                    label: '循环',
                    isSelected: playerProvider.loopMode != MysicLoopMode.off,
                    onTap: () => _setPlayMode(
                      context,
                      shuffle: false,
                      loop: playerProvider.loopMode == MysicLoopMode.off
                          ? MysicLoopMode.all
                          : playerProvider.loopMode,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    },
  );
}

void _setPlayMode(BuildContext context, {
  required bool shuffle,
  required MysicLoopMode loop,
}) {
  final playerProvider = context.read<PlayerProvider>();
  if (shuffle) {
    playerProvider.toggleShuffleMode();
  } else if (playerProvider.isShuffleMode) {
    playerProvider.toggleShuffleMode();
  }
  if (loop != MysicLoopMode.off) {
    playerProvider.setLoopMode(loop);
  }
  Navigator.of(context).pop();
}
```

- [ ] **Step 2: 添加模式按钮组件**

```dart
class _ModeButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _ModeButton({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected
          ? AppColors.accent.withValues(alpha: 0.15)
          : AppColors.card,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            border: Border.all(
              color: isSelected ? AppColors.accent : Colors.transparent,
              width: 1,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 24,
                color: isSelected ? AppColors.accent : AppColors.muted,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: isSelected ? AppColors.accent : AppColors.muted,
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

- [ ] **Step 3: 更新 build 方法添加播放模式区**

修改 `build` 方法，在 `_buildHeader` 后添加 `_buildPlayModeSection`：

```dart
@override
Widget build(BuildContext context) {
  return Drawer(
    backgroundColor: AppColors.surface,
    child: SafeArea(
      child: Column(
        children: [
          _buildHeader(context),
          const Divider(color: AppColors.card, height: 1),
          _buildPlayModeSection(context),  // 新增
          const Divider(color: AppColors.card, height: 1),
          _buildScanButton(context),
          const Divider(color: AppColors.card, height: 1),
          Expanded(child: _buildPlaylistSection(context)),
          const Divider(color: AppColors.card, height: 1),
          _buildFooter(context),
        ],
      ),
    ),
  );
}
```

- [ ] **Step 4: 添加必要的 import**

在文件顶部添加：

```dart
import 'package:provider/provider.dart';
import '../../features/player/presentation/providers/player_provider.dart';
import '../../features/player/data/services/audio_player_service.dart';
```

- [ ] **Step 5: 提交修改**

```bash
git add mysic_flutter/lib/shared/widgets/app_drawer.dart
git commit -m "feat(drawer): 添加播放模式选择区"
```

---

## Task 2: 重构主页面为播放器布局

**Files:**
- Modify: `mysic_flutter/lib/main.dart`

- [ ] **Step 1: 重构 _buildBody 方法为播放器布局**

替换 `_buildBody` 方法：

```dart
Widget _buildBody(BuildContext context, PlayerProvider playerProvider) {
  final currentSong = playerProvider.currentSong;
  final hasSong = currentSong != null;

  return SafeArea(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 20),

          // 专辑封面
          Expanded(
            flex: 3,
            child: Center(
              child: GestureDetector(
                onTap: hasSong ? null : _startScan,
                child: AlbumCover(
                  song: currentSong,
                  size: 260,
                  isPlaying: playerProvider.isPlaying,
                ),
              ),
            ),
          ),

          const SizedBox(height: 32),

          // 歌曲信息
          _buildSongInfo(currentSong),

          const SizedBox(height: 16),

          // 歌词预览
          if (hasSong) _buildLyricsPreview(context, playerProvider),

          const SizedBox(height: 24),

          // 进度条
          ProgressBar(
            position: playerProvider.position,
            duration: playerProvider.duration,
            enabled: playerProvider.hasCurrentSong,
            onSeek: (progress) => playerProvider.seekToProgress(progress),
          ),

          const SizedBox(height: 24),

          // 播放控制
          PlayControls(
            isPlaying: playerProvider.isPlaying,
            isLoading: playerProvider.isLoading,
            hasPlaylist: playerProvider.hasPlaylist,
            onPlayPause: () => playerProvider.togglePlayPause(),
            onNext: () => playerProvider.next(),
            onPrevious: () => playerProvider.previous(),
          ),

          const SizedBox(height: 16),

          // 扩展控制
          ExtendedControls(
            isShuffleMode: playerProvider.isShuffleMode,
            loopMode: playerProvider.loopMode,
            onToggleShuffle: () => playerProvider.toggleShuffleMode(),
            onToggleLoop: () => playerProvider.toggleLoopMode(),
          ),

          const SizedBox(height: 24),
        ],
      ),
    ),
  );
}
```

- [ ] **Step 2: 添加歌曲信息组件**

```dart
Widget _buildSongInfo(Song? song) {
  return Column(
    children: [
      Text(
        song?.title ?? '未选择歌曲',
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 8),
      Text(
        song != null
            ? '${song.displayArtist} · ${song.displayAlbum}'
            : '扫描本地音乐开始播放',
        style: const TextStyle(
          fontSize: 14,
          color: Color(0xFF9CA3AF),
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
      ),
    ],
  );
}
```

- [ ] **Step 3: 添加歌词预览组件**

```dart
Widget _buildLyricsPreview(BuildContext context, PlayerProvider provider) {
  return GestureDetector(
    onTap: () => _openLyricsPage(context),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          const Text(
            '为你弹奏肖邦的夜曲',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF9CA3AF),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          const Text(
            '纪念我死去的爱情',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Color(0xFF10B981),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    ),
  );
}
```

- [ ] **Step 4: 删除不再需要的 _buildContent 和 _buildQuickAction 方法**

删除以下方法：
- `_buildContent`
- `_buildQuickAction`
- `_buildMiniPlayer`

- [ ] **Step 5: 更新 floatingActionButton 为 null**

修改 `build` 方法中的 `floatingActionButton`：

```dart
floatingActionButton: null,
```

- [ ] **Step 6: 添加必要的 import**

确保文件顶部有以下 import：

```dart
import 'features/player/presentation/widgets/album_cover.dart';
import 'features/player/presentation/widgets/play_controls.dart';
import 'features/player/presentation/widgets/progress_bar.dart';
```

- [ ] **Step 7: 提交修改**

```bash
git add mysic_flutter/lib/main.dart
git commit -m "refactor(main): 重构主页面为播放器布局"
```

---

## Task 3: 修复播放功能 - 点击歌单自动播放

**Files:**
- Modify: `mysic_flutter/lib/main.dart`

- [ ] **Step 1: 修改 onPlaylistTap 回调**

找到 `onPlaylistTap` 回调并修改：

```dart
onPlaylistTap: (playlist) async {
  final playlistId = playlist.id;
  if (playlistId == null) return;

  // 1. 选择歌单（加载歌曲）
  await playlistProvider.selectPlaylist(playlistId);

  // 2. 获取歌曲列表
  final songs = playlistProvider.selectedPlaylistSongs;

  if (songs.isNotEmpty) {
    // 3. 设置播放列表并播放
    await playerProvider.setPlaylist(songs);
    await playerProvider.play();
  }

  // 4. 抽屉会自动关闭（在 AppDrawer 中处理）
},
```

- [ ] **Step 2: 提交修改**

```bash
git add mysic_flutter/lib/main.dart
git commit -m "fix(player): 修复点击歌单无法播放的问题"
```

---

## Task 4: 添加首次使用引导

**Files:**
- Modify: `mysic_flutter/lib/main.dart`

- [ ] **Step 1: 在空状态时显示扫描引导**

修改 `_buildBody` 中的专辑封面部分，当没有歌曲时显示扫描引导：

```dart
// 专辑封面
Expanded(
  flex: 3,
  child: Center(
    child: GestureDetector(
      onTap: hasSong ? null : _startScan,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AlbumCover(
            song: currentSong,
            size: 260,
            isPlaying: playerProvider.isPlaying,
          ),
          // 首次使用引导
          if (!hasSong && !_isScanning)
            Positioned(
              bottom: -40,
              child: ElevatedButton.icon(
                onPressed: _startScan,
                icon: const Icon(Icons.folder_open_rounded),
                label: const Text('扫描本地音乐'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  ),
),
```

- [ ] **Step 2: 提交修改**

```bash
git add mysic_flutter/lib/main.dart
git commit -m "feat(ui): 添加首次使用扫描引导"
```

---

## Task 5: 验证与测试

- [ ] **Step 1: 运行 Flutter 应用**

```bash
cd mysic_flutter && flutter run -d windows
```

- [ ] **Step 2: 验证主页面布局**

检查：
- [ ] 专辑封面为圆形
- [ ] 播放时封面有动画效果
- [ ] 进度条正常显示
- [ ] 播放控制按钮可用

- [ ] **Step 3: 验证抽屉功能**

检查：
- [ ] 抽屉有播放模式选择区
- [ ] 点击模式按钮可以切换模式
- [ ] 当前选中模式高亮显示

- [ ] **Step 4: 验证播放功能**

检查：
- [ ] 点击"扫描全盘"可以扫描音乐
- [ ] 扫描后点击歌单可以播放音乐
- [ ] 播放/暂停、上一首、下一首正常工作

- [ ] **Step 5: 最终提交**

```bash
git add -A
git commit -m "feat: 完成 UI 重构与播放功能修复"
```
