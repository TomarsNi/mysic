import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/utils/scan_directory_provider.dart';

/// 扫描目录管理组件
class ScanDirectoryList extends StatefulWidget {
  const ScanDirectoryList({super.key});

  @override
  State<ScanDirectoryList> createState() => _ScanDirectoryListState();
}

class _ScanDirectoryListState extends State<ScanDirectoryList> {
  final ScanDirectoryProvider _provider = ScanDirectoryProvider();
  List<String> _directories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDirectories();
  }

  Future<void> _loadDirectories() async {
    try {
      final directories = await _provider.getDirectories();
      if (mounted) {
        setState(() {
          _directories = directories;
          _isLoading = false;
        });
      }
    } on Exception catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载目录失败: $e')),
        );
      }
    }
  }

  Future<void> _addDirectory() async {
    final controller = TextEditingController();

    try {
      final result = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text(
            '添加扫描目录',
            style: TextStyle(color: AppColors.white),
          ),
          content: TextField(
            controller: controller,
            style: const TextStyle(color: AppColors.white),
            decoration: const InputDecoration(
              hintText: '输入目录名称',
              hintStyle: TextStyle(color: AppColors.muted),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: AppColors.muted),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: AppColors.accent),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消', style: TextStyle(color: AppColors.muted)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text('添加', style: TextStyle(color: AppColors.accent)),
            ),
          ],
        ),
      );

      if (result != null && result.isNotEmpty) {
        await _provider.addDirectory(result);
        await _loadDirectories();
      }
    } on Exception catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('添加目录失败: $e')),
        );
      }
    } finally {
      controller.dispose();
    }
  }

  Future<void> _removeDirectory(String directory) async {
    try {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text(
            '确认删除',
            style: TextStyle(color: AppColors.white),
          ),
          content: Text(
            '确定要删除目录 "$directory" 吗？',
            style: const TextStyle(color: AppColors.muted),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消', style: TextStyle(color: AppColors.muted)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('删除', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );

      if (confirm == true) {
        await _provider.removeDirectory(directory);
        await _loadDirectories();
      }
    } on Exception catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('删除目录失败: $e')),
        );
      }
    }
  }

  Future<void> _resetToDefault() async {
    try {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text(
            '恢复默认',
            style: TextStyle(color: AppColors.white),
          ),
          content: const Text(
            '确定要恢复默认扫描目录吗？',
            style: TextStyle(color: AppColors.muted),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消', style: TextStyle(color: AppColors.muted)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('恢复', style: TextStyle(color: AppColors.accent)),
            ),
          ],
        ),
      );

      if (confirm == true) {
        await _provider.resetToDefault();
        await _loadDirectories();
      }
    } on Exception catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('恢复默认失败: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.accent),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 标题
        const Text(
          '扫描目录管理',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.white,
          ),
        ),

        const SizedBox(height: 8),

        const Text(
          '仅扫描以下目录中的音乐文件',
          style: TextStyle(fontSize: 14, color: AppColors.muted),
        ),

        const SizedBox(height: 16),

        // 目录列表
        if (_directories.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              '暂无扫描目录，请添加',
              style: TextStyle(color: AppColors.muted),
              textAlign: TextAlign.center,
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _directories.length,
              separatorBuilder: (context, index) => const Divider(
                color: AppColors.surface,
                height: 1,
              ),
              itemBuilder: (context, index) {
                final directory = _directories[index];
                return ListTile(
                  title: Text(
                    directory,
                    style: const TextStyle(color: AppColors.white),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: AppColors.muted),
                    onPressed: () => _removeDirectory(directory),
                  ),
                );
              },
            ),
          ),

        const SizedBox(height: 16),

        // 操作按钮
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _addDirectory,
                icon: const Icon(Icons.add, color: AppColors.accent),
                label: const Text(
                  '添加目录',
                  style: TextStyle(color: AppColors.accent),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.accent),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _resetToDefault,
                icon: const Icon(Icons.restore, color: AppColors.muted),
                label: const Text(
                  '恢复默认',
                  style: TextStyle(color: AppColors.muted),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.muted),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
