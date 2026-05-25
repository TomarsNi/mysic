import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite/sqflite.dart' show ConflictAlgorithm;
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';

import 'core/theme/app_theme.dart';
import 'core/theme/app_colors.dart';
import 'core/database/database_helper.dart';
import 'core/utils/app_logger.dart';
import 'features/player/presentation/providers/player_provider.dart';
import 'features/player/presentation/providers/sleep_timer_provider.dart';
import 'features/playlist/presentation/providers/playlist_provider.dart';
import 'features/lyrics/presentation/pages/lyrics_page.dart' show LyricsPage;
import 'features/lyrics/data/services/lyrics_parser.dart' show LyricLine;
import 'features/settings/presentation/pages/about_page.dart';
import 'features/settings/presentation/pages/api_settings_page.dart';
import 'features/settings/data/scan_options_provider.dart';
import 'features/settings/presentation/pages/scan_settings_page.dart';
import 'features/settings/presentation/providers/api_config_provider.dart';
import 'features/settings/presentation/widgets/scan_directory_list.dart';
import 'features/ai_skills/presentation/providers/ai_skills_provider.dart';
import 'features/ai_skills/presentation/widgets/magic_wand_button.dart';
import 'features/ai_skills/presentation/widgets/skill_selection_sheet.dart';
import 'features/ai_skills/presentation/widgets/result_preview_sheet.dart';
import 'features/ai_skills/core/ai_skill.dart';
import 'features/ai_skills/core/skill_result.dart';
import 'shared/widgets/app_drawer.dart';
import 'shared/widgets/bottom_sheet.dart' show showCreatePlaylistDialog;
import 'shared/widgets/delete_confirm_sheet.dart';
import 'shared/widgets/playlist_queue_sheet.dart';
import 'shared/utils/music_scanner.dart';
import 'shared/utils/scan_directory_provider.dart';
import 'features/playlist/data/playlist_repository.dart';
import 'features/settings/data/play_mode_preference.dart';
import 'features/player/data/models/song.dart';
import 'features/player/presentation/widgets/album_cover.dart';
import 'features/player/presentation/widgets/play_controls.dart';
import 'features/player/presentation/widgets/progress_bar.dart';
import 'features/player/presentation/widgets/sleep_timer_button.dart';

/// 收藏按钮红色
const Color _favoriteRed = Color(0xFFEF4444);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化 Windows 平台 SQLite FFI
  if (Platform.isWindows) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  // 初始化数据库
  await DatabaseHelper().database;

  // Android 13+ 请求通知权限
  if (Platform.isAndroid) {
    final notificationStatus = await Permission.notification.status;
    if (!notificationStatus.isGranted) {
      await Permission.notification.request();
    }
  }

  // 设置系统 UI 样式
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Color(0xFF1A1A2E),
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  runApp(const MysicApp());
}

/// Mysic 音乐播放器应用
class MysicApp extends StatelessWidget {
  const MysicApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => PlayerProvider()),
        ChangeNotifierProvider(create: (_) => SleepTimerProvider()),
        ChangeNotifierProvider(create: (_) => PlaylistProvider()),
        ChangeNotifierProvider(create: (_) => ApiConfigProvider()..load()),
        ChangeNotifierProvider(create: (_) => AiSkillsProvider()),
        ChangeNotifierProvider(create: (_) => ScanOptionsProvider()..load()),
      ],
      child: MaterialApp(
        title: 'Mysic',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: const HomePage(),
      ),
    );
  }
}

