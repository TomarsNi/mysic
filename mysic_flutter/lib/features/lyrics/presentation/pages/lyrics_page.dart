import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../player/data/models/song.dart';
import '../../../player/presentation/providers/player_provider.dart';
import '../../../player/presentation/widgets/play_controls.dart';
import '../../../player/presentation/widgets/progress_bar.dart';
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
  bool _needsScroll = true; // 是否需要滚动（初始为 true 确保首次加载时居中）

  // 歌词行的 GlobalKey 列表，用于精确定位
  final Map<int, GlobalKey> _lineKeys = {};

  static const double _estimatedLineHeight = 48.0;

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

  void _scrollToCurrentLine(int index) {
    final key = _lineKeys[index];
    if (key != null && key.currentContext != null) {
      Scrollable.ensureVisible(
        key.currentContext!,
        alignment: 0.5,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
      return;
    }

    // 降级：目标行未构建，预估位置滚动
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final halfHeight = _scrollController.position.viewportDimension / 2;
    final targetOffset =
        (index * _estimatedLineHeight - halfHeight).clamp(0.0, maxScroll);
    _scrollController.jumpTo(targetOffset);

    // 下一帧用 ensureVisible 精确修正
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final key = _lineKeys[index];
      if (key != null && key.currentContext != null) {
        Scrollable.ensureVisible(
          key.currentContext!,
          alignment: 0.5,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
        );
      }
    });
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
          _needsScroll = true;
        }

        return Scaffold(
          backgroundColor: const Color(0xFF1A1A2E),
          body: SafeArea(
            child: Column(
              children: [
                // 顶部导航栏
                _buildTopBar(context, currentSong),

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
  /// 与首页一致：简约图标按钮（无背景），hover 时 accent 色
  Widget _buildTopBar(BuildContext context, Song? currentSong) {
    return Padding(
      padding: const EdgeInsets.only(left: 0, right: 0, top: 16, bottom: 16),
      child: Stack(
        children: [
          // 文字层 - 绝对居中于屏幕
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '正在播放',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF71717A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  currentSong?.title ?? '未知歌曲',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // 按钮层 - 左右分布
          Row(
            children: [
              // 关闭按钮 - 简约风格
              _MinimalIconButton(
                icon: Icons.keyboard_arrow_down_rounded,
                onPressed: () => Navigator.of(context).pop(),
              ),

              const Spacer(),

              // 编辑按钮 - 简约风格
              _MinimalIconButton(
                icon: _isEditMode ? Icons.close_rounded : Icons.edit_rounded,
                isActive: _isEditMode,
                onPressed: () {
                  setState(() {
                    _isEditMode = !_isEditMode;
                    if (!_isEditMode) {
                      _isLineEditMode = false;
                      _globalOffset = Duration.zero;
                      _lineOffsets = {};
                    }
                  });
                },
              ),
            ],
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
              color: Color(0xFF9CA3AF),
            ),
            SizedBox(height: 16),
            Text(
              '暂无歌词',
              style: TextStyle(
                fontSize: 16,
                color: Color(0xFF9CA3AF),
              ),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // 如果需要滚动，在布局完成后执行
        if (_needsScroll) {
          _needsScroll = false;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _scrollToCurrentLine(_currentLineIndex);
          });
        }

        final halfHeight = constraints.maxHeight / 2;

    return ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
          child: ListView.builder(
            controller: _scrollController,
            padding: EdgeInsets.only(
            top: halfHeight,
            bottom: halfHeight,
          ),
            itemCount: lyrics.length,
            itemBuilder: (context, index) {
              final line = lyrics[index];
              final isCurrentLine = index == _currentLineIndex;
              final isPastLine = index < _currentLineIndex;

              // 确保 key 存在
              _lineKeys.putIfAbsent(index, () => GlobalKey());

              return _LyricLineWidget(
                key: _lineKeys[index],
                line: line,
                isActive: isCurrentLine,
                isPast: isPastLine,
                isEditMode: _isLineEditMode,
                lineOffset: _lineOffsets[index],
                onOffsetChanged: (offset) {
                  setState(() {
                    if (offset == Duration.zero) {
                      _lineOffsets.remove(index);
                    } else {
                      _lineOffsets[index] = offset;
                    }
                  });
                },
                onTap: () {
                  // 点击歌词行跳转到对应时间
                  final playerProvider =
                      Provider.of<PlayerProvider>(context, listen: false);
                  // 计算调整后的时间
                  final adjustedTime = line.timestamp +
                      _globalOffset +
                      (_lineOffsets[index] ?? Duration.zero);
                  playerProvider.seek(adjustedTime);
                },
              );
            },
          ),
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

    if (!mounted) return;

    if (success) {
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
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('保存失败，请重试'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Widget _buildMiniPlayer(BuildContext context, PlayerProvider provider) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 进度条 - 与首页一致的 ProgressBar 组件
        ProgressBar(
          position: provider.position,
          duration: provider.duration,
          enabled: provider.hasCurrentSong,
          onSeek: (progress) => provider.seekToProgress(progress),
        ),

        const SizedBox(height: 24),

        // 播放控制 - 与首页一致的 PlayControls 组件
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: PlayControls(
            isPlaying: provider.isPlaying,
            isLoading: provider.isLoading,
            hasPlaylist: provider.hasPlaylist,
            onPlayPause: () => provider.togglePlayPause(),
            onNext: () => provider.next(),
            onPrevious: () => provider.previous(),
          ),
        ),

        const SizedBox(height: 24),
      ],
    );
  }

  }

/// 歌词行组件
/// - 高亮行：白色 + lg 字号 (18px) + font-medium
/// - 普通行：与首页一致的 muted 色 (0xFF9CA3AF)
/// - 已唱过行：muted 色半透明
/// - 每行 py-2 (padding vertical 8px)
class _LyricLineWidget extends StatelessWidget {
  final LyricLine line;
  final bool isActive;
  final bool isPast;
  final VoidCallback? onTap;
  final bool isEditMode;
  final Duration? lineOffset;
  final ValueChanged<Duration>? onOffsetChanged;

  const _LyricLineWidget({
    super.key,
    required this.line,
    this.isActive = false,
    this.isPast = false,
    this.onTap,
    this.isEditMode = false,
    this.lineOffset,
    this.onOffsetChanged,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveOffset = lineOffset ?? Duration.zero;
    final offsetSeconds = effectiveOffset.inMilliseconds / 1000.0;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        child: Row(
          children: [
            // 逐行调整按钮（编辑模式下显示）
            if (isEditMode) ...[
              _buildLineAdjustButton(
                icon: Icons.remove_rounded,
                onPressed: () {
                  final newOffset = Duration(
                    milliseconds:
                        (effectiveOffset.inMilliseconds - 100).clamp(-5000, 5000),
                  );
                  onOffsetChanged?.call(newOffset);
                },
              ),
              const SizedBox(width: 8),
            ],

            // 歌词文本
            Expanded(
              child: Text(
                line.text,
                style: TextStyle(
                  fontSize: isActive ? 18 : 14,
                  fontWeight: isActive ? FontWeight.w500 : FontWeight.normal,
                  color: isActive
                      ? Colors.white
                      : isPast
                          ? const Color(0xFF9CA3AF).withValues(alpha: 0.5)
                          : const Color(0xFF9CA3AF),
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),

            // 逐行调整按钮（编辑模式下显示）
            if (isEditMode) ...[
              const SizedBox(width: 8),
              _buildLineAdjustButton(
                icon: Icons.add_rounded,
                onPressed: () {
                  final newOffset = Duration(
                    milliseconds:
                        (effectiveOffset.inMilliseconds + 100).clamp(-5000, 5000),
                  );
                  onOffsetChanged?.call(newOffset);
                },
              ),
              // 显示当前偏移值
              if (effectiveOffset != Duration.zero)
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Text(
                    '${offsetSeconds >= 0 ? '+' : ''}${offsetSeconds.toStringAsFixed(1)}s',
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.accent,
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLineAdjustButton({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: IconButton(
        icon: Icon(icon, size: 16),
        color: Colors.white,
        padding: EdgeInsets.zero,
        onPressed: onPressed,
      ),
    );
  }
}

/// 简约图标按钮 - 与首页一致的交互风格
/// 无背景，hover 时图标变为 accent 色
class _MinimalIconButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final bool isActive;

  const _MinimalIconButton({
    required this.icon,
    required this.onPressed,
    this.isActive = false,
  });

  @override
  State<_MinimalIconButton> createState() => _MinimalIconButtonState();
}

class _MinimalIconButtonState extends State<_MinimalIconButton> {
  bool _isHovering = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        onTap: widget.onPressed,
        child: AnimatedScale(
          duration: const Duration(milliseconds: 100),
          scale: _isPressed ? 0.95 : 1.0,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Icon(
              widget.icon,
              color: widget.isActive
                  ? AppColors.accent
                  : _isHovering
                      ? AppColors.accent
                      : AppColors.white,
              size: 24,
            ),
          ),
        ),
      ),
    );
  }
}
