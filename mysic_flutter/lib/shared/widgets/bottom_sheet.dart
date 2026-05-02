import 'dart:async';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:mysic_flutter/core/theme/app_colors.dart';
import 'package:mysic_flutter/features/player/data/models/playlist.dart';
import 'package:mysic_flutter/features/player/data/models/song.dart';
import 'package:mysic_flutter/shared/utils/music_scanner.dart';

/// 添加到歌单底部面板
/// 显示歌单列表，允许用户将歌曲添加到指定歌单
class AddToPlaylistSheet extends StatelessWidget {
  /// 歌单列表
  final List<Playlist> playlists;

  /// 要添加的歌曲
  final Song? song;

  /// 歌单选择回调
  final void Function(Playlist)? onPlaylistSelected;

  /// 创建新歌单回调
  final VoidCallback? onCreatePlaylist;

  const AddToPlaylistSheet({
    super.key,
    this.playlists = const [],
    this.song,
    this.onPlaylistSelected,
    this.onCreatePlaylist,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 拖动指示器
          _buildDragHandle(),

          const SizedBox(height: 16),

          // 标题
          _buildHeader(context),

          const SizedBox(height: 8),

          // 创建新歌单按钮
          _buildCreateButton(context),

          const Divider(
            color: AppColors.card,
            height: 24,
          ),

          // 歌单列表
          Expanded(
            child: _buildPlaylistList(context),
          ),
        ],
      ),
    );
  }

  Widget _buildDragHandle() {
    return Container(
      width: 40, // 设计稿要求 w-10 (40px)
      height: 4, // 设计稿要求 h-1 (4px)
      decoration: BoxDecoration(
        color: AppColors.white.withValues(alpha: 0.2), // 设计稿要求 bg-white/20
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          // 歌曲信息
          if (song != null) ...[
            // 歌曲封面
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.music_note_rounded,
                color: AppColors.muted,
                size: 24,
              ),
            ),

            const SizedBox(width: 12),

            // 歌曲标题和艺术家
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    song!.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.white,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),

                  const SizedBox(height: 2),

                  Text(
                    song!.displayArtist,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.muted,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ] else ...[
            const Text(
              '添加到歌单',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.white,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCreateButton(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: AppColors.accent.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(
          Icons.add_rounded,
          color: AppColors.accent,
          size: 24,
        ),
      ),
      title: const Text(
        '创建新歌单',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: AppColors.white,
        ),
      ),
      onTap: () {
        Navigator.of(context).pop();
        onCreatePlaylist?.call();
      },
    );
  }

  Widget _buildPlaylistList(BuildContext context) {
    if (playlists.isEmpty) {
      return _buildEmptyState(context);
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      itemCount: playlists.length,
      itemBuilder: (context, index) {
        final playlist = playlists[index];
        return _PlaylistOptionTile(
          playlist: playlist,
          onTap: () {
            Navigator.of(context).pop();
            onPlaylistSelected?.call(playlist);
          },
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.playlist_add_rounded,
            size: 48,
            color: AppColors.muted.withValues(alpha: 0.5),
          ),

          const SizedBox(height: 16),

          const Text(
            '暂无歌单',
            style: TextStyle(
              fontSize: 16,
              color: AppColors.muted,
            ),
          ),

          const SizedBox(height: 8),

          const Text(
            '点击上方按钮创建新歌单',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.muted,
            ),
          ),
        ],
      ),
    );
  }
}

/// 歌单选项瓦片
/// 设计稿规范：图标 48px (w-12 h-12)，圆角 rounded-xl (12px)，渐变背景
class _PlaylistOptionTile extends StatelessWidget {
  final Playlist playlist;
  final VoidCallback? onTap;

  const _PlaylistOptionTile({
    required this.playlist,
    this.onTap,
  });

