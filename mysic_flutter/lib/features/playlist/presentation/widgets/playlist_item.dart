import 'package:flutter/material.dart';
import 'package:mysic_flutter/core/theme/app_colors.dart';
import 'package:mysic_flutter/features/player/data/models/playlist.dart';
import 'package:mysic_flutter/features/player/data/models/song.dart';

/// 歌单列表项组件
/// 显示单个歌单的信息，支持点击和长按操作
class PlaylistItem extends StatelessWidget {
  /// 歌单数据
  final Playlist playlist;

  /// 点击回调
  final VoidCallback? onTap;

  /// 长按回调（用于显示菜单）
  final VoidCallback? onLongPress;

  /// 删除回调
  final VoidCallback? onDelete;

  /// 编辑回调
  final VoidCallback? onEdit;

  /// 是否显示歌曲数量
  final bool showSongCount;

  /// 是否显示总时长
  final bool showDuration;

  /// 是否选中状态
  final bool isSelected;

  const PlaylistItem({
    super.key,
    required this.playlist,
    this.onTap,
    this.onLongPress,
    this.onDelete,
    this.onEdit,
    this.showSongCount = true,
    this.showDuration = false,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected
          ? AppColors.accent.withValues(alpha: 0.15)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        onLongPress: onLongPress ?? _showContextMenu,
        child: Container(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // 歌单封面
              _buildCover(),

              const SizedBox(width: 16),

              // 歌单信息
              Expanded(
                child: _buildInfo(),
              ),

              // 操作按钮或箭头
              if (onTap != null) _buildTrailing(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCover() {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: _getGradientForPlaylist(),
      ),
      child: playlist.coverPath != null
          ? ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                playlist.coverPath!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _buildDefaultCoverIcon(),
              ),
            )
          : _buildDefaultCoverIcon(),
    );
  }

  Widget _buildDefaultCoverIcon() {
    return const Icon(
      Icons.playlist_play_rounded,
      color: AppColors.white,
      size: 32,
    );
  }

  LinearGradient _getGradientForPlaylist() {
    // 根据歌单 ID 选择不同的渐变色
    final gradients = [
      AppColors.accentGradient,
      AppColors.roseGradient,
      AppColors.blueGradient,
      AppColors.violetGradient,
      AppColors.orangeGradient,
    ];

    final index = (playlist.id ?? 0) % gradients.length;
    return gradients[index];
  }

  Widget _buildInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // 歌单名称
        Text(
          playlist.name,
          style: TextStyle(
            fontSize: 16,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected ? AppColors.accent : AppColors.white,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),

        const SizedBox(height: 4),

        // 歌单描述或歌曲数量
        Text(
          _buildSubtitle(),
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.muted,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),

        // 总时长
        if (showDuration && !playlist.isEmpty) ...[
          const SizedBox(height: 2),
          Text(
            '总时长: ${playlist.formattedTotalDuration}',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.muted,
            ),
          ),
        ],
      ],
    );
  }

  String _buildSubtitle() {
    if (playlist.description != null && playlist.description!.isNotEmpty) {
      return playlist.description!;
    }

    if (showSongCount) {
      return '${playlist.songCount} 首歌曲';
    }

    return '';
  }

  Widget _buildTrailing() {
    return Icon(
      Icons.chevron_right_rounded,
      color: AppColors.muted.withValues(alpha: 0.5),
      size: 24,
    );
  }

  void _showContextMenu() {
    // 由父组件处理，这里提供默认实现
    // 实际使用时应该通过 onLongPress 回调处理
  }
}

/// 歌单歌曲列表项组件
/// 显示歌单中的单个歌曲
class PlaylistSongItem extends StatelessWidget {
  /// 歌曲数据
  final Song song;

  /// 在列表中的位置（用于显示序号）
  final int index;

  /// 点击回调
  final VoidCallback? onTap;

  /// 长按回调
  final VoidCallback? onLongPress;

  /// 删除回调
  final VoidCallback? onDelete;

  /// 是否正在播放
  final bool isPlaying;

  const PlaylistSongItem({
    super.key,
    required this.song,
    required this.index,
    this.onTap,
    this.onLongPress,
    this.onDelete,
    this.isPlaying = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isPlaying
          ? AppColors.accent.withValues(alpha: 0.15)
          : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              // 序号或播放指示器
              SizedBox(
                width: 32,
                child: isPlaying
                    ? _buildPlayingIndicator()
                    : _buildIndexNumber(),
              ),

              const SizedBox(width: 12),

              // 歌曲信息
              Expanded(
                child: _buildSongInfo(),
              ),

              // 时长
              Text(
                song.formattedDuration,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlayingIndicator() {
    return const Icon(
      Icons.volume_up_rounded,
      color: AppColors.accent,
      size: 20,
    );
  }

  Widget _buildIndexNumber() {
    return Text(
      '${index + 1}',
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: AppColors.muted.withValues(alpha: 0.7),
      ),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildSongInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 歌曲标题
        Text(
          song.title,
          style: TextStyle(
            fontSize: 15,
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
            fontSize: 13,
            color: AppColors.muted,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

/// 歌单详情头部组件
/// 显示歌单封面和基本信息
class PlaylistHeader extends StatelessWidget {
  /// 歌单数据
  final Playlist playlist;

  /// 播放全部回调
  final VoidCallback? onPlayAll;

  /// 随机播放回调
  final VoidCallback? onShufflePlay;

  /// 编辑歌单回调
  final VoidCallback? onEdit;

  const PlaylistHeader({
    super.key,
    required this.playlist,
    this.onPlayAll,
    this.onShufflePlay,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // 封面和基本信息
          Row(
            children: [
              // 封面
              _buildCover(),

              const SizedBox(width: 20),

              // 信息
              Expanded(
                child: _buildInfo(),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // 操作按钮
          _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildCover() {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: _getGradientForPlaylist(),
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: playlist.coverPath != null
          ? ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                playlist.coverPath!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _buildDefaultCoverIcon(),
              ),
            )
          : _buildDefaultCoverIcon(),
    );
  }

  Widget _buildDefaultCoverIcon() {
    return const Icon(
      Icons.playlist_play_rounded,
      color: AppColors.white,
      size: 48,
    );
  }

  LinearGradient _getGradientForPlaylist() {
    final gradients = [
      AppColors.accentGradient,
      AppColors.roseGradient,
      AppColors.blueGradient,
      AppColors.violetGradient,
      AppColors.orangeGradient,
    ];

    final index = (playlist.id ?? 0) % gradients.length;
    return gradients[index];
  }

  Widget _buildInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 歌单名称
        Text(
          playlist.name,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: AppColors.white,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),

        const SizedBox(height: 8),

        // 歌曲数量和总时长
        Text(
          '${playlist.songCount} 首歌曲 · ${playlist.formattedTotalDuration}',
          style: const TextStyle(
            fontSize: 14,
            color: AppColors.muted,
          ),
        ),

        if (playlist.description != null &&
            playlist.description!.isNotEmpty) ...[
          const SizedBox(height: 8),

          Text(
            playlist.description!,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.muted,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        // 播放全部按钮
        Expanded(
          child: ElevatedButton.icon(
            onPressed: onPlayAll,
            icon: const Icon(Icons.play_arrow_rounded, size: 20),
            label: const Text('播放全部'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: AppColors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          ),
        ),

        const SizedBox(width: 12),

        // 随机播放按钮
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onShufflePlay,
            icon: const Icon(Icons.shuffle_rounded, size: 20),
            label: const Text('随机播放'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.white,
              side: const BorderSide(color: AppColors.muted),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
