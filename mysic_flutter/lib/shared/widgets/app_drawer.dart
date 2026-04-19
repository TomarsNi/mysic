import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../features/player/data/models/playlist.dart';
import '../../features/player/presentation/providers/player_provider.dart';
import '../../features/player/data/services/audio_player_service.dart';

/// 抽屉菜单组件
/// 左侧滑出的导航菜单，包含歌单列表和设置入口
class AppDrawer extends StatelessWidget {
  /// 当前选中的歌单 ID
  final int? selectedPlaylistId;

  /// 歌单列表
  final List<Playlist> playlists;

  /// 歌单点击回调
  final void Function(Playlist)? onPlaylistTap;

  /// 扫描音乐点击回调
  final VoidCallback? onScanTap;

  /// 设置点击回调
  final VoidCallback? onSettingsTap;

  /// 关于点击回调
  final VoidCallback? onAboutTap;

  /// 新建歌单点击回调
  final VoidCallback? onCreatePlaylistTap;

  const AppDrawer({
    super.key,
    this.selectedPlaylistId,
    this.playlists = const [],
    this.onPlaylistTap,
    this.onScanTap,
    this.onSettingsTap,
    this.onAboutTap,
    this.onCreatePlaylistTap,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: AppColors.surface,
      child: SafeArea(
        child: Column(
          children: [
            // 头部
            _buildHeader(context),

            const Divider(
              color: AppColors.card,
              height: 1,
            ),

            // 播放模式选择区
            _buildPlayModeSection(context),

            const Divider(
              color: AppColors.card,
              height: 1,
            ),

            // 扫描音乐按钮
            _buildScanButton(context),

            const Divider(
              color: AppColors.card,
              height: 1,
            ),

            // 歌单列表
            Expanded(
              child: _buildPlaylistSection(context),
            ),

            const Divider(
              color: AppColors.card,
              height: 1,
            ),

            // 底部设置区域
            _buildFooter(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Row(
        children: [
          // 应用图标
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: AppColors.accentGradient,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.music_note_rounded,
              color: AppColors.white,
              size: 28,
            ),
          ),

          const SizedBox(width: 16),

          // 应用名称
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Mysic',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.white,
                ),
              ),
              SizedBox(height: 2),
              Text(
                '本地音乐播放器',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.muted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

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
                      onTap: () {
                        final currentLoop = playerProvider.loopMode;
                        MysicLoopMode nextLoop;
                        switch (currentLoop) {
                          case MysicLoopMode.off:
                            nextLoop = MysicLoopMode.all;
                            break;
                          case MysicLoopMode.all:
                            nextLoop = MysicLoopMode.one;
                            break;
                          case MysicLoopMode.one:
                            nextLoop = MysicLoopMode.off;
                            break;
                        }
                        _setPlayMode(context, shuffle: false, loop: nextLoop);
                      },
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

    // Handle shuffle mode
    if (shuffle && !playerProvider.isShuffleMode) {
      playerProvider.toggleShuffleMode();
    } else if (!shuffle && playerProvider.isShuffleMode) {
      playerProvider.toggleShuffleMode();
    }

    // Handle loop mode
    if (loop != playerProvider.loopMode) {
      playerProvider.setLoopMode(loop);
    }

    Navigator.of(context).pop();
  }

  Widget _buildScanButton(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.accent.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(
          Icons.folder_open_rounded,
          color: AppColors.accent,
          size: 22,
        ),
      ),
      title: const Text(
        '本地音乐',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: AppColors.white,
        ),
      ),
      subtitle: const Text(
        '扫描设备中的音乐文件',
        style: TextStyle(
          fontSize: 12,
          color: AppColors.muted,
        ),
      ),
      onTap: () {
        Navigator.of(context).pop();
        onScanTap?.call();
      },
    );
  }

  Widget _buildPlaylistSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 歌单标题栏
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '我的歌单',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.muted,
                ),
              ),

              // 新建歌单按钮
              IconButton(
                icon: const Icon(
                  Icons.add_rounded,
                  color: AppColors.muted,
                  size: 20,
                ),
                onPressed: onCreatePlaylistTap,
                tooltip: '新建歌单',
              ),
            ],
          ),
        ),

        // 歌单列表
        Expanded(
          child: playlists.isEmpty
              ? _buildEmptyState(context)
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: playlists.length,
                  itemBuilder: (context, index) {
                    final playlist = playlists[index];
                    final isSelected = playlist.id == selectedPlaylistId;

                    return _PlaylistListTile(
                      playlist: playlist,
                      isSelected: isSelected,
                      onTap: () {
                        Navigator.of(context).pop();
                        onPlaylistTap?.call(playlist);
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.playlist_add_rounded,
            size: 48,
            color: AppColors.muted.withValues(alpha: 0.5),
          ),

          const SizedBox(height: 16),

          const Text(
            '暂无歌单',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.muted,
            ),
          ),

          const SizedBox(height: 8),

          TextButton.icon(
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('创建歌单'),
            onPressed: onCreatePlaylistTap,
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Column(
      children: [
        // 设置按钮
        ListTile(
          leading: const Icon(
            Icons.settings_rounded,
            color: AppColors.muted,
          ),
          title: const Text(
            '设置',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.white,
            ),
          ),
          onTap: () {
            Navigator.of(context).pop();
            onSettingsTap?.call();
          },
        ),

        // 关于按钮
        ListTile(
          leading: const Icon(
            Icons.info_outline_rounded,
            color: AppColors.muted,
          ),
          title: const Text(
            '关于',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.white,
            ),
          ),
          onTap: () {
            Navigator.of(context).pop();
            onAboutTap?.call();
          },
        ),
      ],
    );
  }
}

/// 歌单列表项
class _PlaylistListTile extends StatelessWidget {
  final Playlist playlist;
  final bool isSelected;
  final VoidCallback? onTap;

  const _PlaylistListTile({
    required this.playlist,
    this.isSelected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected
          ? AppColors.accent.withValues(alpha: 0.15)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              // 歌单封面
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: playlist.coverPath != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          playlist.coverPath!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _buildDefaultIcon(),
                        ),
                      )
                    : _buildDefaultIcon(),
              ),

              const SizedBox(width: 12),

              // 歌单信息
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 歌单名称
                    Text(
                      playlist.name,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                        color: isSelected ? AppColors.accent : AppColors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),

                    const SizedBox(height: 2),

                    // 歌曲数量
                    Text(
                      '${playlist.songCount} 首歌曲',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),

              // 选中指示器
              if (isSelected)
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: AppColors.accent,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDefaultIcon() {
    return const Icon(
      Icons.playlist_play_rounded,
      color: AppColors.muted,
      size: 24,
    );
  }
}

/// 播放模式按钮
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
