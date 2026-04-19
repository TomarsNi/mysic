import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';
import 'package:mysic_flutter/features/player/presentation/providers/player_provider.dart';
import 'package:mysic_flutter/features/playlist/presentation/providers/playlist_provider.dart';
import 'package:mysic_flutter/features/player/data/models/song.dart';
import 'package:mysic_flutter/features/player/data/models/playlist.dart';
import 'package:mysic_flutter/features/playlist/data/playlist_repository.dart';

/// Mock 仓库 - 用于测试，避免真实数据库操作
class MockPlaylistRepository extends PlaylistRepository {
  final List<Playlist> _playlists = [];
  final List<Song> _songs = [];
  int _nextPlaylistId = 1;

  @override  Future<List<Playlist>> getAllPlaylistsWithSongs() async => List.from(_playlists);

  @override
  Future<Playlist> createPlaylist({
    required String name,
    String? description,
    String? coverPath,
  }) async {
    final playlist = Playlist(
      id: _nextPlaylistId++,
      name: name,
      description: description,
      coverPath: coverPath,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    _playlists.add(playlist);
    return playlist;
  }

  @override
  Future<bool> deletePlaylist(int playlistId) async {
    final index = _playlists.indexWhere((p) => p.id == playlistId);
    if (index != -1) {
      _playlists.removeAt(index);
      return true;
    }
    return false;
  }

  @override
  Future<List<Song>> getAllSongs() async => List.from(_songs);

  @override
  Future<List<Song>> getPlayHistory({int limit = 50}) async => [];
}

/// 测试用 PlaylistProvider - 使用 Mock 仓库
class TestPlaylistProvider extends PlaylistProvider {
  TestPlaylistProvider() : super(repository: MockPlaylistRepository());
}

/// 应用入口 - 用于集成测试
class TestApp extends StatelessWidget {
  const TestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => PlayerProvider()),
        ChangeNotifierProvider<PlaylistProvider>(create: (_) => TestPlaylistProvider()),
      ],
      child: MaterialApp(
        title: 'Mysic 测试',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
          useMaterial3: true,
        ),
        home: const TestHomePage(),
      ),
    );
  }
}

/// 测试主页
class TestHomePage extends StatefulWidget {
  const TestHomePage({super.key});

  @override
  State<TestHomePage> createState() => _TestHomePageState();
}

