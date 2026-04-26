import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite/sqflite.dart' show ConflictAlgorithm;
import 'dart:io';

import 'core/theme/app_theme.dart';
import 'core/database/database_helper.dart';
import 'features/player/presentation/providers/player_provider.dart';
import 'features/playlist/presentation/providers/playlist_provider.dart';
import 'features/lyrics/presentation/pages/lyrics_page.dart' show LyricsPage;
import 'features/settings/presentation/pages/about_page.dart';
import 'features/settings/presentation/pages/api_settings_page.dart';
import 'features/settings/presentation/providers/api_config_provider.dart';
import 'features/ai_skills/presentation/providers/ai_skills_provider.dart';
import 'features/ai_skills/presentation/widgets/magic_wand_button.dart';
import 'features/ai_skills/presentation/widgets/skill_selection_sheet.dart';
import 'features/ai_skills/presentation/widgets/result_preview_sheet.dart';
import 'features/ai_skills/core/ai_skill.dart';
import 'features/ai_skills/core/skill_result.dart';
import 'shared/widgets/app_drawer.dart';
import 'shared/utils/music_scanner.dart';
import 'features/playlist/data/playlist_repository.dart';
import 'features/player/data/models/song.dart';
import 'features/player/data/models/playlist.dart';
import 'features/player/presentation/widgets/album_cover.dart';
import 'features/player/presentation/widgets/play_controls.dart';
import 'features/player/presentation/widgets/progress_bar.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化 Windows 平台 SQLite FFI
  if (Platform.isWindows) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  // 初始化数据库
  await DatabaseHelper().database;

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
        ChangeNotifierProvider(create: (_) => PlaylistProvider()),
        ChangeNotifierProvider(create: (_) => ApiConfigProvider()..load()),
        ChangeNotifierProvider(create: (_) => AiSkillsProvider()),
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

  @override
  void initState() {
    super.initState();
    _fabAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    // 加载歌单并恢复播放 - 延迟到 build 完成后执行
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadPlaylists();
      // 恢复上次播放的歌单
      await _restoreLastPlaylist();
    });
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

    // 4. 播放歌单（与用户点击歌单逻辑一致）
    await playerProvider.setPlaylist(songs, autoPlay: true);
  }

  @override
  void dispose() {
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
                await playerProvider.setPlaylist(songs, autoPlay: true);
              }

              // 5. 抽屉会自动关闭（在 AppDrawer 中处理）
            },
            onScanTap: _startScan,
            onSettingsTap: () => _showSettings(context),
            onAboutTap: () => _showAbout(context),
            onApiSettingsTap: () => _showApiSettings(context),
            onCreatePlaylistTap: () => _createPlaylist(context),
          ),
          body: _buildBody(context, playerProvider),
          floatingActionButton: null,
        );
      },
    );
  }

  Widget _buildBody(BuildContext context, PlayerProvider playerProvider) {
    final currentSong = playerProvider.currentSong;
    final hasSong = currentSong != null;

    return SafeArea(
      child: Column(
        children: [
          // 顶部栏
          _buildTopBar(context),

          // 主内容区
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  const SizedBox(height: 20),

                  // 专辑封面
                  Expanded(
                    flex: 3,
                    child: Center(
                      child: GestureDetector(
                        onTap: hasSong ? null : _startScan,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            AlbumCover(
                              song: currentSong,
                              size: 260,
                              isPlaying: playerProvider.isPlaying,
                            ),
                            // 首次使用引导
                            if (!hasSong && !_isScanning)
                              Positioned(
                                bottom: -40,
                                child: ElevatedButton.icon(
                                  onPressed: _startScan,
                                  icon: const Icon(Icons.folder_open_rounded),
                                  label: const Text('扫描本地音乐'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF10B981),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 24,
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(24),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // 歌曲信息
                  _buildSongInfo(currentSong),

                  const SizedBox(height: 16),

                  // 歌词预览
                  if (hasSong) _buildLyricsPreview(context, playerProvider),

                  const SizedBox(height: 24),

                  // 进度条
                  ProgressBar(
                    position: playerProvider.position,
                    duration: playerProvider.duration,
                    enabled: playerProvider.hasCurrentSong,
                    onSeek: (progress) => playerProvider.seekToProgress(progress),
                  ),

                  const SizedBox(height: 24),

                  // 播放控制
                  PlayControls(
                    isPlaying: playerProvider.isPlaying,
                    isLoading: playerProvider.isLoading,
                    hasPlaylist: playerProvider.hasPlaylist,
                    onPlayPause: () => playerProvider.togglePlayPause(),
                    onNext: () => playerProvider.next(),
                    onPrevious: () => playerProvider.previous(),
                  ),

                  const SizedBox(height: 24),
                ],
              ),
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
        final hasEnabledApi = apiConfigProvider.enabledConfig != null;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Row(
            children: [
              // 抽屉按钮 - 设计稿：p-3 rounded-xl bg-card
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF27272A), // bg-card
                  borderRadius: BorderRadius.circular(12), // rounded-xl
                ),
                child: IconButton(
                  icon: const Icon(Icons.menu_rounded, color: Colors.white),
                  onPressed: () => Scaffold.of(context).openDrawer(),
                  padding: const EdgeInsets.all(12), // p-3
                ),
              ),

              const Expanded(
                child: Column(
                  children: [
                    // 上方 muted xs 文字
                    Text(
                      '正在播放',
                      style: TextStyle(
                        fontSize: 12, // xs = 12px
                        color: Color(0xFF71717A), // muted
                      ),
                    ),
                    SizedBox(height: 2),
                    // 下方 font-medium sm (14px)
                    Text(
                      '全部歌曲',
                      style: TextStyle(
                        fontSize: 14, // sm = 14px
                        fontWeight: FontWeight.w500, // font-medium
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),

              // 魔法棒按钮（AI 功能）
              if (hasEnabledApi) ...[
                MagicWandButton(
                  visible: currentSong != null,
                  onTap: () => _showSkillSelection(context, currentSong!),
                ),
                const SizedBox(width: 12),
              ],

              // 弹出菜单按钮 - 设计稿：p-3 rounded-xl bg-card
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF27272A), // bg-card
                  borderRadius: BorderRadius.circular(12), // rounded-xl
                ),
                child: PopupMenuButton<String>(
                  icon: const Icon(Icons.add_rounded, color: Colors.white),
                  color: const Color(0xFF27272A),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  offset: const Offset(0, 48),
                  onSelected: (value) {
                    if (currentSong == null) return;
                    _handleMiniPlayerMenuAction(context, currentSong, value);
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem<String>(
                      value: 'add_to_playlist',
                      child: Row(
                        children: [
                          Icon(Icons.playlist_add, color: Colors.white, size: 20),
                          const SizedBox(width: 12),
                          const Text('添加到歌单', style: TextStyle(color: Colors.white)),
                        ],
                      ),
                    ),
                    PopupMenuItem<String>(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_rounded, color: Colors.white, size: 20),
                          const SizedBox(width: 12),
                          const Text('编辑', style: TextStyle(color: Colors.white)),
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
                          const Text('删除', style: TextStyle(color: Color(0xFFEF4444))),
                        ],
                      ),
                    ),
                  ],
                ),
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
    return Column(
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
          textAlign: TextAlign.center,
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
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildLyricsPreview(BuildContext context, PlayerProvider provider) {
    // 设计稿规范：
    // - 两行歌词：当前行 lg font-medium white，下一行 muted
    // - hover 时背景 white/5，圆角 rounded-xl
    // - 点击可进入歌词页面
    final currentLyric = provider.currentLyricLine?.text;
    final nextLyric = provider.nextLyricLine?.text;

    // 如果没有歌词，显示占位文本
    final displayCurrentLyric = currentLyric ?? '暂无歌词';
    final displayNextLyric = nextLyric ?? '';

    return GestureDetector(
      onTap: currentLyric != null ? () => _openLyricsPage(context) : null,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF27272A), // bg-card
            borderRadius: BorderRadius.circular(12), // rounded-xl
          ),
          child: Column(
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
                textAlign: TextAlign.center,
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
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // 操作方法
  Future<void> _startScan() async {
    print('========== 开始扫描 ==========');
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
      print('扫描结果: success=${result.isSuccess}, totalFound=${result.totalFound}, newAdded=${result.newAdded}, error=${result.errorMessage}');

      if (mounted && result.isSuccess) {
        // 先刷新 Provider 数据，确保歌曲列表是最新的
        final playlistProvider = context.read<PlaylistProvider>();

        // 直接从数据库验证数据是否保存成功
        final db = await DatabaseHelper().database;
        final dbCount = await db.rawQuery('SELECT COUNT(*) as count FROM ${DatabaseHelper.tableSongs}');
        print('数据库中实际歌曲数: ${dbCount.first['count']}');

        await playlistProvider.refresh();
        print('刷新 Provider 完成，allSongs 数量: ${playlistProvider.allSongs.length}');

        // 只要有歌曲就检查/创建"本地音乐"歌单
        if (playlistProvider.allSongs.isNotEmpty) {
          await _ensureLocalMusicPlaylist(context, result.newAdded);
        } else {
          print('没有歌曲，跳过创建歌单');
        }

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

  /// 确保存在"本地音乐"歌单，并将所有歌曲添加进去
  Future<void> _ensureLocalMusicPlaylist(BuildContext context, int newSongCount) async {
    final playlistProvider = context.read<PlaylistProvider>();
    const localMusicPlaylistName = '本地音乐';

    // 查找是否已存在"本地音乐"歌单
    Playlist? localPlaylist;
    try {
      localPlaylist = playlistProvider.playlists.firstWhere(
        (p) => p.name == localMusicPlaylistName,
      );
      print('找到已存在的本地音乐歌单: ${localPlaylist.id}');
    } catch (_) {
      // 不存在，需要创建
      print('本地音乐歌单不存在，准备创建');
    }

    if (localPlaylist == null) {
      // 创建"本地音乐"歌单
      localPlaylist = await playlistProvider.createPlaylist(
        name: localMusicPlaylistName,
        description: '扫描本地音乐自动创建',
      );
      print('创建本地音乐歌单结果: id=${localPlaylist?.id}, name=${localPlaylist?.name}');
    }

    final playlistId = localPlaylist?.id;
    if (playlistId == null) {
      print('歌单 ID 为空，无法添加歌曲');
      return;
    }

    // 获取所有歌曲并添加到歌单
    final allSongs = playlistProvider.allSongs;
    print('准备添加 ${allSongs.length} 首歌曲到歌单 $playlistId');

    if (allSongs.isEmpty) {
      print('allSongs 为空，尝试直接从数据库获取');
      // 直接从数据库获取
      final repository = PlaylistRepository();
      final songs = await repository.getAllSongs();
      print('从数据库获取到 ${songs.length} 首歌曲');
      if (songs.isNotEmpty) {
        final count = await playlistProvider.addSongsToPlaylist(playlistId, songs);
        print('成功添加 $count 首歌曲到歌单');
      }
    } else {
      final count = await playlistProvider.addSongsToPlaylist(playlistId, allSongs);
      print('成功添加 $count 首歌曲到歌单');
    }
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

  void _createPlaylist(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const CreatePlaylistDialog(),
    );
  }

  void _handleMiniPlayerMenuAction(BuildContext context, Song song, String value) {
    switch (value) {
      case 'add_to_playlist':
        _showAddToPlaylist(context, song);
        break;
      case 'edit':
        _showEditSongDialog(context, song);
        break;
      case 'delete':
        _showDeleteConfirmSheet(context, song);
        break;
    }
  }

  void _showDeleteConfirmSheet(BuildContext context, Song song) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _DeleteConfirmSheet(
        song: song,
        onConfirm: () async {
          final playerProvider = context.read<PlayerProvider>();
          final playlistProvider = context.read<PlaylistProvider>();

          // 删除歌曲
          await playerProvider.deleteCurrentSong();

          // 刷新歌单数据
          await playlistProvider.refresh();

          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('歌曲已删除'),
                backgroundColor: Color(0xFF10B981),
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

          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

/// 创建歌单对话框
class CreatePlaylistDialog extends StatefulWidget {
  const CreatePlaylistDialog({super.key});

  @override
  State<CreatePlaylistDialog> createState() => _CreatePlaylistDialogState();
}

class _CreatePlaylistDialogState extends State<CreatePlaylistDialog> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF16213E),
      title: const Text('创建歌单', style: TextStyle(color: Colors.white)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: '歌单名称',
              labelStyle: TextStyle(color: Color(0xFF9CA3AF)),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Color(0xFF9CA3AF)),
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _descriptionController,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: '描述（可选）',
              labelStyle: TextStyle(color: Color(0xFF9CA3AF)),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Color(0xFF9CA3AF)),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消', style: TextStyle(color: Color(0xFF9CA3AF))),
        ),
        ElevatedButton(
          onPressed: () async {
            if (_nameController.text.isNotEmpty) {
              final playlistProvider = context.read<PlaylistProvider>();
              await playlistProvider.createPlaylist(
                name: _nameController.text,
                description: _descriptionController.text.isNotEmpty
                    ? _descriptionController.text
                    : null,
              );
              if (mounted) {
                Navigator.pop(context);
              }
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF6366F1),
          ),
          child: const Text('创建'),
        ),
      ],
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

/// 删除确认 BottomSheet
class _DeleteConfirmSheet extends StatelessWidget {
  final Song song;
  final VoidCallback onConfirm;

  const _DeleteConfirmSheet({
    required this.song,
    required this.onConfirm,
  });

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
            song.title,
            style: const TextStyle(
              color: Color(0xFF71717A),
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),

          // 警告提示
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFEF4444).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              '删除后歌曲将从所有歌单移除，且不会在下次扫描时重新添加',
              style: TextStyle(
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
                    onConfirm();
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
