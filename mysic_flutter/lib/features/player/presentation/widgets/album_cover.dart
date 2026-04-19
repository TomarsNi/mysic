import 'dart:io';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/models/song.dart';

/// 专辑封面组件
/// 圆形专辑封面，带脉冲发光动画效果
class AlbumCover extends StatefulWidget {
  final Song? song;
  final double size;
  final bool isPlaying;
  final bool showGlow;

  const AlbumCover({
    super.key,
    required this.song,
    this.size = 200,
    this.isPlaying = false,
    this.showGlow = true,
  });

  @override
  State<AlbumCover> createState() => _AlbumCoverState();
}

class _AlbumCoverState extends State<AlbumCover>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000), // 设计稿要求 3s
    );

    // glow 动画用于 box-shadow 变化
    _glowAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );

    if (widget.isPlaying) {
      _animationController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(AlbumCover oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying != oldWidget.isPlaying) {
      if (widget.isPlaying) {
        _animationController.repeat(reverse: true);
      } else {
        _animationController.stop();
        _animationController.reset();
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 设计稿：播放时静态 scale(1.08)
    return Transform.scale(
      scale: widget.isPlaying ? 1.08 : 1.0,
      child: AnimatedBuilder(
        animation: _glowAnimation,
        builder: (context, child) {
          return _buildCover(_glowAnimation.value);
        },
      ),
    );
  }

  Widget _buildCover(double glowValue) {
    final coverRadius = widget.size / 2;

    return Stack(
      alignment: Alignment.center,
      children: [
        // vinyl-ring 外层边框环 (设计稿 inset: -8px)
        Container(
          width: widget.size + 16,
          height: widget.size + 16,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.05),
              width: 2,
            ),
          ),
        ),
        // vinyl-ring 内层边框环 (设计稿 ::before inset: -4px)
        Container(
          width: widget.size + 8,
          height: widget.size + 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.03),
              width: 1,
            ),
          ),
        ),
        // 主封面
        Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: widget.showGlow && widget.isPlaying
                ? [
                    // 设计稿 pulse-glow 动画的 base shadow
                    // CSS: 0 25px 50px -12px rgba(0, 0, 0, 0.5)
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      offset: const Offset(0, 25), // 设计稿 offset-y: 25px
                      blurRadius: 50, // 设计稿 blur: 50px
                      spreadRadius: -12, // 设计稿 spread: -12px
                    ),
                    // glow 效果随动画变化
                    // 设计稿: 0% 时 0 0 60px -20px rgba(accent, 0.2)
                    //         50% 时 0 0 80px -15px rgba(accent, 0.4)
                    BoxShadow(
                      color: AppColors.accent.withValues(
                        alpha: 0.2 + glowValue * 0.2, // 0.2 → 0.4
                      ),
                      blurRadius: 60 + glowValue * 20, // 60 → 80
                      spreadRadius: -20 + glowValue * 5, // -20 → -15
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
          ),
          child: ClipOval(
            child: _buildCoverImage(coverRadius),
          ),
        ),
      ],
    );
  }

  Widget _buildCoverImage(double radius) {
    // 如果有专辑封面路径，尝试加载
    if (widget.song?.albumArtPath != null &&
        widget.song!.albumArtPath!.isNotEmpty) {
      final file = File(widget.song!.albumArtPath!);
      if (file.existsSync()) {
        return Image.file(
          file,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _buildDefaultCover(),
        );
      }
    }

    return _buildDefaultCover();
  }

  Widget _buildDefaultCover() {
    return Container(
      decoration: const BoxDecoration(
        gradient: AppColors.accentGradient,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Icon(
          Icons.music_note_rounded,
          size: widget.size * 0.4,
          color: AppColors.white,
        ),
      ),
    );
  }
}

/// 小型专辑封面（用于列表项等）
class AlbumCoverSmall extends StatelessWidget {
  final Song? song;
  final double size;

  const AlbumCoverSmall({
    super.key,
    required this.song,
    this.size = 48,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 4,
            spreadRadius: 1,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.15),
        child: _buildCoverImage(),
      ),
    );
  }

  Widget _buildCoverImage() {
    if (song?.albumArtPath != null && song!.albumArtPath!.isNotEmpty) {
      final file = File(song!.albumArtPath!);
      if (file.existsSync()) {
        return Image.file(
          file,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _buildDefaultCover(),
        );
      }
    }

    return _buildDefaultCover();
  }

  Widget _buildDefaultCover() {
    return Container(
      decoration: const BoxDecoration(
        gradient: AppColors.accentGradient,
      ),
      child: Center(
        child: Icon(
          Icons.music_note_rounded,
          size: size * 0.4,
          color: AppColors.white,
        ),
      ),
    );
  }
}
