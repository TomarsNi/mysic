import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../../../core/services/file_copy_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/models/song.dart';

/// 歌曲元信息编辑对话框
class SongEditDialog extends StatefulWidget {
  final Song song;
  final void Function(Song updatedSong) onSave;

  const SongEditDialog({
    super.key,
    required this.song,
    required this.onSave,
  });

  @override
  State<SongEditDialog> createState() => _SongEditDialogState();
}

class _SongEditDialogState extends State<SongEditDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _artistController;
  late final TextEditingController _albumController;

  final FileCopyService _fileCopyService = FileCopyService();
  String? _albumArtPath;
  String? _lyricsPath;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.song.title);
    _artistController = TextEditingController(text: widget.song.artist ?? '');
    _albumController = TextEditingController(text: widget.song.album ?? '');
    _albumArtPath = widget.song.albumArtPath;
    _lyricsPath = widget.song.lyricsPath;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _artistController.dispose();
    _albumController.dispose();
    super.dispose();
  }

  Future<void> _selectAlbumCover() async {
    if (_isProcessing) return;
    if (widget.song.id == null) {
      _showError('请先保存歌曲信息');
      return;
    }

    final result = await openFile(
      acceptedTypeGroups: [
        XTypeGroup(
          label: '图片',
          extensions: ['jpg', 'jpeg', 'png', 'webp'],
          uniformTypeIdentifiers: ['public.image'],
        ),
      ],
    );

    if (result == null) return;

    setState(() => _isProcessing = true);

    try {
      if (_albumArtPath != null) {
        await _fileCopyService.deleteFile(_albumArtPath);
      }

      final newPath = await _fileCopyService.copyAlbumCover(
        result.path,
        widget.song.id!,
      );

      if (newPath != null) {
        setState(() => _albumArtPath = newPath);
      } else {
        _showError('复制图片失败');
      }
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _clearAlbumCover() async {
    if (_albumArtPath != null) {
      await _fileCopyService.deleteFile(_albumArtPath);
      setState(() => _albumArtPath = null);
    }
  }

  Future<void> _selectLyrics() async {
    if (_isProcessing) return;
    if (widget.song.id == null) {
      _showError('请先保存歌曲信息');
      return;
    }

    final result = await openFile(
      acceptedTypeGroups: [
        XTypeGroup(
          label: '歌词',
          extensions: ['lrc'],
          uniformTypeIdentifiers: ['public.plain-text'],
        ),
      ],
    );

    if (result == null) return;

    setState(() => _isProcessing = true);

    try {
      if (_lyricsPath != null) {
        await _fileCopyService.deleteFile(_lyricsPath);
      }

      final newPath = await _fileCopyService.copyLyrics(
        result.path,
        widget.song.id!,
      );

      if (newPath != null) {
        setState(() => _lyricsPath = newPath);
      } else {
        _showError('复制歌词文件失败');
      }
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _clearLyrics() async {
    if (_lyricsPath != null) {
      await _fileCopyService.deleteFile(_lyricsPath);
      setState(() => _lyricsPath = null);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  String get _lyricsFileName {
    if (_lyricsPath == null) return '未选择';
    return p.basename(_lyricsPath!);
  }

  void _handleSave() {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('歌曲名称不能为空')),
      );
      return;
    }

    final updatedSong = widget.song.copyWith(
      title: title,
      artist: _artistController.text.trim().isEmpty
          ? null
          : _artistController.text.trim(),
      album: _albumController.text.trim().isEmpty
          ? null
          : _albumController.text.trim(),
      albumArtPath: _albumArtPath,
      albumArtBase64: _albumArtPath != null ? null : widget.song.albumArtBase64,
      lyricsPath: _lyricsPath,
      updatedAt: DateTime.now(),
    );

    widget.onSave(updatedSong);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('编辑歌曲信息'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildAlbumCoverSection(),
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 16),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: '歌曲名称',
                hintText: '请输入歌曲名称',
              ),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _artistController,
              decoration: const InputDecoration(
                labelText: '艺术家',
                hintText: '请输入艺术家名称',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _albumController,
              decoration: const InputDecoration(
                labelText: '专辑',
                hintText: '请输入专辑名称',
              ),
            ),
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 16),
            _buildLyricsSection(),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isProcessing ? null : () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _isProcessing ? null : _handleSave,
          child: _isProcessing
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('保存'),
        ),
      ],
    );
  }

  Widget _buildAlbumCoverSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '专辑封面',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient:
                    _albumArtPath != null ? null : AppColors.accentGradient,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: ClipOval(
                child: _albumArtPath != null
                    ? Image.file(
                        File(_albumArtPath!),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _buildDefaultCoverIcon(),
                      )
                    : _buildDefaultCoverIcon(),
              ),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: _isProcessing ? null : _selectAlbumCover,
                      icon: const Icon(Icons.image_outlined, size: 18),
                      label: const Text('选择图片'),
                    ),
                    const SizedBox(width: 8),
                    if (_albumArtPath != null)
                      TextButton.icon(
                        onPressed: _isProcessing ? null : _clearAlbumCover,
                        icon: const Icon(Icons.delete_outline, size: 18),
                        label: const Text('清除'),
                        style: TextButton.styleFrom(
                          foregroundColor: Theme.of(context).colorScheme.error,
                        ),
                      ),
                  ],
                ),
                Text(
                  '支持 JPG、PNG、WebP',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.muted,
                      ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDefaultCoverIcon() {
    return Container(
      decoration: const BoxDecoration(
        gradient: AppColors.accentGradient,
        shape: BoxShape.circle,
      ),
      child: const Center(
        child: Icon(
          Icons.music_note_rounded,
          color: AppColors.white,
          size: 32,
        ),
      ),
    );
  }

  Widget _buildLyricsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '歌词文件',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  const Icon(
                    Icons.lyrics_outlined,
                    size: 20,
                    color: AppColors.muted,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _lyricsFileName,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: _lyricsPath != null ? null : AppColors.muted,
                          ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            TextButton.icon(
              onPressed: _isProcessing ? null : _selectLyrics,
              icon: const Icon(Icons.folder_open_outlined, size: 18),
              label: const Text('选择歌词'),
            ),
            if (_lyricsPath != null) ...[
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: _isProcessing ? null : _clearLyrics,
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text('清除'),
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                ),
              ),
            ],
          ],
        ),
        Text(
          '支持 LRC 格式歌词文件',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.muted,
              ),
        ),
      ],
    );
  }
}

/// 显示歌曲编辑对话框
Future<void> showSongEditDialog({
  required BuildContext context,
  required Song song,
  required void Function(Song updatedSong) onSave,
}) {
  return showDialog(
    context: context,
    builder: (context) => SongEditDialog(
      song: song,
      onSave: onSave,
    ),
  );
}
