import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/models/song.dart';

/// 专辑封面组件
/// 圆形专辑封面
class AlbumCover extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final coverRadius = size / 2;

    return Transform.scale(
      scale: isPlaying ? 1.08 : 1.0,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // vinyl-ring 外层边框环
          Container(
            width: size + 16,
            height: size + 16,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.05),
                width: 2,
              ),
            ),
          ),
          // vinyl-ring 内层边框环
          Container(
            width: size + 8,
            height: size + 8,
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
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: showGlow && isPlaying
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.5),
                        offset: const Offset(0, 25),
                        blurRadius: 50,
                        spreadRadius: -12,
                      ),
                      BoxShadow(
                        color: AppColors.accent.withValues(alpha: 0.3),
                        blurRadius: 70,
                        spreadRadius: -17,
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
      ),
    );
  }

  Widget _buildCoverImage(double radius) {
    // 优先使用同名图片文件（albumArtPath）
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

    // 其次使用内嵌封面（albumArtBase64）
    if (song?.albumArtBase64 != null && song!.albumArtBase64!.isNotEmpty) {
      try {
        final bytes = base64Decode(song!.albumArtBase64!);
        return Image.memory(
          bytes,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _buildDefaultCover(),
        );
      } catch (e) {
        // base64 解码失败，显示默认封面
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
          size: size * 0.4,
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
    // 优先使用同名图片文件（albumArtPath）
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

    // 其次使用内嵌封面（albumArtBase64）
    if (song?.albumArtBase64 != null && song!.albumArtBase64!.isNotEmpty) {
      try {
        final bytes = base64Decode(song!.albumArtBase64!);
        return Image.memory(
          bytes,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _buildDefaultCover(),
        );
      } catch (e) {
        // base64 解码失败，显示默认封面
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