class _TestHomePageState extends State<TestHomePage> {
  final List<String> _testResults = [];
  bool _isRunning = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('集成测试'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Column(
        children: [
          // 测试控制按钮
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: _isRunning ? null : _runAllTests,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('运行全部测试'),
                ),
                ElevatedButton.icon(
                  onPressed: _clearResults,
                  icon: const Icon(Icons.clear),
                  label: const Text('清空结果'),
                ),
              ],
            ),
          ),

          // 测试结果列表
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _testResults.length,
              itemBuilder: (context, index) {
                final result = _testResults[index];
                final isSuccess = result.startsWith('✓');
                final isError = result.startsWith('✗');

                return Card(
                  color: isError
                      ? Colors.red.shade50
                      : isSuccess
                          ? Colors.green.shade50
                          : null,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      result,
                      style: TextStyle(
                        color: isError
                            ? Colors.red
                            : isSuccess
                                ? Colors.green
                                : null,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _runAllTests() async {
    setState(() {
      _isRunning = true;
      _testResults.add('开始运行测试...');
    });

    final playerProvider = context.read<PlayerProvider>();
    final playlistProvider = context.read<PlaylistProvider>();

    // 测试 1: 播放器初始状态
    await _runTest('播放器初始状态', () async {
      if (playerProvider.playerState.name != 'idle') {
        throw Exception('初始状态应为 idle，实际为 ${playerProvider.playerState}');
      }
      if (playerProvider.currentSong != null) {
        throw Exception('初始歌曲应为 null');
      }
      if (playerProvider.isPlaying) {
        throw Exception('初始播放状态应为 false');
      }
    });

    // 测试 2: 添加歌曲到播放列表
    await _runTest('添加歌曲到播放列表', () async {
      final song = Song(
        id: 1,
        title: '测试歌曲1',
        artist: '测试艺术家',
        duration: 180000,
        filePath: '/test/song1.mp3',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      playerProvider.addToPlaylist(song);

      if (playerProvider.playlist.isEmpty) {
        throw Exception('播放列表不应为空');
      }
      if (playerProvider.playlist.first.title != '测试歌曲1') {
        throw Exception('歌曲标题不匹配');
      }
    });

    // 测试 3: 播放列表数量
    await _runTest('播放列表数量正确', () async {
      if (playerProvider.playlist.length != 1) {
        throw Exception('播放列表应有 1 首歌曲，实际有 ${playerProvider.playlist.length}');
      }
    });

    // 测试 4: 添加更多歌曲
    await _runTest('添加多首歌曲', () async {
      for (int i = 2; i <= 5; i++) {
        final song = Song(
          id: i,
          title: '测试歌曲$i',
          artist: '艺术家$i',
          duration: 180000 + i * 10000,
          filePath: '/test/song$i.mp3',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        playerProvider.addToPlaylist(song);
      }

      if (playerProvider.playlist.length != 5) {
        throw Exception('播放列表应有 5 首歌曲，实际有 ${playerProvider.playlist.length}');
      }
    });

    // 测试 5: 随机模式切换
    await _runTest('随机模式切换', () async {
      final initialState = playerProvider.isShuffleMode;
      await playerProvider.toggleShuffleMode();

      if (playerProvider.isShuffleMode == initialState) {
        throw Exception('随机模式应已切换');
      }

      await playerProvider.toggleShuffleMode();
      if (playerProvider.isShuffleMode != initialState) {
        throw Exception('随机模式应恢复初始状态');
      }
    });

    // 测试 6: 循环模式切换
    await _runTest('循环模式切换', () async {
      final modes = ['off', 'one', 'all', 'off'];

      for (int i = 0; i < modes.length - 1; i++) {
        await playerProvider.toggleLoopMode();
        if (playerProvider.loopMode.name != modes[i + 1]) {
          throw Exception('循环模式应为 ${modes[i + 1]}，实际为 ${playerProvider.loopMode.name}');
        }
      }
    });

    // 测试 7: 进度跳转
    await _runTest('进度跳转', () async {
      await playerProvider.seek(const Duration(seconds: 30));
      if (playerProvider.position != const Duration(seconds: 30)) {
        throw Exception('位置应为 30 秒，实际为 ${playerProvider.position}');
      }
    });

    // 测试 8: 移除歌曲
    await _runTest('移除歌曲', () async {
      final initialCount = playerProvider.playlist.length;
      playerProvider.removeFromPlaylist(0);

      if (playerProvider.playlist.length != initialCount - 1) {
        throw Exception('歌曲数量应减少 1');
      }
    });

    // 测试 9: 清空播放列表
    await _runTest('清空播放列表', () async {
      await playerProvider.clearPlaylist();

      if (playerProvider.playlist.isNotEmpty) {
        throw Exception('播放列表应为空');
      }
      if (playerProvider.currentIndex != -1) {
        throw Exception('当前索引应为 -1');
      }
    });

    // 测试 10: 歌单创建
    await _runTest('歌单创建', () async {
      await playlistProvider.createPlaylist(name: '测试歌单');

      final playlists = playlistProvider.playlists;
      if (playlists.isEmpty) {
        throw Exception('应创建歌单');
      }
      if (playlists.first.name != '测试歌单') {
        throw Exception('歌单名称不匹配');
      }
    });

    // 测试 11: 歌单删除
    await _runTest('歌单删除', () async {
      final playlist = playlistProvider.playlists.first;
      final playlistId = playlist.id;
      if (playlistId == null) {
        throw Exception('歌单 ID 不应为 null');
      }
      await playlistProvider.deletePlaylist(playlistId);

      if (playlistProvider.playlists.isNotEmpty) {
        throw Exception('歌单应已删除');
      }
    });

    setState(() {
      _testResults.add('');
      _testResults.add('======== 测试完成 ========');
      _isRunning = false;
    });
  }

  Future<void> _runTest(String name, Future<void> Function() test) async {
    try {
      await test();
      setState(() {
        _testResults.add('✓ $name');
      });
    } catch (e) {
      setState(() {
        _testResults.add('✗ $name: $e');
      });
    }

    // 添加小延迟以便观察
    await Future.delayed(const Duration(milliseconds: 300));
  }

  void _clearResults() {
    setState(() {
      _testResults.clear();
    });
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('集成测试', () {
    testWidgets('应用启动测试', (WidgetTester tester) async {
      await tester.pumpWidget(const TestApp());

      // 验证应用标题
      expect(find.text('集成测试'), findsOneWidget);

      // 验证测试按钮存在
      expect(find.text('运行全部测试'), findsOneWidget);
      expect(find.text('清空结果'), findsOneWidget);
    });

    testWidgets('点击运行测试按钮', (WidgetTester tester) async {
      await tester.pumpWidget(const TestApp());

      // 点击运行测试按钮
      await tester.tap(find.text('运行全部测试'));
      await tester.pump();

      // 验证开始运行测试的消息出现
      expect(find.text('开始运行测试...'), findsOneWidget);
    });

    testWidgets('点击清空结果按钮', (WidgetTester tester) async {
      await tester.pumpWidget(const TestApp());

      // 先运行测试
      await tester.tap(find.text('运行全部测试'));
      await tester.pump();

      // 然后清空
      await tester.tap(find.text('清空结果'));
      await tester.pump();

      // 验证结果被清空
      expect(find.text('开始运行测试...'), findsNothing);
    });
  });
}
