import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/utils/scan_directory_provider.dart';
import '../../../../shared/utils/scan_directory_config.dart';
import '../../../playlist/presentation/providers/playlist_provider.dart';

/// 扫描目录管理组件
class ScanDirectoryList extends StatefulWidget {
  /// 可选的 provider，用于测试注入
  final ScanDirectoryProvider? provider;

  const ScanDirectoryList({super.key, this.provider});

  @override
  State<ScanDirectoryList> createState() => _ScanDirectoryListState();
}

class _ScanDirectoryListState extends State<ScanDirectoryList> {
  late final ScanDirectoryProvider _provider;
  List<ScanDirectoryConfig> _configs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _provider = widget.provider ?? ScanDirectoryProvider();
    _loadDirectories();
  }

  Future<void> _loadDirectories() async {
    try {
      // 先尝试迁移旧数据
      await _provider.migrateIfNeeded();
      final configs = await _provider.getConfigs();
      if (mounted) {
        setState(() {
          _configs = configs;
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
        // 检查是否已存在
        final exists = _configs.any((c) => c.directory == result);
        if (exists) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('该目录已存在')),
            );
          }
          return;
        }

        // 获取 PlaylistProvider 并创建同名歌单
        if (!mounted) return;
        final playlistProvider = context.read<PlaylistProvider>();
        final playlist = await playlistProvider.createPlaylist(name: result);

        if (playlist != null) {
          // 关联目录与歌单
          await _provider.addDirectoryWithPlaylist(
            result,
            playlistId: playlist.id,
            playlistName: playlist.name,
          );
          await _loadDirectories();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('已添加目录并创建歌单$result')),
            );
          }
        } else {
          // 歌单创建失败，仅添加目录
          await _provider.addDirectoryWithPlaylist(result);
          await _loadDirectories();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('已添加目录$result（歌单创建失败）')),
            );
          }
        }
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

  Future<void> _removeDirectory(ScanDirectoryConfig config) async {
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
            '确定要删除目录 ${config.effectiveDisplayName} 吗？',
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
        await _provider.removeConfig(config.directory);
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
            '确定要恢复默认扫描目录吗？这将清除所有目录配置。',
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
        // 重新迁移以获取默认目录配置
        await _provider.migrateIfNeeded();
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

  /// 显示编辑歌单关联对话框
  Future<void> _showEditPlaylistDialog(ScanDirectoryConfig config) async {
    final playlistProvider = context.read<PlaylistProvider>();
    final playlists = playlistProvider.playlists;

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(
          '关联歌单 - ${config.effectiveDisplayName}',
          style: const TextStyle(color: AppColors.white),
        ),
        content: SizedBox(
          width: 300,
          child: ListView(
            shrinkWrap: true,
            children: [
              // 取消关联选项
              ListTile(
                title: const Text(
                  '取消关联',
                  style: TextStyle(color: AppColors.muted),
                ),
                leading: Icon(
                  Icons.link_off,
                  color: config.isLinked ? AppColors.muted : AppColors.accent,
                ),
                onTap: () async {
                  // 清除关联
                  final configs = List<ScanDirectoryConfig>.from(await _provider.getConfigs());
                  final index = configs.indexWhere((c) => c.directory == config.directory);
                  if (index >= 0) {
                    final newConfig = configs[index].copyWith(clearPlaylist: true);
                    await _provider.removeConfig(config.directory);
                    await _provider.addDirectoryWithPlaylist(
                      newConfig.directory,
                    );
                  }
                  if (context.mounted) {
                    Navigator.pop(context);
                  }
                  await _loadDirectories();
                },
              ),
              const Divider(color: AppColors.card),
              // 歌单列表
              ...playlists.map((playlist) => ListTile(
                title: Text(
                  playlist.name,
                  style: TextStyle(
                    color: config.playlistId == playlist.id
                        ? AppColors.accent
                        : AppColors.white,
                  ),
                ),
                leading: Icon(
                  config.playlistId == playlist.id
                      ? Icons.link
                      : Icons.playlist_play,
                  color: config.playlistId == playlist.id
                      ? AppColors.accent
                      : AppColors.muted,
                ),
                onTap: () async {
                  await _provider.updateDirectoryPlaylist(
                    config.directory,
                    playlist.id!,
                    playlist.name,
                  );
                  if (context.mounted) {
                    Navigator.pop(context);
                  }
                  await _loadDirectories();
                },
              )),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭', style: TextStyle(color: AppColors.muted)),
          ),
        ],
      ),
    );
  }

  /// 构建目录项的尾部组件（显示关联状态）
  Widget _buildPlaylistTrailing(ScanDirectoryConfig config) {
    if (config.isLinked) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              config.playlistName!,
              style: const TextStyle(color: AppColors.accent, fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.link, color: AppColors.accent, size: 16),
        ],
      );
    } else {
      return Text(
        '未关联',
        style: TextStyle(
          color: AppColors.muted.withValues(alpha: 0.5),
          fontSize: 12,
        ),
      );
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
        if (_configs.isEmpty)
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
              itemCount: _configs.length,
              separatorBuilder: (context, index) => const Divider(
                color: AppColors.surface,
                height: 1,
              ),
              itemBuilder: (context, index) {
                final config = _configs[index];
                return ListTile(
                  title: Text(
                    config.effectiveDisplayName,
                    style: const TextStyle(color: AppColors.white),
                  ),
                  subtitle: _buildPlaylistTrailing(config),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: AppColors.muted),
                    onPressed: () => _removeDirectory(config),
                  ),
                  onTap: () => _showEditPlaylistDialog(config),
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