/// 主页面
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
  late AnimationController _fabAnimationController;
  bool _isScanning = false;
  MusicScanner? _currentScanner;
  PlayerProvider? _playerProvider;

  @override
  void initState() {
    super.initState();
    _fabAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    // 加载歌单并恢复播放 - 延迟到 build 完成后执行
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _playerProvider = context.read<PlayerProvider>();
      // 设置睡眠倒计时完成回调
      _setupSleepTimerCallback();
      await _loadPlaylists();
      // 恢复上次播放的歌单
      await _restoreLastPlaylist();
    });
  }

  /// 设置睡眠倒计时完成回调
  void _setupSleepTimerCallback() {
    final sleepTimerProvider = context.read<SleepTimerProvider>();
    final playerProvider = context.read<PlayerProvider>();

    // 设置睡眠倒计时完成回调
    sleepTimerProvider.setOnComplete(() {
      // 暂停播放
      playerProvider.pause();

      // 显示提示
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('睡眠倒计时已结束，播放已暂停'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      }
    });

    // 设置歌曲播放完成回调（用于通知 SleepTimerProvider 递减歌曲计数）
    playerProvider.onSongCompleted = () {
      sleepTimerProvider.onSongCompleted();
    };
  }

  Future<void> _loadPlaylists() async {
    final playlistProvider = context.read<PlaylistProvider>();
    await playlistProvider.refresh();
  }

  /// 恢复上次播放的歌单
  Future<void> _restoreLastPlaylist() async {
    final playerProvider = context.read<PlayerProvider>();
    final playlistProvider = context.read<PlaylistProvider>();
    final repository = PlaylistRepository();

    // 1. 尝试获取上次播放的歌单 ID
    final lastPlaylistIdStr = await repository.getAppState('last_playlist_id');
    int? playlistId = lastPlaylistIdStr != null ? int.tryParse(lastPlaylistIdStr) : null;

    // 2. 如果歌单不存在，回退到"本地音乐"歌单
    if (playlistId == null) {
      final localPlaylist = playlistProvider.playlists.where((p) => p.name == '本地音乐').firstOrNull;
      playlistId = localPlaylist?.id;
    } else {
      // 验证歌单是否还存在
      final playlist = await repository.getPlaylistById(playlistId);
      if (playlist == null) {
        // 歌单已删除，回退到"本地音乐"
        final localPlaylist = playlistProvider.playlists.where((p) => p.name == '本地音乐').firstOrNull;
        playlistId = localPlaylist?.id;
      }
    }

    if (playlistId == null) return;

    // 3. 加载歌单歌曲
    await playlistProvider.selectPlaylist(playlistId);
    final songs = playlistProvider.selectedPlaylistSongs;
    if (songs.isEmpty) return;

    // 4. 尝试恢复最后播放的歌曲
    final lastSongId = await PlayModePreference.loadLastSongId();
    int startIndex = 0;

    if (lastSongId != null) {
      // 查找歌曲在歌单中的位置
      final index = songs.indexWhere((s) => s.id == lastSongId);
      if (index != -1) {
        startIndex = index;
      }
    }

    // 5. 播放歌单
    final playlistName = playlistProvider.selectedPlaylist?.name ?? '';
    await playerProvider.setPlaylist(
      songs,
      startIndex: startIndex,
      autoPlay: true,
      playlistName: playlistName,
    );
  }

  @override
  void dispose() {
    _playerProvider?.onSongCompleted = null;
    _fabAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<PlayerProvider, PlaylistProvider>(
      builder: (context, playerProvider, playlistProvider, child) {
        return Scaffold(
          backgroundColor: const Color(0xFF1A1A2E),
          drawer: AppDrawer(
            playlists: playlistProvider.playlists,
            selectedPlaylistId: playlistProvider.selectedPlaylist?.id,
            favoritesPlaylist: playlistProvider.favoritesPlaylist,
            onPlaylistTap: (playlist) async {
              final playlistId = playlist.id;
              if (playlistId == null) return;

              // 1. 记录最后播放的歌单
              final repository = PlaylistRepository();
              await repository.setAppState('last_playlist_id', playlistId.toString());

              // 2. 选择歌单（加载歌曲）
              await playlistProvider.selectPlaylist(playlistId);

              // 3. 获取歌曲列表
              final songs = playlistProvider.selectedPlaylistSongs;

              if (songs.isNotEmpty) {
                // 4. 设置播放列表并自动播放
                await playerProvider.setPlaylist(
                  songs,
                  autoPlay: true,
                  playlistName: playlist.name,
                );
              }

              // 5. 抽屉会自动关闭（在 AppDrawer 中处理）
            },
            onFavoritesTap: (playlist) async {
              final playlistId = playlist.id;
              if (playlistId == null) return;

              // 记录最后播放的歌单
              final repository = PlaylistRepository();
              await repository.setAppState('last_playlist_id', playlistId.toString());

              // 选择歌单
              await playlistProvider.selectPlaylist(playlistId);

              // 获取歌曲列表
              final songs = playlistProvider.selectedPlaylistSongs;

              if (songs.isNotEmpty) {
                await playerProvider.setPlaylist(
                  songs,
                  autoPlay: true,
                  playlistName: playlist.name,
                );
              }
            },
            onScanSettingsTap: () => _showScanSettings(context),
            onSettingsTap: () => _showSettings(context),
            onAboutTap: () => _showAbout(context),
            onApiSettingsTap: () => _showApiSettings(context),
            onCreatePlaylistTap: () => _createPlaylist(context),
          ),
          body: _buildBody(context, playerProvider),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context, PlayerProvider playerProvider) {
    return SafeArea(
      child: Column(
        children: [
          // 顶部栏
          _buildTopBar(context),

          // 主内容区
          Expanded(
            child: Column(
              children: [
                // 有边距的内容区域
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 20),

                      // 专辑封面 - 使用 Selector 避免频繁重建
                      Expanded(
                        flex: 3,
                        child: Center(
                          child: Selector<PlayerProvider, (Song?, bool)>(
                            selector: (_, provider) => (provider.currentSong, provider.isPlaying),
                            builder: (context, data, _) {
                              final currentSong = data.$1;
                              final isPlaying = data.$2;
                              final hasSong = currentSong != null;
                              return GestureDetector(
                                onTap: hasSong ? null : _startScan,
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    AlbumCover(
                                      song: currentSong,
                                      size: 260,
                                      isPlaying: isPlaying,
                                    ),
                                    // 首次使用引导
                                    if (!hasSong && !_isScanning)
                                      Positioned(
                                        bottom: -40,
                                        child: Material(
                                          color: Colors.transparent,
                                          child: InkWell(
                                            onTap: _startScan,
                                            borderRadius: BorderRadius.circular(24),
                                            child: AnimatedContainer(
                                              duration: const Duration(milliseconds: 150),
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 24,
                                                vertical: 12,
                                              ),
                                              decoration: BoxDecoration(
                                                color: AppColors.accent,
                                                borderRadius: BorderRadius.circular(24),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: AppColors.accent.withValues(alpha: 0.3),
                                                    blurRadius: 20,
                                                    spreadRadius: -5,
                                                    offset: const Offset(0, 8),
                                                  ),
                                                ],
                                              ),
                                              child: const Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    Icons.folder_open_rounded,
                                                    color: Colors.white,
                                                    size: 20,
                                                  ),
                                                  SizedBox(width: 8),
                                                  Text(
                                                    '扫描本地音乐',
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                      fontWeight: FontWeight.w500,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ),

                      const SizedBox(height: 32),

                      // 歌曲信息 - 使用 Selector 避免频繁重建
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Selector<PlayerProvider, Song?>(
                          selector: (_, provider) => provider.currentSong,
                          builder: (context, currentSong, _) => _buildSongInfo(currentSong),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // 歌词预览 - 使用 Selector 避免频繁重建
                      Selector<PlayerProvider, Song?>(
                        selector: (_, provider) => provider.currentSong,
                        builder: (context, currentSong, _) {
                          if (currentSong == null) return const SizedBox.shrink();
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Selector<PlayerProvider, (LyricLine?, LyricLine?)>(
                              selector: (_, provider) => (provider.currentLyricLine, provider.nextLyricLine),
                              builder: (context, data, _) => _buildLyricsPreviewStatic(data.$1?.text, data.$2?.text),
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 24),
                    ],
                  ),
                ),

                // 进度条 - 需要实时更新，直接使用 Consumer
                Selector<PlayerProvider, (Duration, Duration?, bool)>(
                  selector: (_, provider) => (provider.position, provider.duration, provider.hasCurrentSong),
                  builder: (context, data, _) {
                    return ProgressBar(
                      position: data.$1,
                      duration: data.$2,
                      enabled: data.$3,
                      onSeek: (progress) => playerProvider.seekToProgress(progress),
                    );
                  },
                ),

                const SizedBox(height: 24),

                // 播放控制区域 - 使用 Selector 避免频繁重建
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Selector<PlayerProvider, (bool, bool, bool)>(
                    selector: (_, provider) => (provider.isPlaying, provider.isLoading, provider.hasPlaylist),
                    builder: (context, data, _) {
                      final isPlaying = data.$1;
                      final isLoading = data.$2;
                      final hasPlaylist = data.$3;
                      return Stack(
                        alignment: Alignment.center,
                        children: [
                          // 播放控制 - 水平居中
                          PlayControls(
                            isPlaying: isPlaying,
                            isLoading: isLoading,
                            hasPlaylist: hasPlaylist,
                            onPlayPause: () => playerProvider.togglePlayPause(),
                            onNext: () => playerProvider.next(),
                            onPrevious: () => playerProvider.previous(),
                          ),

                          // 睡眠倒计时按钮 - 固定左侧
                          Positioned(
                            left: 0,
                            child: const SleepTimerButton(),
                          ),

                          // 歌单按钮 - 固定右侧，与播放控制垂直对齐
                          if (hasPlaylist)
                            Positioned(
                              right: 0,
                              child: _PlaylistQueueButton(
                                onTap: () => _showPlaylistQueue(context),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    // 设计稿规范：
    // - 三栏布局：菜单按钮 + 标题 + 添加按钮
    // - 按钮：p-3 rounded-xl bg-card
    // - 标题：上方 muted xs 文字，下方 font-medium sm
    return Consumer2<PlayerProvider, ApiConfigProvider>(
      builder: (context, playerProvider, apiConfigProvider, child) {
        final currentSong = playerProvider.currentSong;
        final playlistName = playerProvider.playlistName;
        final hasEnabledApi = apiConfigProvider.enabledConfig != null;
        return Padding(
          padding: const EdgeInsets.only(left: 0, right: 0, top: 16, bottom: 16),
          child: Stack(
            children: [
              // 文字层 - 绝对居中于屏幕
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '正在播放',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF71717A),
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      playlistName.isNotEmpty ? playlistName : '全部歌曲',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),

              // 按钮层 - 左右分布
              Row(
                children: [
                  // 抽屉按钮
                  _TopBarButton(
                    icon: Icons.menu_rounded,
                    onPressed: () => Scaffold.of(context).openDrawer(),
                  ),

                  const Spacer(),

                  // 魔法棒按钮
                  if (hasEnabledApi) ...[
                    MagicWandButton(
                      visible: currentSong != null,
                      onTap: () => _showSkillSelection(context, currentSong!),
                    ),
                    const SizedBox(width: 12),
                  ],

                  // 加号按钮
                  _AddButton(
                    currentSong: currentSong,
                    onAddToPlaylist: () => _showAddToPlaylist(context, currentSong!),
                    onEdit: () => _showEditSongDialog(context, currentSong!),
                    onDelete: () => _showDeleteConfirmSheet(context, currentSong!),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  /// 显示歌曲编辑对话框
  void _showEditSongDialog(BuildContext context, Song song) {
    showDialog(
      context: context,
      builder: (context) => _SongEditDialog(
        song: song,
        onSave: (updatedSong) async {
          final playerProvider = context.read<PlayerProvider>();
          await playerProvider.updateSong(updatedSong);

          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('歌曲信息已更新'),
                backgroundColor: Color(0xFF10B981),
              ),
            );
          }
        },
      ),
    );
  }

  Widget _buildSongInfo(Song? song) {
    return Consumer<PlaylistProvider>(
      builder: (context, playlistProvider, _) {
        final isFavorite = song?.id != null && playlistProvider.isSongFavorite(song!.id!);

        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 歌曲名称区域
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    song?.title ?? '未选择歌曲',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    song != null
                        ? '${song.displayArtist} · ${song.displayAlbum}'
                        : '扫描本地音乐开始播放',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF9CA3AF),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            // 爱心按钮
            if (song != null)
              _FavoriteButton(
                isFavorite: isFavorite,
                onTap: () => _toggleFavorite(context, song),
              ),
          ],
        );
      },
    );
  }

  /// 切换收藏状态
  Future<void> _toggleFavorite(BuildContext context, Song song) async {
    final playlistProvider = context.read<PlaylistProvider>();
    await playlistProvider.toggleFavorite(song);
  }

  Widget _buildLyricsPreviewStatic(String? currentLyric, String? nextLyric) {
    // 设计稿规范：
    // - 两行歌词：当前行 lg font-medium white，下一行 muted
    // - 左对齐，无背景色
    // - 点击可进入歌词页面
    final displayCurrentLyric = currentLyric ?? '暂无歌词';
    final displayNextLyric = nextLyric ?? '';

    return GestureDetector(
      onTap: currentLyric != null ? () => _openLyricsPage(context) : null,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 当前行 - 设计稿要求 lg font-medium white
            Text(
              displayCurrentLyric,
              style: const TextStyle(
                fontSize: 18, // lg
                fontWeight: FontWeight.w500, // font-medium
                color: Colors.white,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (displayNextLyric.isNotEmpty) ...[
              const SizedBox(height: 4),
              // 下一行 - muted 色
              Text(
                displayNextLyric,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF71717A), // muted
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }

  // 操作方法
  Future<void> _startScan() async {
    AppLogger.d('HomePage#_startScan', '开始扫描');
    final playerProvider = context.read<PlayerProvider>();
    playerProvider.startScan();

    setState(() {
      _isScanning = true;
    });

    try {
      final scanner = MusicScanner();
      _currentScanner = scanner;

      // 监听进度
      scanner.progressStream.listen((progress) {
        if (mounted) {
          // 同步到 Provider
          playerProvider.updateScanProgress(progress.progress);
          playerProvider.updateScanDetail(
            path: progress.currentPath,
            found: progress.songsFound,
          );
        }
      });

      final result = await scanner.scanMusic();
      AppLogger.d('HomePage#_startScan', '扫描结果: success=${result.isSuccess}, totalFound=${result.totalFound}, newAdded=${result.newAdded}, error=${result.errorMessage}');

      if (mounted && result.isSuccess) {
        // 先刷新 Provider 数据，确保歌曲列表是最新的
        final playlistProvider = context.read<PlaylistProvider>();

        // 直接从数据库验证数据是否保存成功
        final db = await DatabaseHelper().database;
        final dbCount = await db.rawQuery('SELECT COUNT(*) as count FROM ${DatabaseHelper.tableSongs}');
        AppLogger.d('HomePage#_startScan', '数据库中实际歌曲数: ${dbCount.first['count']}');

        await playlistProvider.refresh();
        AppLogger.i('HomePage#_startScan', '刷新 Provider 完成，allSongs 数量: ${playlistProvider.allSongs.length}');

        // 同步到系统"本地音乐"歌单
        await playlistProvider.syncToLocalMusicPlaylist(playlistProvider.allSongs);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '扫描完成: 发现 ${result.totalFound} 首歌曲，新增 ${result.newAdded} 首',
            ),
            backgroundColor: const Color(0xFF6366F1),
          ),
        );

        // 重新加载歌单
        await _loadPlaylists();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '扫描失败: ${result.errorMessage}',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('扫描失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        playerProvider.finishScan();
        setState(() {
          _isScanning = false;
          _currentScanner = null;
        });
      }
    }
  }

  void _cancelScan() {
    _currentScanner?.cancelScan();
    setState(() {
      _isScanning = false;
      _currentScanner = null;
    });
  }

  void _openLyricsPage(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const LyricsPage(),
      ),
    );
  }

  void _showSearch(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF16213E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => const SearchSheet(),
    );
  }

  void _showSettings(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF16213E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => const SettingsSheet(),
    );
  }

  void _showAbout(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const AboutPage(),
      ),
    );
  }

  void _showApiSettings(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const ApiSettingsPage(),
      ),
    );
  }

  void _showScanSettings(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const ScanSettingsPage(),
      ),
    );
  }

  void _createPlaylist(BuildContext context) {
    showCreatePlaylistDialog(
      context,
      onCreate: (name, description, scannedSongs, scannedDirectory) async {
        AppLogger.d('HomePage#_createPlaylist', '开始创建歌单: $name');
        AppLogger.d('HomePage#_createPlaylist', 'scannedSongs: ${scannedSongs?.length ?? "null"}, scannedDirectory: $scannedDirectory');

        final playlistProvider = context.read<PlaylistProvider>();

        // 创建歌单
        final playlist = await playlistProvider.createPlaylist(
          name: name,
          description: description,
        );
        AppLogger.d('HomePage#_createPlaylist', '创建歌单结果: ${playlist?.id}, ${playlist?.name}');

        if (playlist != null) {
          // 如果选择了目录，存储目录与歌单的关联
          if (scannedDirectory != null && scannedDirectory.isNotEmpty) {
            final scanDirectoryProvider = ScanDirectoryProvider();
            await scanDirectoryProvider.addDirectoryWithPlaylist(
              scannedDirectory,
              playlistId: playlist.id!,
              playlistName: playlist.name,
            );
            AppLogger.i('HomePage#_createPlaylist', '目录关联已保存');
          }

          if (scannedSongs != null && scannedSongs.isNotEmpty) {
            AppLogger.d('HomePage#_createPlaylist', '开始添加歌曲到歌单...');
            // 添加到新创建的歌单
            final addedCount = await playlistProvider.addSongsToPlaylist(playlist.id!, scannedSongs);
            AppLogger.i('HomePage#_createPlaylist', '添加歌曲结果: $addedCount');

            // 同步到系统"本地音乐"歌单
            await playlistProvider.syncToLocalMusicPlaylist(scannedSongs);
            AppLogger.i('HomePage#_createPlaylist', '同步到本地音乐歌单完成');

            // 刷新数据
            await playlistProvider.refresh();
            AppLogger.i('HomePage#_createPlaylist', '刷新数据完成');

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('歌单创建成功，已添加 ${scannedSongs.length} 首歌曲'),
                  backgroundColor: const Color(0xFF10B981),
                ),
              );
            }
          } else if (mounted) {
            AppLogger.d('HomePage#_createPlaylist', '没有扫描歌曲，跳过添加');
            // 歌单创建成功但没有扫描歌曲
            await playlistProvider.refresh();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('歌单创建成功'),
                backgroundColor: Color(0xFF10B981),
              ),
            );
          }
        }
        AppLogger.d('HomePage#_createPlaylist', '创建歌单流程结束');
      },
    );
  }

  void _showDeleteConfirmSheet(BuildContext context, Song song) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => DeleteConfirmSheet(
        song: song,
        onConfirm: (deleteWithFile) async {
          final playlistProvider = context.read<PlaylistProvider>();

          // 删除歌曲
          await playlistProvider.deleteSong(
            song.id!,
            deleteFile: deleteWithFile,
          );

          // 刷新歌单数据
          await playlistProvider.refresh();

          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  deleteWithFile ? '歌曲和原文件已删除' : '歌曲已删除',
                ),
                backgroundColor: const Color(0xFF10B981),
              ),
            );
          }
        },
      ),
    );
  }

  void _showAddToPlaylist(BuildContext context, Song song) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF16213E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => AddToPlaylistSheet(song: song),
    );
  }

  void _showPlaylistQueue(BuildContext context) {
    final playerProvider = context.read<PlayerProvider>();
    final playlistProvider = context.read<PlaylistProvider>();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        snap: true,
        snapSizes: const [0.4, 0.9],
        builder: (context, scrollController) => PlaylistQueueSheet(
          songs: playerProvider.playlist,
          currentIndex: playerProvider.currentIndex,
          playlistName: playlistProvider.selectedPlaylist?.name ?? '播放列表',
          scrollController: scrollController,
          onSongTap: (index) {
            playerProvider.seekToIndex(index);
            Navigator.of(context).pop();
          },
        ),
      ),
    );
  }

  // AI Skills 相关方法

  /// 显示 Skill 选择菜单
  void _showSkillSelection(BuildContext context, Song song) {
    final aiSkillsProvider = context.read<AiSkillsProvider>();
    final apiConfigProvider = context.read<ApiConfigProvider>();
    final config = apiConfigProvider.enabledConfig;

    if (config == null) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => SkillSelectionSheet(
        skills: aiSkillsProvider.skills,
        onSkillSelected: (skill) {
          Navigator.pop(context);
          _executeSkill(context, skill, song, config);
        },
      ),
    );
  }

  /// 执行 Skill
  void _executeSkill(
    BuildContext context,
    AiSkill skill,
    Song song,
    dynamic config,
  ) {
    final aiSkillsProvider = context.read<AiSkillsProvider>();

    // 构建输入
    final input = skill.id == 'song_recognition'
        ? {
            'filePath': song.filePath,
            'currentTitle': song.title,
            'currentArtist': song.artist,
            'currentAlbum': song.album,
          }
        : {
            'title': song.title,
            'artist': song.artist,
            'album': song.album,
          };

    // 显示结果预览
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false, // 禁止下拉手势关闭
      builder: (context) => ListenableBuilder(
        listenable: aiSkillsProvider,
        builder: (context, _) {
          return ResultPreviewSheet(
            skill: skill,
            status: aiSkillsProvider.status,
            result: aiSkillsProvider.result,
            song: song,
            onConfirm: () {
              _applyResult(context, skill, aiSkillsProvider.result, song);
              Navigator.pop(context);
            },
            onCancel: () {
              aiSkillsProvider.reset();
              Navigator.pop(context);
            },
            onRetry: () {
              aiSkillsProvider.executeSkill(
                skill: skill,
                config: config,
                input: input,
              );
            },
          );
        },
      ),
    );

    // 执行 Skill
    aiSkillsProvider.executeSkill(
      skill: skill,
      config: config,
      input: input,
    );
  }

  /// 应用 Skill 结果
  Future<void> _applyResult(
    BuildContext context,
    AiSkill skill,
    SkillResult? result,
    Song song,
  ) async {
    if (result is! SkillSuccess) return;

    final data = result.data;
    final playerProvider = context.read<PlayerProvider>();
    final playlistProvider = context.read<PlaylistProvider>();

    if (skill.id == 'song_recognition') {
      // 更新歌曲信息
      final updatedSong = song.copyWith(
        title: data['title'] as String,
        artist: data['artist'] as String,
        album: data['album'] as String,
        albumArtBase64: data['albumArtBase64'] as String?,
        updatedAt: DateTime.now(),
      );

      await playerProvider.updateSong(updatedSong);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('歌曲信息已更新'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      }
    } else if (skill.id == 'lyrics_search') {
      // 保存歌词
      final db = await DatabaseHelper().database;
      await db.insert(
        DatabaseHelper.tableLyrics,
        {
          'song_id': song.id,
          'lrc_content': data['lyrics'] as String,
          'is_synced': 1,
          'source': data['source'] as String?,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // 重新加载歌词到播放器
      await playerProvider.reloadLyrics();

      // 刷新播放器状态
      await playlistProvider.refresh();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('歌词已保存'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      }
    }

    // 重置状态
    context.read<AiSkillsProvider>().reset();
  }
}

/// 搜索面板
class SearchSheet extends StatefulWidget {
  const SearchSheet({super.key});

  @override
  State<SearchSheet> createState() => _SearchSheetState();
}

class _SearchSheetState extends State<SearchSheet> {
  final _searchController = TextEditingController();
  List<dynamic> _results = [];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // 搜索框
            TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: '搜索歌曲、艺术家、专辑...',
                hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
                prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF9CA3AF)),
                filled: true,
                fillColor: const Color(0xFF1A1A2E),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: _onSearch,
            ),

            const SizedBox(height: 20),

            // 搜索结果
            Expanded(
              child: _results.isEmpty
                  ? const Center(
                      child: Text(
                        '输入关键词搜索',
                        style: TextStyle(color: Color(0xFF9CA3AF)),
                      ),
                    )
                  : ListView.builder(
                      controller: scrollController,
                      itemCount: _results.length,
                      itemBuilder: (context, index) {
                        final song = _results[index];
                        return ListTile(
                          leading: const Icon(Icons.music_note_rounded, color: Color(0xFF6366F1)),
                          title: Text(
                            song.title,
                            style: const TextStyle(color: Colors.white),
                          ),
                          subtitle: Text(
                            song.displayArtist,
                            style: const TextStyle(color: Color(0xFF9CA3AF)),
                          ),
                          onTap: () {
                            final playerProvider = context.read<PlayerProvider>();
                            playerProvider.playSong(song);
                            Navigator.pop(context);
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _onSearch(String query) async {
    if (query.isEmpty) {
      setState(() => _results = []);
      return;
    }

    final repository = PlaylistRepository();
    final songs = await repository.searchSongs(query);
    setState(() => _results = songs);
  }
}

/// 设置面板
class SettingsSheet extends StatelessWidget {
  const SettingsSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 标题
          Row(
            children: [
              const Text(
                '设置',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: Color(0xFF9CA3AF)),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // 设置项
          ListTile(
            leading: const Icon(Icons.color_lens_rounded, color: Color(0xFF6366F1)),
            title: const Text('主题', style: TextStyle(color: Colors.white)),
            subtitle: const Text('深色模式', style: TextStyle(color: Color(0xFF9CA3AF))),
            onTap: () {},
          ),

          ListTile(
            leading: const Icon(Icons.audio_file_rounded, color: Color(0xFF6366F1)),
            title: const Text('音频设置', style: TextStyle(color: Colors.white)),
            subtitle: const Text('音质、淡入淡出', style: TextStyle(color: Color(0xFF9CA3AF))),
            onTap: () {},
          ),

          ListTile(
            leading: const Icon(Icons.storage_rounded, color: Color(0xFF6366F1)),
            title: const Text('存储', style: TextStyle(color: Colors.white)),
            subtitle: const Text('缓存管理', style: TextStyle(color: Color(0xFF9CA3AF))),
            onTap: () {},
          ),

          ListTile(
            leading: const Icon(Icons.folder_rounded, color: Color(0xFF6366F1)),
            title: const Text('扫描目录', style: TextStyle(color: Colors.white)),
            subtitle: const Text('管理音乐扫描目录', style: TextStyle(color: Color(0xFF9CA3AF))),
            onTap: () {
              Navigator.pop(context);
              _showScanDirectorySheet(context);
            },
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  void _showScanDirectorySheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(20),
          child: const ScanDirectoryList(),
        ),
      ),
    );
  }
}

/// 添加到歌单面板
class AddToPlaylistSheet extends StatefulWidget {
  final Song song;

  const AddToPlaylistSheet({super.key, required this.song});

  @override
  State<AddToPlaylistSheet> createState() => _AddToPlaylistSheetState();
}

class _AddToPlaylistSheetState extends State<AddToPlaylistSheet> {
  @override
  Widget build(BuildContext context) {
    final playlistProvider = context.watch<PlaylistProvider>();
    final playlists = playlistProvider.playlists;

    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题
          Row(
            children: [
              const Text(
                '添加到歌单',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: Color(0xFF9CA3AF)),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // 歌单列表
          if (playlists.isEmpty)
            const Center(
              child: Text(
                '暂无歌单，请先创建歌单',
                style: TextStyle(color: Color(0xFF9CA3AF)),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              itemCount: playlists.length,
              itemBuilder: (context, index) {
                final playlist = playlists[index];
                return ListTile(
                  leading: const Icon(Icons.playlist_play_rounded, color: Color(0xFF6366F1)),
                  title: Text(
                    playlist.name,
                    style: const TextStyle(color: Colors.white),
                  ),
                  subtitle: Text(
                    '${playlist.songCount} 首歌曲',
                    style: const TextStyle(color: Color(0xFF9CA3AF)),
                  ),
                  onTap: () async {
                    final playlistId = playlist.id;
                    if (playlistId != null) {
                      await playlistProvider.addSongToPlaylist(playlistId, widget.song);
                      if (mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('已添加到歌单'),
                            backgroundColor: Color(0xFF6366F1),
                          ),
                        );
                      }
                    }
                  },
                );
              },
            ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

/// 歌曲编辑对话框
class _SongEditDialog extends StatefulWidget {
  final Song song;
  final void Function(Song updatedSong) onSave;

  const _SongEditDialog({
    required this.song,
    required this.onSave,
  });

  @override
  State<_SongEditDialog> createState() => _SongEditDialogState();
}

class _SongEditDialogState extends State<_SongEditDialog> {
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
      backgroundColor: const Color(0xFF16213E),
      title: const Text('编辑歌曲信息', style: TextStyle(color: Colors.white)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: '歌曲名称',
                labelStyle: TextStyle(color: Color(0xFF9CA3AF)),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF9CA3AF)),
                ),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _artistController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: '艺术家',
                labelStyle: TextStyle(color: Color(0xFF9CA3AF)),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF9CA3AF)),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _albumController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: '专辑',
                labelStyle: TextStyle(color: Color(0xFF9CA3AF)),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF9CA3AF)),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消', style: TextStyle(color: Color(0xFF9CA3AF))),
        ),
        ElevatedButton(
          onPressed: _handleSave,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF10B981),
          ),
          child: const Text('保存'),
        ),
      ],
    );
  }
}

