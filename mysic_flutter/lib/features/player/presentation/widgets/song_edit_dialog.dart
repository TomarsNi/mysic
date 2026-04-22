import 'package:flutter/material.dart';
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

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.song.title);
    _artistController = TextEditingController(text: widget.song.artist ?? '');
    _albumController = TextEditingController(text: widget.song.album ?? '');
  }

  @override
  void dispose() {
    _titleController.dispose();
    _artistController.dispose();
    _albumController.dispose();
    super.dispose();
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
          children: [
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
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _handleSave,
          child: const Text('保存'),
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
