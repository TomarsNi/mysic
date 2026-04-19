import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'dart:io';

import 'core/theme/app_theme.dart';
import 'core/database/database_helper.dart';
import 'features/player/presentation/providers/player_provider.dart';
import 'features/playlist/presentation/providers/playlist_provider.dart';
import 'features/player/presentation/pages/player_page.dart' show PlayerPage;
import 'features/lyrics/presentation/pages/lyrics_page.dart' show LyricsPage;
import 'features/settings/presentation/pages/about_page.dart';
import 'shared/widgets/app_drawer.dart';
import 'shared/utils/music_scanner.dart';
import 'features/playlist/data/playlist_repository.dart';
import 'features/player/data/models/song.dart';
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
  String _scanPath = '';
  int _scanFound = 0;
  double _scanProgress = 0.0;
  MusicScanner? _currentScanner;

  @override
  void initState() {
    super.initState();
    _fabAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    // 加载歌单 - 延迟到 build 完成后执行
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadPlaylists();
    });
  }

  Future<void> _loadPlaylists() async {
    final playlistProvider = context.read<PlaylistProvider>();
    await playlistProvider.refresh();
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

              // 1. 选择歌单（加载歌曲）
              await playlistProvider.selectPlaylist(playlistId);

              // 2. 获取歌曲列表
              final songs = playlistProvider.selectedPlaylistSongs;

              if (songs.isNotEmpty) {
                // 3. 设置播放列表并播放
                await playerProvider.setPlaylist(songs);
                await playerProvider.play();
              }

              // 4. 抽屉会自动关闭（在 AppDrawer 中处理）
            },
            onScanTap: _startScan,
            onSettingsTap: () => _showSettings(context),
            onAboutTap: () => _showAbout(context),
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

            const SizedBox(height: 16),

            // 扩展控制
            ExtendedControls(
              isShuffleMode: playerProvider.isShuffleMode,
              loopMode: playerProvider.loopMode,
              onToggleShuffle: () => playerProvider.toggleShuffleMode(),
              onToggleLoop: () => playerProvider.toggleLoopMode(),
            ),

            const SizedBox(height: 24),
          ],
        ),
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
    return GestureDetector(
      onTap: () => _openLyricsPage(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF16213E),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            const Text(
              '为你弹奏肖邦的夜曲',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF9CA3AF),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            const Text(
              '纪念我死去的爱情',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Color(0xFF10B981),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // 操作方法
  Future<void> _startScan() async {
    setState(() {
      _isScanning = true;
      _scanPath = '准备扫描...';
      _scanFound = 0;
      _scanProgress = 0.0;
    });

    try {
      final scanner = MusicScanner();
      _currentScanner = scanner;

      // 监听进度
      scanner.progressStream.listen((progress) {
        if (mounted) {
          setState(() {
            _scanPath = progress.currentPath;
            _scanFound = progress.songsFound;
            _scanProgress = progress.progress;
          });
        }
      });

      final result = await scanner.scanMusic();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result.isSuccess
                  ? '扫描完成: 发现 ${result.totalFound} 首歌曲，新增 ${result.newAdded} 首'
                  : '扫描失败: ${result.errorMessage}',
            ),
            backgroundColor: result.isSuccess ? const Color(0xFF6366F1) : Colors.red,
          ),
        );

        // 重新加载歌单
        await _loadPlaylists();
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

  void _openPlayerPage(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const PlayerPage(),
      ),
    );
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

  void _createPlaylist(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const CreatePlaylistDialog(),
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
