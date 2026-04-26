import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../player/data/models/song.dart';
import '../../../player/presentation/providers/player_provider.dart';
import '../../data/services/lyrics_parser.dart';

/// 歌词页面
/// 完整歌词显示页面，支持时间同步高亮
class LyricsPage extends StatefulWidget {
  const LyricsPage({super.key});

  @override
  State<LyricsPage> createState() => _LyricsPageState();
}

class _LyricsPageState extends State<LyricsPage> {
  final ScrollController _scrollController = ScrollController();
  int _currentLineIndex = 0;

  // 编辑模式状态
  bool _isEditMode = false;
  bool _isLineEditMode = false;
  Duration _globalOffset = Duration.zero;
  Map<int, Duration> _lineOffsets = {};

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToCurrentLine(int index, List<LyricLine> lyrics) {
    if (!_scrollController.hasClients || lyrics.isEmpty) return;

    // 计算目标位置，使当前行居中
    const itemHeight = 60.0;
    final targetOffset = (index * itemHeight) - (200 - itemHeight / 2);

    _scrollController.animateTo(
      targetOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  int _getCurrentLineIndex(Duration position, List<LyricLine> lyrics) {
    if (lyrics.isEmpty) return 0;
    for (int i = lyrics.length - 1; i >= 0; i--) {
      if (position >= lyrics[i].timestamp) {
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
        final lyrics = playerProvider.currentLyrics.lines;

        // 更新当前行索引
        final newLineIndex = _getCurrentLineIndex(position, lyrics);
        if (newLineIndex != _currentLineIndex) {
          _currentLineIndex = newLineIndex;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _scrollToCurrentLine(_currentLineIndex, lyrics);
          });
        }

        return Scaffold(
          backgroundColor: AppColors.surface,
          body: SafeArea(
            child: Column(
              children: [
                // 顶部导航栏
                _buildTopBar(context, currentSong),

                // 歌曲信息栏 - 设计稿新增
                _buildSongInfoBar(context, currentSong),

                // 歌词列表
                Expanded(
                  child: _buildLyricsList(lyrics),
                ),

                // 时间调整工具栏（编辑模式下显示）
                if (_isEditMode) _buildAdjustmentToolbar(context, playerProvider),

                // 底部迷你播放器（非编辑模式下显示）
                if (!_isEditMode) _buildMiniPlayer(context, playerProvider),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 顶部栏
  /// 设计稿规范：关闭按钮 + 标题 + 空位，关闭按钮样式 p-3 rounded-xl bg-card
  Widget _buildTopBar(BuildContext context, Song? currentSong) {
    return Container(
      padding: const EdgeInsets.only(left: 24, right: 24, top: 48, bottom: 16), // 设计稿 px-6 pt-16 pb-4
      child: Row(
        children: [
          // 关闭按钮 - 设计稿：p-3 rounded-xl bg-card
          Container(
            width: 44, // p-3 (12px) + icon 20px = 44px
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.card, // bg-card
              borderRadius: BorderRadius.circular(12), // rounded-xl
            ),
            child: IconButton(
              icon: const Icon(Icons.keyboard_arrow_down_rounded), // 设计稿使用向下箭头
              iconSize: 20,
              color: AppColors.white,
              padding: EdgeInsets.zero,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),

          // 标题区域 - 设计稿：上方 text-xs text-muted（正在播放），下方 text-sm font-medium
          Expanded(
            child: Column(
              children: [
                Text(
                  '正在播放',
                  style: const TextStyle(
                    fontSize: 12, // text-xs
                    color: AppColors.muted,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  currentSong?.title ?? '未知歌曲',
                  style: const TextStyle(
                    fontSize: 14, // text-sm
                    fontWeight: FontWeight.w500, // font-medium
                    color: AppColors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // 右侧编辑按钮
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _isEditMode ? AppColors.accent : AppColors.card,
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: Icon(
                _isEditMode ? Icons.close_rounded : Icons.edit_rounded,
              ),
              iconSize: 20,
              color: AppColors.white,
              padding: EdgeInsets.zero,
              onPressed: () {
                setState(() {
                  _isEditMode = !_isEditMode;
                  if (!_isEditMode) {
                    // 退出编辑模式时重置状态
                    _isLineEditMode = false;
                    _globalOffset = Duration.zero;
                    _lineOffsets = {};
                  }
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  /// 歌曲信息栏
  /// 设计稿规范：封面 w-14 h-14 (56px) rounded-xl，标题 + 艺术家，border-b border-white/5
  Widget _buildSongInfoBar(BuildContext context, Song? currentSong) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16), // px-6 py-4
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: AppColors.white.withValues(alpha: 0.05), // border-white/5
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // 封面 - 设计稿：w-14 h-14 rounded-xl bg-gradient-to-br from-zinc-700 to-zinc-800
          Container(
            width: 56, // w-14 = 56px
            height: 56,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12), // rounded-xl
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF3F3F46), Color(0xFF27272A)], // zinc-700 to zinc-800
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: currentSong?.albumArtPath != null
                  ? Image.network(
                      currentSong!.albumArtPath!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.music_note_rounded,
                        color: AppColors.muted,
                        size: 24,
                      ),
                    )
                  : const Icon(
                      Icons.music_note_rounded,
                      color: AppColors.muted,
                      size: 24,
                    ),
            ),
          ),

          const SizedBox(width: 16), // gap-4

          // 歌曲信息
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  currentSong?.title ?? '未知歌曲',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600, // font-semibold
                    color: AppColors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '${currentSong?.artist ?? '未知艺术家'} · ${currentSong?.album ?? '未知专辑'}',
                  style: const TextStyle(
                    fontSize: 14, // text-sm
                    color: AppColors.muted,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLyricsList(List<LyricLine> lyrics) {
    if (lyrics.isEmpty) {
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
      itemCount: lyrics.length,
      itemBuilder: (context, index) {
        final line = lyrics[index];
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

  /// 时间调整工具栏
  Widget _buildAdjustmentToolbar(BuildContext context, PlayerProvider provider) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(
            color: AppColors.white.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 标题
          Row(
            children: [
              const Icon(
                Icons.music_note_rounded,
                size: 20,
                color: AppColors.accent,
              ),
              const SizedBox(width: 8),
              const Text(
                '时间调整',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 整体偏移
          _buildGlobalOffsetControl(),
          const SizedBox(height: 16),

          // 按钮行
          Row(
            children: [
              // 逐行调整按钮
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      _isLineEditMode = !_isLineEditMode;
                    });
                  },
                  icon: Icon(
                    _isLineEditMode ? Icons.list_rounded : Icons.tune_rounded,
                    size: 18,
                  ),
                  label: Text(_isLineEditMode ? '完成调整' : '逐行调整'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.white,
                    side: BorderSide(
                      color: AppColors.white.withValues(alpha: 0.3),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // 保存按钮
              ElevatedButton(
                onPressed:
                    _hasChanges() ? () => _saveAdjustment(provider) : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: AppColors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('保存'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 整体偏移控件
  Widget _buildGlobalOffsetControl() {
    final offsetSeconds = _globalOffset.inMilliseconds / 1000.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '整体偏移',
          style: TextStyle(
            fontSize: 14,
            color: AppColors.muted,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            // 减少按钮
            _buildOffsetButton(
              icon: Icons.remove_rounded,
              onPressed: () {
                setState(() {
                  _globalOffset = Duration(
                    milliseconds:
                        (_globalOffset.inMilliseconds - 100).clamp(-5000, 5000),
                  );
                });
              },
            ),
            // 滑块
            Expanded(
              child: SliderTheme(
                data: SliderThemeData(
                  activeTrackColor: AppColors.accent,
                  inactiveTrackColor: AppColors.white.withValues(alpha: 0.1),
                  thumbColor: AppColors.accent,
                  overlayColor: AppColors.accent.withValues(alpha: 0.2),
                  trackHeight: 4,
                ),
                child: Slider(
                  value: offsetSeconds.clamp(-5.0, 5.0),
                  min: -5.0,
                  max: 5.0,
                  divisions: 100,
                  onChanged: (value) {
                    setState(() {
                      _globalOffset = Duration(
                        milliseconds: (value * 1000).round(),
                      );
                    });
                  },
                ),
              ),
            ),
            // 增加按钮
            _buildOffsetButton(
              icon: Icons.add_rounded,
              onPressed: () {
                setState(() {
                  _globalOffset = Duration(
                    milliseconds:
                        (_globalOffset.inMilliseconds + 100).clamp(-5000, 5000),
                  );
                });
              },
            ),
          ],
        ),
        // 当前值和重置按钮
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '当前: ${offsetSeconds >= 0 ? '+' : ''}${offsetSeconds.toStringAsFixed(1)}s',
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.white,
              ),
            ),
            TextButton(
              onPressed: _globalOffset != Duration.zero
                  ? () {
                      setState(() {
                        _globalOffset = Duration.zero;
                      });
                    }
                  : null,
              child: const Text('重置'),
            ),
          ],
        ),
      ],
    );
  }

  /// 偏移按钮
  Widget _buildOffsetButton({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: AppColors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: IconButton(
        icon: Icon(icon, size: 20),
        color: AppColors.white,
        padding: EdgeInsets.zero,
        onPressed: onPressed,
      ),
    );
  }

  /// 检查是否有更改
  bool _hasChanges() {
    return _globalOffset != Duration.zero || _lineOffsets.isNotEmpty;
  }

  /// 保存调整
  Future<void> _saveAdjustment(PlayerProvider provider) async {
    final success = await provider.saveLyricsAdjustment(
      globalOffset: _globalOffset,
      lineOffsets: _lineOffsets,
    );

    if (success && mounted) {
      setState(() {
        _isEditMode = false;
        _isLineEditMode = false;
        _globalOffset = Duration.zero;
        _lineOffsets = {};
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('歌词时间已保存'),
          backgroundColor: AppColors.accent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Widget _buildMiniPlayer(BuildContext context, PlayerProvider provider) {
    // 设计稿规范：底部迷你播放器带 backdrop-blur-lg，背景 bg-card/50
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15), // backdrop-blur-lg
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.card.withValues(alpha: 0.5), // bg-card/50
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
              // 进度条 - 设计稿：h-1 高度
              Container(
                height: 4, // h-1 = 4px
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1), // bg-white/10
                  borderRadius: BorderRadius.circular(2),
                ),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: provider.duration != null && provider.duration!.inMilliseconds > 0
                      ? (provider.position.inMilliseconds / provider.duration!.inMilliseconds).clamp(0.0, 1.0)
                      : 0.0,
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 8),

              // 时间显示
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _formatDuration(provider.position),
                      style: const TextStyle(fontSize: 12, color: AppColors.muted),
                    ),
                    Text(
                      provider.duration != null ? _formatDuration(provider.duration!) : '--:--',
                      style: const TextStyle(fontSize: 12, color: AppColors.muted),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // 控制按钮
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 上一首
                  IconButton(
                    icon: const Icon(Icons.skip_previous_rounded),
                    iconSize: 28,
                    color: AppColors.white,
                    onPressed: provider.hasPlaylist ? () => provider.previous() : null,
                  ),

                  const SizedBox(width: 24),

                  // 播放/暂停 - 设计稿：圆形 accent 按钮
                  Container(
                    width: 48, // p-3 = 12px padding + icon size
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: AppColors.accentGradient,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.accent.withValues(alpha: 0.3),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: IconButton(
                      icon: Icon(
                        provider.isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                      ),
                      iconSize: 20, // w-5 h-5
                      color: AppColors.white,
                      onPressed: () => provider.togglePlayPause(),
                    ),
                  ),

                  const SizedBox(width: 24),

                  // 下一首
                  IconButton(
                    icon: const Icon(Icons.skip_next_rounded),
                    iconSize: 28,
                    color: AppColors.white,
                    onPressed: provider.hasPlaylist ? () => provider.next() : null,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}

/// 歌词行组件
/// 设计稿规范：
/// - 高亮行：白色 + lg 字号 (20px) + font-medium
/// - 普通行：muted 色
/// - 每行 py-2 (padding vertical 8px)
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
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8), // 设计稿 py-2
        child: Text(
          line.text,
          style: TextStyle(
            // 设计稿：高亮行 lg 字号 (约 18-20px)，font-medium，白色
            fontSize: isActive ? 18 : 14,
            fontWeight: isActive ? FontWeight.w500 : FontWeight.normal, // font-medium
            color: isActive
                ? AppColors.white // 设计稿要求高亮行白色
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
