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
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
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
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: widget.isPlaying ? _pulseAnimation.value : 1.0,
          child: child,
        );
      },
      child: _buildCover(),
    );
  }

  Widget _buildCover() {
    final coverRadius = widget.size / 2;

    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: widget.showGlow && widget.isPlaying
            ? [
                BoxShadow(
                  color: AppColors.accent.withValues(alpha: 0.4),
                  blurRadius: 30,
                  spreadRadius: 5,
                ),
                BoxShadow(
                  color: AppColors.accent.withValues(alpha: 0.2),
                  blurRadius: 60,
                  spreadRadius: 10,
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