  /// 根据歌单类型返回对应的渐变色
  LinearGradient _getGradientForPlaylist(Playlist playlist) {
    final name = playlist.name.toLowerCase();

    if (name.contains('喜欢') || name.contains('favorite')) {
      return AppColors.roseGradient;
    } else if (name.contains('最近') || name.contains('recent')) {
      return AppColors.blueGradient;
    } else if (name.contains('轻音乐') || name.contains('chill')) {
      return AppColors.emeraldGradient;
    } else if (name.contains('运动') || name.contains('workout')) {
      return AppColors.orangeGradient;
    } else if (name.contains('助眠') || name.contains('sleep')) {
      return AppColors.violetGradient;
    }

    return AppColors.accentGradient;
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 48, // 设计稿要求 w-12 (48px)
        height: 48,
        decoration: BoxDecoration(
          gradient: playlist.coverPath == null
              ? _getGradientForPlaylist(playlist)
              : null,
          color: playlist.coverPath != null ? AppColors.card : null,
          borderRadius: BorderRadius.circular(12), // 设计稿要求 rounded-xl
        ),
        child: playlist.coverPath != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  playlist.coverPath!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _buildDefaultIcon(),
                ),
              )
            : _buildDefaultIcon(),
      ),
      title: Text(
        playlist.name,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: AppColors.white,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '${playlist.songCount} 首歌曲',
        style: const TextStyle(
          fontSize: 13,
          color: AppColors.muted,
        ),
      ),
      onTap: onTap,
    );
  }

  Widget _buildDefaultIcon() {
    return const Icon(
      Icons.playlist_play_rounded,
      color: AppColors.white,
      size: 24,
    );
  }
}

/// 歌单选项底部面板
/// 显示歌单的编辑、删除等操作选项
class PlaylistOptionsSheet extends StatelessWidget {
  /// 歌单数据
  final Playlist playlist;

  /// 编辑回调
  final VoidCallback? onEdit;

  /// 删除回调
  final VoidCallback? onDelete;

  /// 分享回调
  final VoidCallback? onShare;

  /// 重命名回调
  final VoidCallback? onRename;

