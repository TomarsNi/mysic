import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../player/data/models/song.dart';
import '../../../player/presentation/providers/player_provider.dart';
import '../../../player/presentation/widgets/album_cover.dart';
import '../../../player/presentation/widgets/progress_bar.dart';

/// 歌词行数据模型
class LyricLine {
  final Duration timestamp;
  final String text;

  const LyricLine({
    required this.timestamp,
    required this.text,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LyricLine &&
        other.timestamp == timestamp &&
        other.text == text;
  }

  @override
  int get hashCode => Object.hash(timestamp, text);
}

/// 歌词页面
/// 完整歌词显示页面，支持时间同步高亮
class LyricsPage extends StatefulWidget {
  final List<LyricLine>? lyrics;

  const LyricsPage({
    super.key,
    this.lyrics,
  });

  @override
  State<LyricsPage> createState() => _LyricsPageState();
}

class _LyricsPageState extends State<LyricsPage> {
  final ScrollController _scrollController = ScrollController();
  int _currentLineIndex = 0;

  // 示例歌词（实际使用时从歌词解析服务获取）
  final List<LyricLine> _sampleLyrics = const [
    LyricLine(timestamp: Duration(seconds: 0), text: '♪ 前奏 ♪'),
    LyricLine(timestamp: Duration(seconds: 5), text: '这是第一句歌词'),
    LyricLine(timestamp: Duration(seconds: 10), text: '这是第二句歌词'),
    LyricLine(timestamp: Duration(seconds: 15), text: '这是第三句歌词'),
    LyricLine(timestamp: Duration(seconds: 20), text: '这是第四句歌词'),
    LyricLine(timestamp: Duration(seconds: 25), text: '这是第五句歌词'),
    LyricLine(timestamp: Duration(seconds: 30), text: '这是第六句歌词'),
    LyricLine(timestamp: Duration(seconds: 35), text: '这是第七句歌词'),
    LyricLine(timestamp: Duration(seconds: 40), text: '这是第八句歌词'),
    LyricLine(timestamp: Duration(seconds: 45), text: '这是第九句歌词'),
    LyricLine(timestamp: Duration(seconds: 50), text: '这是第十句歌词'),
    LyricLine(timestamp: Duration(seconds: 55), text: '♪ 间奏 ♪'),
    LyricLine(timestamp: Duration(seconds: 60), text: '这是第十一句歌词'),
    LyricLine(timestamp: Duration(seconds: 65), text: '这是第十二句歌词'),
    LyricLine(timestamp: Duration(seconds: 70), text: '这是第十三句歌词'),
    LyricLine(timestamp: Duration(seconds: 75), text: '这是第十四句歌词'),
    LyricLine(timestamp: Duration(seconds: 80), text: '♪ 结束 ♪'),
  ];

  List<LyricLine> get _lyrics => widget.lyrics ?? _sampleLyrics;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToCurrentLine(int index) {
    if (!_scrollController.hasClients) return;

    // 计算目标位置，使当前行居中
    const itemHeight = 60.0;
    final targetOffset = (index * itemHeight) - (200 - itemHeight / 2);

    _scrollController.animateTo(
      targetOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  int _getCurrentLineIndex(Duration position) {
    for (int i = _lyrics.length - 1; i >= 0; i--) {
      if (position >= _lyrics[i].timestamp) {
        return i;
      }
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PlayerProvider>(
      builder: (context, playerProvider, child) {
        final currentSong = playerProvider.currentSong;
        final position = playerProvider.position;

        // 更新当前行索引
        final newLineIndex = _getCurrentLineIndex(position);
        if (newLineIndex != _currentLineIndex) {
          _currentLineIndex = newLineIndex;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _scrollToCurrentLine(_currentLineIndex);
          });
        }

        return Scaffold(
          backgroundColor: AppColors.surface,
          body: SafeArea(
            child: Column(
              children: [
                // 顶部导航栏
                _buildTopBar(context, currentSong),

                // 歌词列表
                Expanded(
                  child: _buildLyricsList(),
                ),

                // 底部迷你播放器
                _buildMiniPlayer(context, playerProvider),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTopBar(BuildContext context, Song? currentSong) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // 返回按钮
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => Navigator.of(context).pop(),
          ),

          // 歌曲信息
          Expanded(
            child: Column(
              children: [
                Text(
                  currentSong?.title ?? '未知歌曲',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  currentSong?.artist ?? '未知艺术家',
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

          // 更多选项
          IconButton(
            icon: const Icon(Icons.more_vert_rounded),
            onPressed: () {
              // TODO: 显示更多选项
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLyricsList() {
    if (_lyrics.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.lyrics_rounded,
              size: 64,
              color: AppColors.muted,
            ),
            SizedBox(height: 16),
            Text(
              '暂无歌词',
              style: TextStyle(
                fontSize: 16,
                color: AppColors.muted,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(vertical: 200),
      itemCount: _lyrics.length,
      itemBuilder: (context, index) {
        final line = _lyrics[index];
        final isCurrentLine = index == _currentLineIndex;
        final isPastLine = index < _currentLineIndex;

        return _LyricLineWidget(
          line: line,
          isActive: isCurrentLine,
          isPast: isPastLine,
          onTap: () {
            // 点击歌词行跳转到对应时间
            final playerProvider =
                Provider.of<PlayerProvider>(context, listen: false);
            playerProvider.seek(line.timestamp);
          },
        );
      },
    );
  }

  Widget _buildMiniPlayer(BuildContext context, PlayerProvider provider) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 进度条
          ProgressBar(
            position: provider.position,
            duration: provider.duration,
            enabled: provider.hasCurrentSong,
            onSeek: (progress) => provider.seekToProgress(progress),
          ),

          const SizedBox(height: 12),

          // 控制按钮
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 上一首
              IconButton(
                icon: const Icon(Icons.skip_previous_rounded),
                iconSize: 32,
                onPressed: provider.hasPlaylist ? () => provider.previous() : null,
              ),

              const SizedBox(width: 24),

              // 播放/暂停
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppColors.accentGradient,
                ),
                child: IconButton(
                  icon: Icon(
                    provider.isPlaying
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                  ),
                  iconSize: 32,
                  color: AppColors.white,
                  onPressed: () => provider.togglePlayPause(),
                ),
              ),

              const SizedBox(width: 24),

              // 下一首
              IconButton(
                icon: const Icon(Icons.skip_next_rounded),
                iconSize: 32,
                onPressed: provider.hasPlaylist ? () => provider.next() : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 歌词行组件
class _LyricLineWidget extends StatelessWidget {
  final LyricLine line;
  final bool isActive;
  final bool isPast;
  final VoidCallback? onTap;

  const _LyricLineWidget({
    required this.line,
    this.isActive = false,
    this.isPast = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Text(
          line.text,
          style: TextStyle(
            fontSize: isActive ? 20 : 16,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
            color: isActive
                ? AppColors.accent
                : isPast
                    ? AppColors.muted.withValues(alpha: 0.5)
                    : AppColors.muted,
          ),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
