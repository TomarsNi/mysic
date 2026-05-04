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
                        fontWeight:
                            isPlaying ? FontWeight.w600 : FontWeight.w500,
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