  const PlaylistOptionsSheet({
    super.key,
    required this.playlist,
    this.onEdit,
    this.onDelete,
    this.onShare,
    this.onRename,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 拖动指示器
          Container(
            width: 40, // 设计稿要求 w-10 (40px)
            height: 4, // 设计稿要求 h-1 (4px)
            margin: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              color: AppColors.white.withValues(alpha: 0.2), // 设计稿要求 bg-white/20
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          const SizedBox(height: 24),

          // 歌单信息
          _buildPlaylistInfo(context),

          const Divider(
            color: AppColors.card,
            height: 24,
          ),

          // 选项列表
          _buildOptionsList(context),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildPlaylistInfo(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          // 封面
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.playlist_play_rounded,
              color: AppColors.muted,
              size: 28,
            ),
          ),

          const SizedBox(width: 16),

          // 信息
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  playlist.name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),

                const SizedBox(height: 4),

                Text(
                  '${playlist.songCount} 首歌曲',
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.muted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionsList(BuildContext context) {
    return Column(
      children: [
        // 重命名
        ListTile(
          leading: const Icon(Icons.edit_rounded, color: AppColors.white),
          title: const Text(
            '重命名',
            style: TextStyle(color: AppColors.white),
          ),
          onTap: () {
            Navigator.of(context).pop();
            onRename?.call();
          },
        ),

        // 编辑
        ListTile(
          leading: const Icon(Icons.edit_note_rounded, color: AppColors.white),
          title: const Text(
            '编辑歌曲',
            style: TextStyle(color: AppColors.white),
          ),
          onTap: () {
            Navigator.of(context).pop();
            onEdit?.call();
          },
        ),

        // 分享
        ListTile(
          leading: const Icon(Icons.share_rounded, color: AppColors.white),
          title: const Text(
            '分享',
            style: TextStyle(color: AppColors.white),
          ),
          onTap: () {
            Navigator.of(context).pop();
            onShare?.call();
          },
        ),

        // 删除
        ListTile(
          leading: const Icon(Icons.delete_rounded, color: Color(0xFFEF4444)),
          title: const Text(
            '删除歌单',
            style: TextStyle(color: Color(0xFFEF4444)),
          ),
          onTap: () {
            Navigator.of(context).pop();
            onDelete?.call();
          },
        ),
      ],
    );
  }
}

/// 创建歌单对话框
class CreatePlaylistDialog extends StatefulWidget {
  /// 创建回调
  /// [scannedSongs] 如果用户选择了目录并扫描成功，则为扫描到的歌曲列表；否则为 null
  final void Function(String name, String? description, List<Song>? scannedSongs)? onCreate;

  const CreatePlaylistDialog({
    super.key,
    this.onCreate,
  });

  @override
  State<CreatePlaylistDialog> createState() => _CreatePlaylistDialogState();
}

class _CreatePlaylistDialogState extends State<CreatePlaylistDialog> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _canCreate = false;
  String? _selectedDirectory;
  bool _isScanning = false;
  double _scanProgress = 0.0;
  int _songsFound = 0;
  String? _lastAutoFilledName;

  @override
  void initState() {
    super.initState();
    _nameController.addListener(_updateCanCreate);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _updateCanCreate() {
    setState(() {
      _canCreate = _nameController.text.trim().isNotEmpty;
    });
  }

  /// 从路径中提取文件夹名称
  String _extractFolderName(String path) {
    final parts = path.split(RegExp(r'[\\/]'));
    return parts.where((p) => p.isNotEmpty).last;
  }

  Future<void> _selectDirectory() async {
    final result = await getDirectoryPath();
    if (result != null && mounted) {
      final folderName = _extractFolderName(result);
      setState(() {
        _selectedDirectory = result;
        // 智能填充：空值或等于上次自动填充值时才更新
        if (_nameController.text.isEmpty ||
            _nameController.text == _lastAutoFilledName) {
          _nameController.text = folderName;
          _lastAutoFilledName = folderName;
          _updateCanCreate();
        }
      });
    }
  }

  void _clearDirectory() {
    setState(() {
      _selectedDirectory = null;
      _songsFound = 0;
    });
  }

  void _handleCreate() {
    if (_selectedDirectory != null) {
      _scanAndCreate();
    } else {
      if (!_canCreate || _isScanning) return;

      final name = _nameController.text.trim();
      final description = _descriptionController.text.trim();

      widget.onCreate?.call(
        name,
        description.isEmpty ? null : description,
        null,
      );
      Navigator.of(context).pop();
    }
  }

  Future<void> _scanAndCreate() async {
    if (!_canCreate || _isScanning) return;
    if (_selectedDirectory == null) {
      _handleCreate();
      return;
    }

    setState(() {
      _isScanning = true;
      _scanProgress = 0.0;
    });

    MusicScanner? scanner;
    StreamSubscription<ScanProgress>? subscription;

    try {
      scanner = MusicScanner();
      subscription = scanner.progressStream.listen(
        (progress) {
          if (mounted) {
            setState(() {
              _scanProgress = progress.progress;
            });
          }
        },
        onError: (error) {
          debugPrint('扫描进度错误: $error');
        },
      );

      final result = await scanner.scanMusicInDirectory(_selectedDirectory!);

      if (!mounted) return;

      // 获取本次扫描的歌曲
      List<Song>? scannedSongs;
      if (result.isSuccess && result.newAdded > 0) {
        // 获取所有歌曲（扫描器会保存到数据库）
        final allSongs = await scanner.getAllSongs();
        // 本次扫描的歌曲就是 newAdded 首新歌
        scannedSongs = allSongs.take(result.newAdded).toList();
      }

      setState(() {
        _isScanning = false;
        _songsFound = result.totalFound;
      });

      final name = _nameController.text.trim();
      final description = _descriptionController.text.trim();

      widget.onCreate?.call(
        name,
        description.isEmpty ? null : description,
        scannedSongs,
      );
      Navigator.of(context).pop();
    } on Exception catch (e) {
      if (mounted) {
        setState(() {
          _isScanning = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('扫描失败: $e')),
        );
      }
    } finally {
      await subscription?.cancel();
      await scanner?.dispose();
    }
  }

  Widget _buildDirectorySelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '扫描目录（可选）',
          style: TextStyle(
            fontSize: 14,
            color: AppColors.muted,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _selectedDirectory ?? '未选择目录',
                  style: TextStyle(
                    fontSize: 14,
                    color: _selectedDirectory != null
                        ? AppColors.white
                        : AppColors.muted.withValues(alpha: 0.7),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (_selectedDirectory != null) ...[
                GestureDetector(
                  onTap: _clearDirectory,
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: AppColors.muted,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
              ],
              GestureDetector(
                onTap: _selectDirectory,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    '选择',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.accent,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildScanProgress() {
    if (!_isScanning && _songsFound == 0) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        if (_isScanning) ...[
          Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    AppColors.accent.withValues(alpha: 0.7),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '正在扫描... ${(_scanProgress * 100).toInt()}%',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.muted,
                ),
              ),
            ],
          ),
        ] else if (_songsFound > 0) ...[
          Row(
            children: [
              const Icon(
                Icons.check_circle_rounded,
                size: 16,
                color: AppColors.accent,
              ),
              const SizedBox(width: 8),
              Text(
                '已找到 $_songsFound 首歌曲',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.accent,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      title: const Text(
        '创建歌单',
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: AppColors.white,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 目录选择
          _buildDirectorySelector(),

          _buildScanProgress(),

          const SizedBox(height: 16),

          // 歌单名称输入
          TextField(
            controller: _nameController,
            style: const TextStyle(color: AppColors.white),
            decoration: InputDecoration(
              hintText: '歌单名称',
              hintStyle: TextStyle(color: AppColors.muted.withValues(alpha: 0.7)),
              filled: true,
              fillColor: AppColors.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
            autofocus: true,
            textInputAction: TextInputAction.next,
          ),

          const SizedBox(height: 16),

          // 描述输入
          TextField(
            controller: _descriptionController,
            style: const TextStyle(color: AppColors.white),
            decoration: InputDecoration(
              hintText: '描述（可选）',
              hintStyle: TextStyle(color: AppColors.muted.withValues(alpha: 0.7)),
              filled: true,
              fillColor: AppColors.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
            maxLines: 2,
            textInputAction: TextInputAction.done,
          ),
        ],
      ),
      actions: [
        // 取消按钮
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(
            '取消',
            style: TextStyle(color: AppColors.muted),
          ),
        ),

        // 创建按钮
        ElevatedButton(
          onPressed: (_canCreate && !_isScanning) ? _handleCreate : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accent,
            foregroundColor: AppColors.white,
            disabledBackgroundColor: AppColors.muted.withValues(alpha: 0.3),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: _isScanning
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.white),
                  ),
                )
              : const Text('创建'),
        ),
      ],
    );
  }
}

/// 显示添加到歌单面板的辅助函数
void showAddToPlaylistSheet(
  BuildContext context, {
  List<Playlist> playlists = const [],
  Song? song,
  void Function(Playlist)? onPlaylistSelected,
  VoidCallback? onCreatePlaylist,
}) {
  showModalBottomSheet(
    context: context,
    backgroundColor: AppColors.card,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) => AddToPlaylistSheet(
      playlists: playlists,
      song: song,
      onPlaylistSelected: onPlaylistSelected,
      onCreatePlaylist: onCreatePlaylist,
    ),
  );
}

/// 显示歌单选项面板的辅助函数
void showPlaylistOptionsSheet(
  BuildContext context, {
  required Playlist playlist,
  VoidCallback? onEdit,
  VoidCallback? onDelete,
  VoidCallback? onShare,
  VoidCallback? onRename,
}) {
  showModalBottomSheet(
    context: context,
    backgroundColor: AppColors.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) => PlaylistOptionsSheet(
      playlist: playlist,
      onEdit: onEdit,
      onDelete: onDelete,
      onShare: onShare,
      onRename: onRename,
    ),
  );
}

/// 显示创建歌单对话框的辅助函数
void showCreatePlaylistDialog(
  BuildContext context, {
  void Function(String name, String? description, List<Song>? scannedSongs)? onCreate,
}) {
  showDialog(
    context: context,
    builder: (context) => CreatePlaylistDialog(onCreate: onCreate),
  );
}
