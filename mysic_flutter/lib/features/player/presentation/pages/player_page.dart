import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/models/song.dart';
import '../providers/player_provider.dart';
import '../widgets/album_cover.dart';
import '../widgets/play_controls.dart';
import '../widgets/progress_bar.dart';
import '../widgets/song_edit_dialog.dart';
import '../../../lyrics/presentation/pages/lyrics_page.dart';
import '../../../playlist/presentation/providers/playlist_provider.dart';

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
        icon: const Icon(Icons.menu_rounded),
        onPressed: () {
          Scaffold.of(context).openDrawer();
        },
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
        _buildPopupMenu(context, provider),
      ],
    );
  }

  Widget _buildPopupMenu(BuildContext context, PlayerProvider provider) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.add_rounded),
      color: AppColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      offset: const Offset(0, 48),
      onSelected: (value) => _handleMenuAction(context, provider, value),
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          value: 'add_to_playlist',
          child: Row(
            children: [
              Icon(Icons.playlist_add, color: AppColors.white, size: 20),
              const SizedBox(width: 12),
              const Text('添加到歌单', style: TextStyle(color: AppColors.white)),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'edit',
          child: Row(
            children: [
              Icon(Icons.edit_rounded, color: AppColors.white, size: 20),
              const SizedBox(width: 12),
              const Text('编辑', style: TextStyle(color: AppColors.white)),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem<String>(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete_rounded, color: const Color(0xFFEF4444), size: 20),
              const SizedBox(width: 12),
              const Text('删除', style: TextStyle(color: Color(0xFFEF4444))),
            ],
          ),
        ),
      ],
    );
  }

  void _handleMenuAction(
    BuildContext context,
    PlayerProvider provider,
    String action,
  ) {
    switch (action) {
      case 'add_to_playlist':
        if (provider.currentSong == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('请先选择歌曲')),
          );
          return;
        }
        _showAddToPlaylistSheet(context, provider);
        break;
      case 'edit':
        if (provider.currentSong == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('请先选择歌曲')),
          );
          return;
        }
        _showEditDialog(context, provider.currentSong!);
        break;
      case 'delete':
        if (provider.currentSong == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('请先选择歌曲')),
          );
          return;
        }
        _showDeleteConfirmSheet(context, provider);
        break;
    }
  }

  /// 显示编辑对话框
  void _showEditDialog(BuildContext context, Song song) {
    showSongEditDialog(
      context: context,
      song: song,
      onSave: (updatedSong) async {
        final provider = context.read<PlayerProvider>();
        await provider.updateSong(updatedSong);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('歌曲信息已更新'),
              backgroundColor: AppColors.accent,
            ),
          );
        }
      },
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
            fontSize: 24, // 设计稿：text-2xl (24px)
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
    // 设计稿规范：
    // - 两行歌词：当前行 lg font-medium white，下一行 muted
    // - hover:bg-white/5，圆角 rounded-xl
    // - 点击可进入歌词页面
    final currentSong = provider.currentSong;

    if (currentSong == null) {
      return const SizedBox.shrink();
    }

    // 获取真实歌词数据
    final currentLyric = provider.currentLyricLine?.text;
    final nextLyric = provider.nextLyricLine?.text;

    // 如果没有歌词，显示占位文本
    final displayCurrentLyric = currentLyric ?? '暂无歌词';
    final displayNextLyric = nextLyric ?? '';

    return _LyricsPreviewWidget(
      currentLyric: displayCurrentLyric,
      nextLyric: displayNextLyric,
      hasLyrics: provider.hasLyrics,
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

  void _showAddToPlaylistSheet(BuildContext context, PlayerProvider provider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => _AddToPlaylistSheet(provider: provider),
    );
  }
}

/// 添加到歌单底部面板
/// 设计稿规范：
/// - 当前行：text-lg (18px) font-medium white，mb-1
/// - 下一行：text-sm muted
/// - hover:bg-white/5，rounded-xl，py-3
/// - 点击可进入歌词页面
class _LyricsPreviewWidget extends StatefulWidget {
  final String currentLyric;
  final String nextLyric;
  final bool hasLyrics;
  final VoidCallback? onTap;

  const _LyricsPreviewWidget({
    required this.currentLyric,
    required this.nextLyric,
    this.hasLyrics = false,
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

/// 添加到歌单底部面板
/// 设计稿规范：rounded-t-3xl，拖拽指示条 w-10 h-1
class _AddToPlaylistSheet extends StatelessWidget {
  final PlayerProvider provider;

  const _AddToPlaylistSheet({required this.provider});

  @override
  Widget build(BuildContext context) {
    final currentSong = provider.currentSong;

    return Consumer<PlaylistProvider>(
      builder: (context, playlistProvider, child) {
        final playlists = playlistProvider.playlists;

        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),

              // 拖动指示器 - 设计稿：w-10 h-1 bg-white/20
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.muted.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              const SizedBox(height: 24),

              // 标题
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '添加到歌单',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppColors.white,
                      ),
                    ),
                    if (currentSong == null)
                      const Text(
                        '请先选择歌曲',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.muted,
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // 歌单列表
              if (currentSong == null)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    '当前没有播放中的歌曲',
                    style: TextStyle(color: AppColors.muted),
                  ),
                )
              else if (playlists.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    '暂无歌单，请先创建歌单',
                    style: TextStyle(color: AppColors.muted),
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: playlists.length,
                  itemBuilder: (context, index) {
                    final playlist = playlists[index];
                    final songCount = playlist.songs?.length ?? 0;

                    return ListTile(
                      leading: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          gradient: AppColors.accentGradient,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.music_note_rounded,
                          color: AppColors.white,
                        ),
                      ),
                      title: Text(playlist.name),
                      subtitle: Text('$songCount 首'),
                      onTap: () async {
                        final playlistId = playlist.id;
                        if (playlistId == null) return;

                        Navigator.pop(context);
                        await _addSongToPlaylist(
                          context,
                          playlistProvider,
                          playlistId,
                          currentSong,
                        );
                      },
                    );
                  },
                ),

              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Future<void> _addSongToPlaylist(
    BuildContext context,
    PlaylistProvider playlistProvider,
    int playlistId,
    Song song,
  ) async {
    // 检查歌曲是否已在歌单中
    final isInPlaylist = await playlistProvider.isSongInPlaylist(
      playlistId,
      song.id!,
    );

    if (!context.mounted) return;

    if (isInPlaylist) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('歌曲已在该歌单中'),
          backgroundColor: AppColors.muted,
        ),
      );
      return;
    }

    final success = await playlistProvider.addSongToPlaylist(playlistId, song);

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success ? '已添加到歌单' : '添加失败'),
        backgroundColor: success ? AppColors.accent : Colors.red,
      ),
    );
  }
}
