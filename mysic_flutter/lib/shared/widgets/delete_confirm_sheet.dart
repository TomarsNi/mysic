import 'package:flutter/material.dart';
import 'package:mysic_flutter/features/player/data/models/song.dart';
import 'package:mysic_flutter/features/settings/data/delete_preference.dart';

/// 删除确认 BottomSheet
/// 显示删除歌曲的确认对话框，支持勾选是否同时删除原文件
class DeleteConfirmSheet extends StatefulWidget {
  /// 要删除的歌曲
  final Song song;

  /// 确认删除回调
  /// [deleteWithFile] 为 true 表示同时删除原文件
  final void Function(bool deleteWithFile) onConfirm;

  const DeleteConfirmSheet({
    super.key,
    required this.song,
    required this.onConfirm,
  });

  @override
  State<DeleteConfirmSheet> createState() => _DeleteConfirmSheetState();
}

class _DeleteConfirmSheetState extends State<DeleteConfirmSheet> {
  bool _deleteWithFile = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPreference();
  }

  Future<void> _loadPreference() async {
    final value = await DeletePreference.getDeleteWithFile();
    if (mounted) {
      setState(() {
        _deleteWithFile = value;
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleDeleteWithFile(bool value) async {
    setState(() {
      _deleteWithFile = value;
    });
    await DeletePreference.setDeleteWithFile(value);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF27272A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 拖拽指示条
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFF71717A),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),

          // 警告图标
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: const Color(0xFFEF4444).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(32),
            ),
            child: const Icon(
              Icons.warning_rounded,
              color: Color(0xFFEF4444),
              size: 32,
            ),
          ),
          const SizedBox(height: 16),

          // 标题
          const Text(
            '确认删除歌曲？',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),

          // 歌曲名称
          Text(
            widget.song.title,
            style: const TextStyle(
              color: Color(0xFF71717A),
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),

          // 同时删除文件勾选框
          if (!_isLoading)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF3F3F46),
                borderRadius: BorderRadius.circular(12),
              ),
              child: CheckboxListTile(
                value: _deleteWithFile,
                onChanged: (value) => _toggleDeleteWithFile(value ?? false),
                title: const Text(
                  '同时删除原文件',
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
                subtitle: const Text(
                  '文件删除后无法恢复',
                  style: TextStyle(color: Color(0xFF71717A), fontSize: 12),
                ),
                activeColor: const Color(0xFFEF4444),
                checkColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),

          // 警告提示
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFEF4444).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _deleteWithFile
                  ? '歌曲和原文件都将被删除，且无法恢复'
                  : '删除后歌曲将从所有歌单移除，且不会在下次扫描时重新添加',
              style: const TextStyle(
                color: Color(0xFFEF4444),
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 24),

          // 操作按钮
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    backgroundColor: const Color(0xFF3F3F46),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    '算了吧',
                    style: TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    widget.onConfirm(_deleteWithFile);
                  },
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    backgroundColor: const Color(0xFFEF4444),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    '删了吧',
                    style: TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 显示删除确认面板的辅助函数
void showDeleteConfirmSheet(
  BuildContext context, {
  required Song song,
  required void Function(bool deleteWithFile) onConfirm,
}) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => DeleteConfirmSheet(
      song: song,
      onConfirm: onConfirm,
    ),
  );
}