/// 歌单队列按钮（右下角浮动按钮）
/// 简约风格：无背景，只保留图标，hover 时图标 accent 色
class _PlaylistQueueButton extends StatefulWidget {
  final VoidCallback onTap;

  const _PlaylistQueueButton({required this.onTap});

  @override
  State<_PlaylistQueueButton> createState() => _PlaylistQueueButtonState();
}

class _PlaylistQueueButtonState extends State<_PlaylistQueueButton> {
  bool _isHovering = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          duration: const Duration(milliseconds: 100),
          scale: _isPressed ? 0.95 : 1.0,
          child: Icon(
            Icons.queue_music_rounded,
            color: _isHovering ? AppColors.accent : AppColors.white,
            size: 28,
          ),
        ),
      ),
    );
  }
}

/// 顶部栏按钮
/// 简约风格：无背景，只保留图标，hover 时图标 accent 色
class _TopBarButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onPressed;

  const _TopBarButton({
    required this.icon,
    required this.onPressed,
  });

  @override
  State<_TopBarButton> createState() => _TopBarButtonState();
}

class _TopBarButtonState extends State<_TopBarButton> {
  bool _isHovering = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        onTap: widget.onPressed,
        child: AnimatedScale(
          duration: const Duration(milliseconds: 100),
          scale: _isPressed ? 0.95 : 1.0,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Icon(
              widget.icon,
              color: _isHovering ? AppColors.accent : AppColors.white,
              size: 24,
            ),
          ),
        ),
      ),
    );
  }
}

