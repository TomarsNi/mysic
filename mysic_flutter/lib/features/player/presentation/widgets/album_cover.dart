import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/models/song.dart';

/// 专辑封面组件
/// 正方形专辑封面，带圆角
class AlbumCover extends StatelessWidget {
  final Song? song;
  final double size;
  final bool isPlaying;

  const AlbumCover({
    super.key,
    required this.song,
    this.size = 200,
    this.isPlaying = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
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
