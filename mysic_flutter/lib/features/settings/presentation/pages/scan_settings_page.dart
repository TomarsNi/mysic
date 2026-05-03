import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/scan_options_provider.dart';
import '../widgets/scan_directory_list.dart';
import '../../../../shared/utils/music_scanner.dart';
import '../../../../shared/utils/scan_directory_provider.dart';
import '../../../../features/playlist/presentation/providers/playlist_provider.dart';
import '../../../../features/player/data/models/playlist.dart';
import '../../../../features/playlist/data/playlist_repository.dart';
import '../../../../features/player/presentation/providers/player_provider.dart';

/// 扫描设置页面
class ScanSettingsPage extends StatefulWidget {
  const ScanSettingsPage({super.key});

  @override
  State<ScanSettingsPage> createState() => _ScanSettingsPageState();
}

class _ScanSettingsPageState extends State<ScanSettingsPage> {
  bool _isScanning = false;
  double _scanProgress = 0.0;
  MusicScanner? _currentScanner;
  StreamSubscription<ScanProgress>? _progressSubscription;
  late final TextEditingController _minFileSizeController;

  @override
  void initState() {
    super.initState();
    _minFileSizeController = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<ScanOptionsProvider>();
      provider.load();
      _minFileSizeController.text = provider.minFileSizeKb.toString();
    });
  }

  @override
  void dispose() {
    _progressSubscription?.cancel();
    _minFileSizeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: _buildAppBar(),
      body: Consumer<ScanOptionsProvider>(
        builder: (context, optionsProvider, child) {
          if (!optionsProvider.isLoaded) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.accent),
            );
          }
          return _buildBody(optionsProvider);
        },
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.surface,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: const Text(
        '扫描设置',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
      centerTitle: true,
    );
  }

  Widget _buildBody(ScanOptionsProvider optionsProvider) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 扫描操作区
          _buildScanButton(optionsProvider),
          const SizedBox(height: 24),

          // 扫描目录管理
          const ScanDirectoryList(),
          const SizedBox(height: 24),

          // 高级选项
          _buildAdvancedOptions(optionsProvider),
        ],
      ),
    );
  }

  Widget _buildScanButton(ScanOptionsProvider optionsProvider) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: _isScanning ? null : AppColors.accentGradient,
        color: _isScanning ? AppColors.card : null,
        borderRadius: BorderRadius.circular(16),
        boxShadow: _isScanning
            ? null
            : [
                BoxShadow(
                  color: AppColors.accent.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _isScanning ? null : () => _startScan(optionsProvider),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _isScanning
                    ? SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          value: _scanProgress,
                          valueColor: const AlwaysStoppedAnimation<Color>(AppColors.accent),
                          backgroundColor: AppColors.muted.withValues(alpha: 0.3),
                        ),
                      )
                    : const Icon(Icons.refresh_rounded, color: AppColors.white, size: 24),
                const SizedBox(width: 12),
                Text(
                  _isScanning ? '扫描中 ${(_scanProgress * 100).toInt()}%' : '开始扫描',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAdvancedOptions(ScanOptionsProvider optionsProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '高级选项',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.white,
          ),
        ),
        const SizedBox(height: 16),

        // 文件格式过滤
        _buildFormatFilter(optionsProvider),
        const SizedBox(height: 16),

        // 最小文件大小
        _buildMinFileSizeOption(optionsProvider),
        const SizedBox(height: 16),

        // 自动去重
        _buildAutoDedupeOption(optionsProvider),
      ],
    );
  }

  Widget _buildFormatFilter(ScanOptionsProvider optionsProvider) {
    final formats = ['mp3', 'flac', 'wav', 'm4a', 'ogg', 'aac', 'wma', 'ape'];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '文件格式过滤',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.white),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: formats.map((format) {
              final isSelected = optionsProvider.audioFormats.contains(format);
              return _buildFormatChip(format, isSelected, () {
                optionsProvider.toggleFormat(format);
              });
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildFormatChip(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accent.withValues(alpha: 0.2) : AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppColors.accent : AppColors.muted.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
              size: 16,
              color: isSelected ? AppColors.accent : AppColors.muted,
            ),
            const SizedBox(width: 6),
            Text(
              label.toUpperCase(),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isSelected ? AppColors.accent : AppColors.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMinFileSizeOption(ScanOptionsProvider optionsProvider) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '最小文件大小',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.white),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: AppColors.white),
                  decoration: InputDecoration(
                    hintText: '100',
                    hintStyle: const TextStyle(color: AppColors.muted),
                    filled: true,
                    fillColor: AppColors.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  controller: _minFileSizeController,
                  onSubmitted: (value) {
                    final kb = int.tryParse(value);
                    if (kb != null && kb > 0) {
                      optionsProvider.setMinFileSizeKb(kb);
                    }
                  },
                ),
              ),
              const SizedBox(width: 12),
              const Text('KB', style: TextStyle(color: AppColors.muted)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '过滤掉过小的音频文件',
            style: TextStyle(fontSize: 12, color: AppColors.muted.withValues(alpha: 0.7)),
          ),
        ],
      ),
    );
  }

  Widget _buildAutoDedupeOption(ScanOptionsProvider optionsProvider) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '自动去重',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.white),
                ),
                const SizedBox(height: 4),
                Text(
                  '扫描时自动跳过已存在的歌曲',
                  style: TextStyle(fontSize: 12, color: AppColors.muted.withValues(alpha: 0.7)),
                ),
              ],
            ),
          ),
          _buildToggle(
            optionsProvider.autoDedupe,
            (value) => optionsProvider.setAutoDedupe(value),
          ),
        ],
      ),
    );
  }

  Widget _buildToggle(bool value, ValueChanged<bool> onChanged) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: Container(
        width: 48,
        height: 28,
        decoration: BoxDecoration(
          color: value ? AppColors.accent : AppColors.muted.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
        ),
        child: AnimatedAlign(
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          duration: const Duration(milliseconds: 200),
          child: Container(
            width: 20,
            height: 20,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: value ? AppColors.white : AppColors.muted,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _startScan(ScanOptionsProvider optionsProvider) async {
    final playerProvider = context.read<PlayerProvider>();
    playerProvider.startScan();

    setState(() {
      _isScanning = true;
      _scanProgress = 0.0;
    });

    try {
      final scanner = MusicScanner(
        audioFormats: optionsProvider.audioFormats,
        minFileSizeKb: optionsProvider.minFileSizeKb,
        autoDedupe: optionsProvider.autoDedupe,
      );
      _currentScanner = scanner;

      _progressSubscription = scanner.progressStream.listen((progress) {
        if (mounted) {
          setState(() {
            _scanProgress = progress.progress;
          });
          playerProvider.updateScanProgress(progress.progress);
        }
      });

      final result = await scanner.scanMusic();

      if (mounted && result.isSuccess) {
        // 刷新 PlaylistProvider 数据
        final playlistProvider = context.read<PlaylistProvider>();
        await playlistProvider.refresh();

        // 将歌曲添加到各目录关联的歌单
        await _addSongsToLinkedPlaylists(playlistProvider);

        // 确保"本地音乐"歌单存在并添加所有歌曲（作为总览）
        if (playlistProvider.allSongs.isNotEmpty) {
          await _ensureLocalMusicPlaylist(playlistProvider, result.newAdded);
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('扫描完成: 发现 ${result.totalFound} 首，新增 ${result.newAdded} 首'),
              backgroundColor: AppColors.accent,
            ),
          );
        }
      } else if (mounted && !result.isSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('扫描失败: ${result.errorMessage ?? "未知错误"}'),
            backgroundColor: AppColors.muted,
          ),
        );
      }
    } on Exception catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('扫描失败: $e'),
            backgroundColor: AppColors.muted,
          ),
        );
      }
    } finally {
      _progressSubscription?.cancel();
      _progressSubscription = null;
      if (mounted) {
        playerProvider.finishScan();
        setState(() {
          _isScanning = false;
          _currentScanner = null;
        });
      }
    }
  }

  /// 检查文件路径是否包含指定目录
  /// 支持正斜杠和反斜杠路径分隔符
  bool _isPathInDirectory(String filePath, String directoryName) {
    final lowerPath = filePath.toLowerCase();
    final lowerDir = directoryName.toLowerCase();
    // 正斜杠分隔符: /directory/
    if (lowerPath.contains('/$lowerDir/')) return true;
    // 反斜杠分隔符: \directory\
    final bs = '\\';
    if (lowerPath.contains(bs + lowerDir + bs)) return true;
    // 混合分隔符
    if (lowerPath.contains('/' + lowerDir + bs)) return true;
    if (lowerPath.contains(bs + lowerDir + '/')) return true;
    return false;
  }

  /// 将扫描的歌曲添加到各目录关联的歌单
  Future<void> _addSongsToLinkedPlaylists(PlaylistProvider playlistProvider) async {
    final directoryProvider = ScanDirectoryProvider();
    final configs = await directoryProvider.getConfigs();

    if (configs.isEmpty) return;

    // 获取所有歌曲
    final allSongs = playlistProvider.allSongs;
    if (allSongs.isEmpty) return;

    // 按目录分组添加歌曲
    for (final config in configs) {
      if (!config.isLinked) continue;

      final playlistId = config.playlistId;
      if (playlistId == null) continue;

      // 筛选该目录下的歌曲
      final directorySongs = allSongs
          .where((song) => _isPathInDirectory(song.filePath, config.directory))
          .toList();

      if (directorySongs.isNotEmpty) {
        await playlistProvider.addSongsToPlaylist(playlistId, directorySongs);
      }
    }
  }

  /// 确保存在"本地音乐"歌单，并将所有歌曲添加进去
  Future<void> _ensureLocalMusicPlaylist(
    PlaylistProvider playlistProvider,
    int newSongCount,
  ) async {
    const localMusicPlaylistName = '本地音乐';

    // 查找是否已存在"本地音乐"歌单
    Playlist? localPlaylist;
    try {
      localPlaylist = playlistProvider.playlists.firstWhere(
        (p) => p.name == localMusicPlaylistName,
      );
    } catch (_) {
      // 不存在，需要创建
    }

    if (localPlaylist == null) {
      // 创建"本地音乐"歌单
      localPlaylist = await playlistProvider.createPlaylist(
        name: localMusicPlaylistName,
        description: '扫描本地音乐自动创建',
      );
    }

    final playlistId = localPlaylist?.id;
    if (playlistId == null) return;

    // 获取所有歌曲并添加到歌单
    final allSongs = playlistProvider.allSongs;

    if (allSongs.isEmpty) {
      // 直接从数据库获取
      final repository = PlaylistRepository();
      final songs = await repository.getAllSongs();
      if (songs.isNotEmpty) {
        await playlistProvider.addSongsToPlaylist(playlistId, songs);
      }
    } else {
      await playlistProvider.addSongsToPlaylist(playlistId, allSongs);
    }
  }
}