/// 加号按钮（带菜单）
/// 简约风格：无背景，只保留图标，hover 时图标 accent 色
class _AddButton extends StatefulWidget {
  final Song? currentSong;
  final VoidCallback onAddToPlaylist;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _AddButton({
    required this.currentSong,
    required this.onAddToPlaylist,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<_AddButton> createState() => _AddButtonState();
}

class _AddButtonState extends State<_AddButton> {
  bool _isHovering = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        child: AnimatedScale(
          duration: const Duration(milliseconds: 100),
          scale: _isPressed ? 0.95 : 1.0,
          child: PopupMenuButton<String>(
            icon: Icon(
              Icons.add_rounded,
              color: _isHovering ? AppColors.accent : AppColors.white,
              size: 24,
            ),
            padding: const EdgeInsets.all(16),
            color: AppColors.card,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            offset: const Offset(0, 48),
            onSelected: (value) {
              if (widget.currentSong == null) return;
              switch (value) {
                case 'add_to_playlist':
                  widget.onAddToPlaylist();
                  break;
                case 'edit':
                  widget.onEdit();
                  break;
                case 'delete':
                  widget.onDelete();
                  break;
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem<String>(
                value: 'add_to_playlist',
                child: Row(
                  children: [
                    Icon(Icons.playlist_add, color: AppColors.white, size: 20),
                    const SizedBox(width: 12),
                    Text('添加到歌单', style: TextStyle(color: AppColors.white)),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit_rounded, color: AppColors.white, size: 20),
                    const SizedBox(width: 12),
                    Text('编辑', style: TextStyle(color: AppColors.white)),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem<String>(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_rounded, color: const Color(0xFFEF4444), size: 20),
                    const SizedBox(width: 12),
                    Text('删除', style: TextStyle(color: const Color(0xFFEF4444))),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 收藏按钮组件
/// 白色线框（未收藏）→ 柔和红色实心（已收藏）
/// 双击触发收藏，带弹跳动画
class _FavoriteButton extends StatefulWidget {
  final bool isFavorite;
  final VoidCallback onTap;

  const _FavoriteButton({
    required this.isFavorite,
    required this.onTap,
  });

  @override
  State<_FavoriteButton> createState() => _FavoriteButtonState();
}

class _FavoriteButtonState extends State<_FavoriteButton>
    with SingleTickerProviderStateMixin {
  bool _isHovering = false;
  bool _isPressed = false;
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  // 柔和的红色（不那么刺眼）
  static const Color _softRed = Color(0xFFE57373);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.3), weight: 0.4),
      TweenSequenceItem(tween: Tween(begin: 1.3, end: 1.0), weight: 0.6),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
  }

  @override
  void didUpdateWidget(_FavoriteButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 当变为收藏状态时触发弹跳动画
    if (widget.isFavorite && !oldWidget.isFavorite) {
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 确定当前颜色
    Color iconColor;
    if (widget.isFavorite) {
      iconColor = _softRed;
    } else if (_isHovering) {
      iconColor = AppColors.accent;
    } else {
      iconColor = AppColors.white;
    }

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        onDoubleTap: widget.onTap, // 双击触发收藏
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Transform.scale(
              scale: _isPressed
                  ? 0.9
                  : (_scaleAnimation.value * (_isHovering ? 1.08 : 1.0)),
              child: Container(
                width: 44, // 最小触摸区域 44x44
                height: 44,
                alignment: Alignment.center,
                child: Icon(
                  widget.isFavorite
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  color: iconColor,
                  size: 26,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
