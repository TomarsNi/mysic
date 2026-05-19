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

  /// 收藏歌单
  final Playlist? favoritesPlaylist;

  /// 歌单点击回调（支持异步）
  final Future<void> Function(Playlist)? onPlaylistTap;

  /// 收藏歌单点击回调
  final Future<void> Function(Playlist)? onFavoritesTap;

  /// 扫描设置点击回调
  final VoidCallback? onScanSettingsTap;

  /// 设置点击回调
  final VoidCallback? onSettingsTap;

  /// 关于点击回调
  final VoidCallback? onAboutTap;

  /// API 设置点击回调
  final VoidCallback? onApiSettingsTap;

  /// 新建歌单点击回调
  final VoidCallback? onCreatePlaylistTap;

  const AppDrawer({
    super.key,
    this.selectedPlaylistId,
    this.playlists = const [],
    this.favoritesPlaylist,
    this.onPlaylistTap,
    this.onFavoritesTap,
    this.onScanSettingsTap,
    this.onSettingsTap,
    this.onAboutTap,
    this.onApiSettingsTap,
    this.onCreatePlaylistTap,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: AppColors.card, // 设计稿：bg-card
      child: SafeArea(
        child: Column(
          children: [
            // 头部 - 设计稿：p-6 mb-8
            _buildHeader(context),

            // 播放模式选择区
            _buildPlayModeSection(context),

            // 收藏歌单入口
            _buildFavoritesSection(context),

            // 歌单列表（可滚动）
            Expanded(
              child: _buildPlaylistSection(context),
            ),

            // 底部区域：扫描按钮 + 关于按钮
            _buildFooter(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    // 设计稿：flex items-center justify-between mb-8
    // 左侧：h2 text-lg font-semibold "设置"
    // 右侧：关闭按钮 p-2 rounded-lg hover:bg-white/10
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24), // p-6
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 设置标题 - 设计稿：text-lg font-semibold
          const Text(
            '设置',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.white,
            ),
          ),

          // 关闭按钮 - 设计稿：p-2 rounded-lg hover:bg-white/10
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => Navigator.of(context).pop(),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.all(8),
                child: const Icon(
                  Icons.close_rounded,
                  size: 20,
                  color: AppColors.white,
                ),
              ),
            ),
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
                      isSelected: playerProvider.loopMode == MysicLoopMode.all,
                      onTap: () => _setPlayMode(
                        context,
                        shuffle: false,
                        loop: MysicLoopMode.all,
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

  Widget _buildFavoritesSection(BuildContext context) {
    final favoritesPlaylist = this.favoritesPlaylist;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 标题栏
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '我喜欢听',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.muted,
                ),
              ),
            ],
          ),
        ),

        // 收藏歌单入口
        if (favoritesPlaylist != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: _FavoritesListTile(
              playlist: favoritesPlaylist,
              isSelected: selectedPlaylistId == favoritesPlaylist.id,
              onTap: () async {
                await onFavoritesTap?.call(favoritesPlaylist);
                if (context.mounted) {
                  Navigator.of(context).pop();
                }
              },
            ),
          ),
      ],
    );
  }

  void _setPlayMode(BuildContext context, {
    required bool shuffle,
    required MysicLoopMode loop,
  }) {
    final playerProvider = context.read<PlayerProvider>();

    // 如果目标模式与当前相同，不做任何操作
    final isCurrentMode = (shuffle == playerProvider.isShuffleMode) &&
        (loop == playerProvider.loopMode);
    if (isCurrentMode) {
      return;
    }

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

        // 设计稿：w-full relative overflow-hidden px-4 py-3 rounded-xl bg-accent/20
        return Material(
          color: AppColors.accent.withValues(alpha: 0.20), // bg-accent/20
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: isScanning ? null : onScanSettingsTap,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Stack(
                children: [
                  // 进度条背景 - 设计稿: absolute inset-0 bg-accent/30
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

                  // 按钮内容 - 设计稿：flex items-center justify-center gap-2
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // 图标 - 设计稿：w-5 h-5
                      isScanning
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(AppColors.accent),
                              ),
                            )
                          : const Icon(
                              Icons.refresh_rounded, // 设计稿使用刷新图标
                              color: AppColors.accent,
                              size: 20,
                            ),
                      const SizedBox(width: 8),
                      // 文字
                      Text(
                        isScanning ? '${(scanProgress * 100).toInt()}%' : '扫描设置',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppColors.accent,
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
                      onTap: () async {
                        // 先执行歌单切换，完成后再关闭抽屉
                        await onPlaylistTap?.call(playlist);
                        if (context.mounted) {
                          Navigator.of(context).pop();
                        }
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
    return Container(
      padding: const EdgeInsets.all(16), // p-4
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: AppColors.white.withValues(alpha: 0.1), // border-white/10
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          // 扫描全盘按钮 - 设计稿：w-full bg-accent/20 text-accent
          _buildScanButton(context),

          const SizedBox(height: 8),

          // API 设置按钮 - 设计稿：w-full bg-white/5 text-white/70
          Material(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: () {
                Navigator.of(context).pop();
                onApiSettingsTap?.call();
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.api_rounded,
                      size: 20,
                      color: AppColors.white.withValues(alpha: 0.7),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'API 设置',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.white.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 8),

          // 关于按钮 - 设计稿：w-full bg-white/5 text-white/70
          Material(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: () {
                Navigator.of(context).pop();
                onAboutTap?.call();
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 20,
                      color: AppColors.white.withValues(alpha: 0.7),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '关于我们',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.white.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
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

/// 收藏歌单列表项
/// 使用红色渐变图标
class _FavoritesListTile extends StatefulWidget {
  final Playlist playlist;
  final bool isSelected;
  final VoidCallback? onTap;

  const _FavoritesListTile({
    required this.playlist,
    this.isSelected = false,
    this.onTap,
  });

  @override
  State<_FavoritesListTile> createState() => _FavoritesListTileState();
}

class _FavoritesListTileState extends State<_FavoritesListTile> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: Material(
        color: widget.isSelected
            ? AppColors.accent.withValues(alpha: 0.15)
            : _isHovering
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: widget.onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                // 红色渐变图标
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: AppColors.roseGradient,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.favorite_rounded,
                    color: AppColors.white,
                    size: 20,
                  ),
                ),

                const SizedBox(width: 12),

                // 歌单信息
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.playlist.name,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight:
                              widget.isSelected ? FontWeight.w600 : FontWeight.w500,
                          color: widget.isSelected ? AppColors.accent : AppColors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
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
