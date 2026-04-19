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
    return Consumer<PlayerProvider>(
      builder: (context, playerProvider, child) {
        // 从 Provider 获取扫描进度
        final scanProgress = playerProvider.scanProgress ?? 0.0;
        final isScanning = playerProvider.isScanning;

        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: isScanning ? null : () {
              Navigator.of(context).pop();
              onScanTap?.call();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Stack(
                children: [
                  // 进度条背景 - 设计稿: bg-accent/30
                  if (isScanning)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.accent.withValues(alpha: 0.30),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: scanProgress.clamp(0.0, 1.0),
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppColors.accent.withValues(alpha: 0.50),
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ),

                  // 按钮内容
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.accent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: isScanning
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.accent),
                                ),
                              )
                            : const Icon(
                                Icons.folder_open_rounded,
                                color: AppColors.accent,
                                size: 22,
                              ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isScanning ? '扫描中...' : '本地音乐',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: AppColors.white,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              isScanning
                                  ? '${(scanProgress * 100).toInt()}%'
                                  : '扫描设备中的音乐文件',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
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
/// 设计稿规范：歌单图标 40px (w-10 h-10)，渐变背景，hover bg-white/5
class _PlaylistListTile extends StatefulWidget {
  final Playlist playlist;
  final bool isSelected;
  final VoidCallback? onTap;

  const _PlaylistListTile({
    required this.playlist,
    this.isSelected = false,
    this.onTap,
  });

  @override
  State<_PlaylistListTile> createState() => _PlaylistListTileState();
}

class _PlaylistListTileState extends State<_PlaylistListTile> {
  bool _isHovering = false;

  /// 根据歌单类型返回对应的渐变色
  LinearGradient _getGradientForPlaylist(Playlist playlist) {
    // 基于歌单 ID 或名称选择渐变色
    final name = playlist.name.toLowerCase();

    if (name.contains('喜欢') || name.contains('favorite')) {
      return AppColors.roseGradient; // 红色渐变
    } else if (name.contains('最近') || name.contains('recent')) {
      return AppColors.blueGradient; // 蓝色渐变
    } else if (name.contains('轻音乐') || name.contains('chill')) {
      return AppColors.emeraldGradient; // 绿色渐变
    } else if (name.contains('运动') || name.contains('workout')) {
      return AppColors.orangeGradient; // 橙色渐变
    } else if (name.contains('助眠') || name.contains('sleep')) {
      return AppColors.violetGradient; // 紫色渐变
    } else if (name.contains('全部') || name.contains('all')) {
      return AppColors.accentGradient; // accent 渐变
    }

    // 默认使用 accent 渐变
    return AppColors.accentGradient;
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: Material(
        color: widget.isSelected
            ? AppColors.accent.withValues(alpha: 0.15)
            : _isHovering
                ? Colors.white.withValues(alpha: 0.05) // 设计稿要求 hover bg-white/5
                : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: widget.onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                // 歌单封面 - 设计稿：w-10 h-10 (40px)，渐变背景
                Container(
                  width: 40, // 设计稿要求 40px
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: widget.playlist.coverPath == null
                        ? _getGradientForPlaylist(widget.playlist)
                        : null,
                    color: widget.playlist.coverPath != null
                        ? AppColors.card
                        : null,
                    borderRadius: BorderRadius.circular(8), // rounded-lg
                  ),
                  child: widget.playlist.coverPath != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            widget.playlist.coverPath!,
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
                        widget.playlist.name,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: widget.isSelected ? FontWeight.w600 : FontWeight.w500,
                          color: widget.isSelected ? AppColors.accent : AppColors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),

                      const SizedBox(height: 2),

                      // 歌曲数量
                      Text(
                        '${widget.playlist.songCount} 首歌曲',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),

                // 选中指示器
                if (widget.isSelected)
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
      ),
    );
  }

  Widget _buildDefaultIcon() {
    return const Icon(
      Icons.playlist_play_rounded,
      color: AppColors.white,
      size: 20,
    );
  }
}

/// 播放模式按钮
/// 设计稿规范：grid-cols-3，border border-white/10，hover:border-accent/50 hover:bg-white/5
class _ModeButton extends StatefulWidget {
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
  State<_ModeButton> createState() => _ModeButtonState();
}

class _ModeButtonState extends State<_ModeButton> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    // 设计稿：border border-white/10，选中或 hover 时 border-accent/50
    final borderColor = widget.isSelected
        ? AppColors.accent
        : _isHovering
            ? AppColors.accent.withValues(alpha: 0.5)
            : Colors.white.withValues(alpha: 0.1); // border-white/10

    // 设计稿：选中时 bg-accent/15，hover 时 bg-white/5
    final bgColor = widget.isSelected
        ? AppColors.accent.withValues(alpha: 0.15)
        : _isHovering
            ? Colors.white.withValues(alpha: 0.05) // hover:bg-white/5
            : AppColors.card;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: Material(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            // 设计稿：p-3 (12px 全方向)
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(
                color: borderColor,
                width: 1,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                // 设计稿：w-6 h-6 (24px)
                Icon(
                  widget.icon,
                  size: 24,
                  color: widget.isSelected
                      ? AppColors.accent
                      : _isHovering
                          ? AppColors.accent // hover 时图标变 accent
                          : AppColors.muted,
                ),
                const SizedBox(height: 8), // 设计稿 gap-2 (8px)
                // 设计稿：text-xs (12px)
                Text(
                  widget.label,
                  style: TextStyle(
                    fontSize: 12,
                    color: widget.isSelected
                        ? AppColors.accent
                        : _isHovering
                            ? AppColors.white // hover 时文字变 white
                            : AppColors.muted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
