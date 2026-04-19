import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/models/song.dart';
import '../providers/player_provider.dart';
import '../widgets/album_cover.dart';
import '../widgets/play_controls.dart';
import '../widgets/progress_bar.dart';

/// 主播放页面
/// 整合所有播放组件，包含歌词预览
class PlayerPage extends StatelessWidget {
  const PlayerPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<PlayerProvider>(
      builder: (context, playerProvider, child) {
        return Scaffold(
          backgroundColor: AppColors.surface,
          appBar: _buildAppBar(context, playerProvider),
          body: _buildBody(context, playerProvider),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, PlayerProvider provider) {
    return AppBar(
      backgroundColor: AppColors.surface,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.keyboard_arrow_down_rounded),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: const Text(
        '正在播放',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
      centerTitle: true,
      actions: [
        IconButton(
          icon: const Icon(Icons.more_vert_rounded),
          onPressed: () {
            _showMoreOptions(context, provider);
          },
        ),
      ],
    );
  }

  Widget _buildBody(BuildContext context, PlayerProvider provider) {
    final currentSong = provider.currentSong;

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
                child: AlbumCover(
                  song: currentSong,
                  size: 260,
                  isPlaying: provider.isPlaying,
                ),
              ),
            ),

            const SizedBox(height: 32),

            // 歌曲信息
            _buildSongInfo(currentSong),

            const SizedBox(height: 16),

            // 歌词预览（两行）
            _buildLyricsPreview(context, provider),

            const SizedBox(height: 24),

            // 进度条
            ProgressBar(
              position: provider.position,
              duration: provider.duration,
              enabled: provider.hasCurrentSong,
              onSeek: (progress) => provider.seekToProgress(progress),
            ),

            const SizedBox(height: 24),

            // 播放控制
            PlayControls(
              isPlaying: provider.isPlaying,
              isLoading: provider.isLoading,
              hasPlaylist: provider.hasPlaylist,
              onPlayPause: () => provider.togglePlayPause(),
              onNext: () => provider.next(),
              onPrevious: () => provider.previous(),
            ),

            const SizedBox(height: 16),

            // 扩展控制
            ExtendedControls(
              isShuffleMode: provider.isShuffleMode,
              loopMode: provider.loopMode,
              onToggleShuffle: () => provider.toggleShuffleMode(),
              onToggleLoop: () => provider.toggleLoopMode(),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSongInfo(Song? song) {
    return Column(
      children: [
        // 歌曲标题
        Text(
          song?.title ?? '未选择歌曲',
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: AppColors.white,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: 8),

        // 艺术家和专辑
        Text(
          song != null ? '${song.displayArtist} · ${song.displayAlbum}' : '请选择要播放的歌曲',
          style: const TextStyle(
            fontSize: 14,
            color: AppColors.muted,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildLyricsPreview(BuildContext context, PlayerProvider provider) {
    // TODO: 实现真实歌词预览
    // 目前显示占位文本
    // 设计稿规范：
    // - 两行歌词：当前行 lg font-medium white，下一行 muted
    // - hover:bg-white/5，圆角 rounded-xl
    // - 点击可进入歌词页面
    final currentSong = provider.currentSong;

    if (currentSong == null) {
      return const SizedBox.shrink();
    }

    return _LyricsPreviewWidget(
      currentLyric: '这是当前播放的歌词行',
      nextLyric: '这是下一句歌词',
      onTap: () => _navigateToLyricsPage(context, provider),
    );
  }

  void _navigateToLyricsPage(BuildContext context, PlayerProvider provider) {
    // 导航到歌词页面
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const LyricsPage(),
      ),
    );
  }

  void _showMoreOptions(BuildContext context, PlayerProvider provider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => _MoreOptionsSheet(provider: provider),
    );
  }
}

/// 歌词页面（占位）
class LyricsPage extends StatelessWidget {
  const LyricsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('歌词'),
      ),
      body: const Center(
        child: Text(
          '歌词页面\n将在 task_3_5 中实现',
          style: TextStyle(
            fontSize: 16,
            color: AppColors.muted,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

/// 歌词预览组件
/// 设计稿规范：
/// - 当前行：text-lg (18px) font-medium white，mb-1
/// - 下一行：text-sm muted
/// - hover:bg-white/5，rounded-xl，py-3
/// - 点击可进入歌词页面
class _LyricsPreviewWidget extends StatefulWidget {
  final String currentLyric;
  final String nextLyric;
  final VoidCallback? onTap;

  const _LyricsPreviewWidget({
    required this.currentLyric,
    required this.nextLyric,
    this.onTap,
  });

  @override
  State<_LyricsPreviewWidget> createState() => _LyricsPreviewWidgetState();
}

class _LyricsPreviewWidgetState extends State<_LyricsPreviewWidget> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 12), // 设计稿 py-3
          decoration: BoxDecoration(
            color: _isHovering
                ? Colors.white.withValues(alpha: 0.05) // 设计稿 hover:bg-white/5
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12), // 设计稿 rounded-xl
          ),
          child: Column(
            children: [
              // 当前歌词行 - 设计稿：text-lg font-medium white mb-1
              Text(
                widget.currentLyric,
                style: const TextStyle(
                  fontSize: 18, // 设计稿 text-lg
                  fontWeight: FontWeight.w500, // 设计稿 font-medium
                  color: AppColors.white, // 设计稿 white
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),

              const SizedBox(height: 4), // 设计稿 mb-1

              // 下一行歌词 - 设计稿：text-sm text-muted
              Text(
                widget.nextLyric,
                style: const TextStyle(
                  fontSize: 14, // 设计稿 text-sm
                  color: AppColors.muted, // 设计稿 muted
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 更多选项底部面板
class _MoreOptionsSheet extends StatelessWidget {
  final PlayerProvider provider;

  const _MoreOptionsSheet({required this.provider});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),

          // 拖动指示器
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.muted.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          const SizedBox(height: 24),

          // 选项列表
          ListTile(
            leading: const Icon(Icons.playlist_add_rounded),
            title: const Text('添加到歌单'),
            onTap: () {
              Navigator.pop(context);
              // TODO: 实现添加到歌单功能
            },
          ),

          ListTile(
            leading: const Icon(Icons.share_rounded),
            title: const Text('分享'),
            onTap: () {
              Navigator.pop(context);
              // TODO: 实现分享功能
            },
          ),

          ListTile(
            leading: const Icon(Icons.timer_rounded),
            title: const Text('定时关闭'),
            onTap: () {
              Navigator.pop(context);
              // TODO: 实现定时关闭功能
            },
          ),

          ListTile(
            leading: const Icon(Icons.speed_rounded),
            title: const Text('播放速度'),
            trailing: const Text('1.0x'),
            onTap: () {
              Navigator.pop(context);
              _showSpeedDialog(context);
            },
          ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  void _showSpeedDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text('播放速度'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [0.5, 0.75, 1.0, 1.25, 1.5, 2.0].map((speed) {
            return ListTile(
              title: Text('${speed}x'),
              onTap: () {
                provider.setSpeed(speed);
                Navigator.pop(context);
              },
            );
          }).toList(),
        ),
      ),
    );
  }
}
