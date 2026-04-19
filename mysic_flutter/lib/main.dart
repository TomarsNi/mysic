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
            onPlaylistTap: (playlist) {
              final playlistId = playlist.id;
              if (playlistId != null) {
                playlistProvider.selectPlaylist(playlistId);
              }
            },
            onScanTap: _startScan,
            onSettingsTap: () => _showSettings(context),
            onAboutTap: () => _showAbout(context),
            onCreatePlaylistTap: () => _createPlaylist(context),
          ),
          body: _buildBody(context, playerProvider),
          floatingActionButton: playerProvider.hasCurrentSong
              ? _buildMiniPlayer(context, playerProvider)
              : null,
          floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        );
      },
    );
  }

  Widget _buildBody(BuildContext context, PlayerProvider playerProvider) {
    return CustomScrollView(
      slivers: [
        // AppBar
        SliverAppBar(
          backgroundColor: const Color(0xFF1A1A2E),
          elevation: 0,
          floating: true,
          leading: Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.menu_rounded),
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
          ),
          title: const Text(
            'Mysic',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.search_rounded),
              onPressed: () => _showSearch(context),
            ),
          ],
        ),

        // 内容区域
        SliverToBoxAdapter(
          child: _buildContent(context, playerProvider),
        ),
      ],
    );
  }

  Widget _buildContent(BuildContext context, PlayerProvider playerProvider) {
    final currentSong = playerProvider.currentSong;

    if (currentSong == null) {
      return _buildEmptyState(context);
    }

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 40),

          // 专辑封面
          GestureDetector(
            onTap: () => _openPlayerPage(context),
            child: Hero(
              tag: 'album_cover',
              child: Container(
                width: 280,
                height: 280,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                      blurRadius: 30,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFF6366F1),
                          Color(0xFF8B5CF6),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(
                      Icons.music_note_rounded,
                      size: 80,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 32),

          // 歌曲信息
          Text(
            currentSong.title,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),

          const SizedBox(height: 8),

          Text(
            currentSong.displayArtist,
            style: const TextStyle(
              fontSize: 16,
              color: Color(0xFF9CA3AF),
            ),
          ),

          const SizedBox(height: 48),

          // 快捷操作
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildQuickAction(
                icon: Icons.play_arrow_rounded,
                label: '播放',
                onTap: () => _openPlayerPage(context),
              ),
              _buildQuickAction(
                icon: Icons.lyrics_rounded,
                label: '歌词',
                onTap: () => _openLyricsPage(context),
              ),
              _buildQuickAction(
                icon: Icons.playlist_add_rounded,
                label: '添加到歌单',
                onTap: () => _showAddToPlaylist(context, currentSong),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height - 200,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 图标
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: const Color(0xFF16213E),
                borderRadius: BorderRadius.circular(30),
              ),
              child: const Icon(
                Icons.music_note_rounded,
                size: 60,
                color: Color(0xFF6366F1),
              ),
            ),

            const SizedBox(height: 32),

            const Text(
              '欢迎使用 Mysic',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),

            const SizedBox(height: 12),

            const Text(
              '扫描本地音乐开始播放',
              style: TextStyle(
                fontSize: 16,
                color: Color(0xFF9CA3AF),
              ),
            ),

            const SizedBox(height: 32),

            // 扫描按钮和进度
            if (_isScanning) ...[
              // 进度条
              SizedBox(
                width: 280,
                child: Column(
                  children: [
                    LinearProgressIndicator(
                      value: _scanProgress > 0 ? _scanProgress : null,
                      backgroundColor: const Color(0xFF16213E),
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '已发现 $_scanFound 首歌曲',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF9CA3AF),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _scanPath,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6B7280),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 16),
                    TextButton.icon(
                      onPressed: _cancelScan,
                      icon: const Icon(Icons.cancel_rounded, color: Colors.red),
                      label: const Text('取消扫描', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              ),
            ] else ...[
              ElevatedButton.icon(
                onPressed: _startScan,
                icon: const Icon(Icons.folder_open_rounded),
                label: const Text('扫描本地音乐'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildQuickAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: const Color(0xFF16213E),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              icon,
              size: 28,
              color: const Color(0xFF6366F1),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF9CA3AF),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniPlayer(BuildContext context, PlayerProvider playerProvider) {
    final currentSong = playerProvider.currentSong;

    return GestureDetector(
      onTap: () => _openPlayerPage(context),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF16213E),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // 封面
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.music_note_rounded,
                color: Colors.white,
              ),
            ),

            const SizedBox(width: 12),

            // 歌曲信息
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    currentSong?.title ?? '未知歌曲',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    currentSong?.displayArtist ?? '未知艺术家',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF9CA3AF),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            // 播放/暂停按钮
            IconButton(
              icon: Icon(
                playerProvider.isPlaying
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
                color: Colors.white,
              ),
              onPressed: () => playerProvider.togglePlayPause(),
            ),

            // 下一首按钮
            IconButton(
              icon: const Icon(
                Icons.skip_next_rounded,
                color: Colors.white,
              ),
              onPressed: () => playerProvider.next(),
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
