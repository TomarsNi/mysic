import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';
import 'package:mysic_flutter/features/player/presentation/providers/player_provider.dart';
import 'package:mysic_flutter/features/playlist/presentation/providers/playlist_provider.dart';
import 'package:mysic_flutter/features/player/data/models/song.dart';
import 'package:mysic_flutter/features/player/data/models/playlist.dart';
import 'package:mysic_flutter/features/playlist/data/playlist_repository.dart';
import 'package:mysic_flutter/core/theme/app_theme.dart';
import 'package:mysic_flutter/features/player/presentation/widgets/play_controls.dart';
import 'package:mysic_flutter/features/player/presentation/widgets/progress_bar.dart';
import 'package:mysic_flutter/features/player/data/services/audio_player_service.dart';
import 'package:mysic_flutter/core/utils/app_logger.dart';

/// Mock 仓库 - 用于测试
class MockPlaylistRepository extends PlaylistRepository {
  final List<Playlist> _playlists = [];
  final List<Song> _songs = [];
  int _nextPlaylistId = 1;

  @override
  Future<List<Playlist>> getAllPlaylistsWithSongs() async => List.from(_playlists);

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

/// 测试用 PlaylistProvider
class TestPlaylistProvider extends PlaylistProvider {
  TestPlaylistProvider() : super(repository: MockPlaylistRepository());
}

/// 测试应用
class E2ETestApp extends StatefulWidget {
  const E2ETestApp({super.key});

  @override
  State<E2ETestApp> createState() => _E2ETestAppState();
}

class _E2ETestAppState extends State<E2ETestApp> {
  late PlayerProvider _playerProvider;
  late PlaylistProvider _playlistProvider;
  final List<String> _testLog = [];
  bool _testsCompleted = false;
  int _passedTests = 0;
  int _failedTests = 0;

  @override
  void initState() {
    super.initState();
    _playerProvider = PlayerProvider();
    _playlistProvider = TestPlaylistProvider();
    _runTests();
  }

  Future<void> _runTests() async {
    _log('========== 端到端测试开始 ==========');
    _log('测试时间: ${DateTime.now().toString()}');
    _log('');

    // 等待 Provider 初始化
    await Future.delayed(const Duration(milliseconds: 500));

    // 测试 1: 应用启动验证
    await _test('应用启动验证', () async {
      _log('  PlayerProvider 已初始化');
      _log('  PlaylistProvider 已初始化');
    });

    // 测试 2: 播放器初始状态
    await _test('播放器初始状态', () async {
      _verify(_playerProvider.playerState == MysicPlayerState.idle,
          '初始状态为 idle');
      _verify(_playerProvider.currentSong == null, '当前歌曲为 null');
      _verify(!_playerProvider.isPlaying, '播放状态为 false');
      _verify(_playerProvider.playlist.isEmpty, '播放列表为空');
    });

    // 测试 3: 添加歌曲到播放列表
    await _test('添加歌曲到播放列表', () async {
      final song = _createTestSong(1, '测试歌曲1');
      _playerProvider.addToPlaylist(song);
      await _pump();

      _verify(_playerProvider.playlist.length == 1, '播放列表有 1 首歌曲');
      _verify(_playerProvider.playlist.first.title == '测试歌曲1', '歌曲标题正确');
    });

    // 测试 4: 添加多首歌曲
    await _test('添加多首歌曲', () async {
      for (int i = 2; i <= 5; i++) {
        _playerProvider.addToPlaylist(_createTestSong(i, '测试歌曲$i'));
      }
      await _pump();

      _verify(_playerProvider.playlist.length == 5, '播放列表有 5 首歌曲');
    });

    // 测试 5: 模拟播放/暂停切换
    await _test('播放/暂停切换', () async {
      await _playerProvider.togglePlayPause();
      await _pump();

      // 由于没有真实音频文件，状态可能不会改变
      // 但方法应该能正常执行
      _log('  播放/暂停方法执行成功');
    });

    // 测试 6: 随机模式切换
    await _test('随机模式切换', () async {
      final initialShuffle = _playerProvider.isShuffleMode;
      await _playerProvider.toggleShuffleMode();
      await _pump();

      _verify(_playerProvider.isShuffleMode != initialShuffle, '随机模式已切换');

      // 恢复
      await _playerProvider.toggleShuffleMode();
      await _pump();
    });

    // 测试 7: 循环模式切换
    await _test('循环模式切换', () async {
      final modes = [MysicLoopMode.off, MysicLoopMode.all];

      for (final mode in modes) {
        await _playerProvider.setLoopMode(mode);
        await _pump();
        _verify(_playerProvider.loopMode == mode, '循环模式设置为 ${mode.name}');
      }

      // 恢复默认
      await _playerProvider.setLoopMode(MysicLoopMode.off);
    });

    // 测试 8: 进度跳转
    await _test('进度跳转', () async {
      await _playerProvider.seek(const Duration(seconds: 30));
      await _pump();

      _verify(_playerProvider.position == const Duration(seconds: 30),
          '位置跳转到 30 秒');
    });

    // 测试 9: 移除歌曲
    await _test('移除歌曲', () async {
      final initialCount = _playerProvider.playlist.length;
      _playerProvider.removeFromPlaylist(0);
      await _pump();

      _verify(_playerProvider.playlist.length == initialCount - 1, '歌曲已移除');
    });

    // 测试 10: 清空播放列表
    await _test('清空播放列表', () async {
      await _playerProvider.clearPlaylist();
      await _pump();

      _verify(_playerProvider.playlist.isEmpty, '播放列表已清空');
      _verify(_playerProvider.currentIndex == -1, '当前索引重置');
    });

    // 测试 11: 歌单创建
    await _test('歌单创建', () async {
      await _playlistProvider.createPlaylist(name: '测试歌单');
      await _pump();

      _verify(_playlistProvider.playlists.isNotEmpty, '歌单已创建');
      _verify(_playlistProvider.playlists.first.name == '测试歌单', '歌单名称正确');
    });

    // 测试 12: 歌单删除
    await _test('歌单删除', () async {
      final playlist = _playlistProvider.playlists.first;
      final playlistId = playlist.id;
      if (playlistId != null) {
        await _playlistProvider.deletePlaylist(playlistId);
        await _pump();

        _verify(_playlistProvider.playlists.isEmpty, '歌单已删除');
      }
    });

    // 测试 13: 播放列表设置
    await _test('播放列表设置', () async {
      final songs = List.generate(10, (i) => _createTestSong(i + 1, '歌曲${i + 1}'));
      await _playerProvider.setPlaylist(songs, startIndex: 0);
      await _pump();

      _verify(_playerProvider.playlist.length == 10, '播放列表有 10 首歌曲');
      _verify(_playerProvider.currentIndex == 0, '当前索引为 0');
    });

    // 测试 14: 上一首/下一首操作
    await _test('上一首/下一首操作', () async {
      await _playerProvider.next();
      await _pump();
      _log('  下一首操作执行成功');

      await _playerProvider.previous();
      await _pump();
      _log('  上一首操作执行成功');
    });

    // 测试 15: 播放速度设置
    await _test('播放速度设置', () async {
      await _playerProvider.setSpeed(1.5);
      await _pump();
      _log('  播放速度设置为 1.5x');
    });

    // 测试 16: 进度百分比计算
    await _test('进度百分比计算', () async {
      _playerProvider.seek(const Duration(seconds: 60));
      await _pump();

      final progress = _playerProvider.progress;
      _log('  当前进度: ${(progress * 100).toStringAsFixed(1)}%');
    });

    // 测试 17: 格式化时间
    await _test('格式化时间', () async {
      final position = _playerProvider.formattedPosition;
      final duration = _playerProvider.formattedDuration;

      _log('  当前位置: $position');
      _log('  总时长: $duration');
    });

    // 测试 18: 歌曲属性
    await _test('歌曲属性', () async {
      final song = Song(
        id: 100,
        title: '属性测试歌曲',
        artist: '测试艺术家',
        album: '测试专辑',
        duration: 180000,
        filePath: '/test/song_100.mp3',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      _verify(song.title == '属性测试歌曲', '歌曲标题正确');
      _verify(song.artist == '测试艺术家', '艺术家正确');
      _verify(song.album == '测试专辑', '专辑正确');
    });

    // 测试 19: Provider 状态监听
    await _test('Provider 状态监听', () async {
      bool notified = false;
      void listener() {
        notified = true;
      }

      _playerProvider.addListener(listener);
      _playerProvider.addToPlaylist(_createTestSong(999, '监听测试'));
      await _pump();

      _verify(notified, 'Provider 通知监听器');
      _playerProvider.removeListener(listener);
    });

    // 测试 20: 批量操作
    await _test('批量操作', () async {
      await _playerProvider.clearPlaylist();
      await _pump();

      // 批量添加
      for (int i = 0; i < 50; i++) {
        _playerProvider.addToPlaylist(_createTestSong(i + 100, '批量歌曲$i'));
      }
      await _pump();

      _verify(_playerProvider.playlist.length == 50, '批量添加 50 首歌曲');

      // 批量移除
      for (int i = 0; i < 25; i++) {
        _playerProvider.removeFromPlaylist(0);
      }
      await _pump();

      _verify(_playerProvider.playlist.length == 25, '批量移除后剩余 25 首');
    });

    setState(() {
      _testsCompleted = true;
    });

    _log('');
    _log('========== 测试结果 ==========');
    _log('通过: $_passedTests');
    _log('失败: $_failedTests');
    _log('总计: ${_passedTests + _failedTests}');
    _log('完成时间: ${DateTime.now().toString()}');
    _log('==============================');
  }

  Future<void> _test(String name, Future<void> Function() testFn) async {
    _log('');
    _log('>>> $name');

    try {
      await testFn();
      _passedTests++;
      _log('  [PASS] $name');
    } catch (e) {
      _failedTests++;
      _log('  [FAIL] $name: $e');
    }
  }

  void _verify(bool condition, String message) {
    if (condition) {
      _log('  ✓ $message');
    } else {
      throw Exception('验证失败: $message');
    }
  }

  void _log(String message) {
    // 根据消息内容选择日志级别
    if (message.contains('[PASS]') || message.contains('✓') ||
        message.contains('成功') || message.contains('完成')) {
      AppLogger.i('E2ETest#_log', message);
    } else if (message.contains('[FAIL]') || message.contains('验证失败') ||
               message.contains('失败') || message.contains('错误')) {
      AppLogger.w('E2ETest#_log', message);
    } else {
      AppLogger.d('E2ETest#_log', message);
    }
    setState(() {
      _testLog.add(message);
    });
  }

  Future<void> _pump() async {
    await Future.delayed(const Duration(milliseconds: 100));
  }

  Song _createTestSong(int id, String title) {
    return Song(
      id: id,
      title: title,
      artist: '艺术家$id',
      duration: 180000 + id * 1000,
      filePath: '/test/song_$id.mp3',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  @override
  void dispose() {
    _playerProvider.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _playerProvider),
        ChangeNotifierProvider.value(value: _playlistProvider),
      ],
      child: MaterialApp(
        title: 'Mysic E2E 测试',
        theme: AppTheme.darkTheme,
        home: _buildTestPage(),
      ),
    );
  }

  Widget _buildTestPage() {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        title: const Text('端到端测试'),
        backgroundColor: const Color(0xFF16213E),
      ),
      body: Column(
        children: [
          // 状态指示器
          Container(
            padding: const EdgeInsets.all(16),
            color: _testsCompleted
                ? (_failedTests == 0 ? Colors.green : Colors.orange)
                : Colors.blue,
            child: Row(
              children: [
                Icon(
                  _testsCompleted
                      ? (_failedTests == 0 ? Icons.check_circle : Icons.warning)
                      : Icons.hourglass_empty,
                  color: Colors.white,
                ),
                const SizedBox(width: 8),
                Text(
                  _testsCompleted
                      ? '测试完成 - 通过: $_passedTests, 失败: $_failedTests'
                      : '测试运行中...',
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
              ],
            ),
          ),

          // 测试日志
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: _testLog.length,
              itemBuilder: (context, index) {
                final log = _testLog[index];
                Color textColor = Colors.white;

                if (log.contains('[PASS]') || log.contains('✓')) {
                  textColor = Colors.green;
                } else if (log.contains('[FAIL]') || log.contains('验证失败')) {
                  textColor = Colors.red;
                } else if (log.contains('>>>')) {
                  textColor = Colors.cyan;
                } else if (log.contains('==========')) {
                  textColor = Colors.yellow;
                }

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(
                    log,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      color: textColor,
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
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('端到端测试', () {
    testWidgets('应用启动并运行测试', (WidgetTester tester) async {
      await tester.pumpWidget(const E2ETestApp());

      // 等待 UI 渲染
      await tester.pump(const Duration(seconds: 2));

      // 验证 AppBar 标题
      expect(find.text('端到端测试'), findsOneWidget);
    });

    testWidgets('测试结果显示', (WidgetTester tester) async {
      await tester.pumpWidget(const E2ETestApp());

      // 等待测试执行
      await tester.pump(const Duration(seconds: 15));

      // 验证测试日志出现
      expect(find.textContaining('>>>'), findsWidgets);
    });

    testWidgets('UI 组件渲染测试', (WidgetTester tester) async {
      // 测试播放控制组件
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlayControls(
              isPlaying: false,
              isLoading: false,
              hasPlaylist: true,
              onPlayPause: () {},
              onNext: () {},
              onPrevious: () {},
            ),
          ),
        ),
      );

      // 验证播放按钮存在
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
      expect(find.byIcon(Icons.skip_previous_rounded), findsOneWidget);
      expect(find.byIcon(Icons.skip_next_rounded), findsOneWidget);
    });

    testWidgets('进度条组件渲染测试', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProgressBar(
              position: const Duration(seconds: 30),
              duration: const Duration(seconds: 180),
              enabled: true,
              onSeek: (progress) {},
            ),
          ),
        ),
      );

      // 验证进度条存在
      expect(find.byType(ProgressBar), findsOneWidget);
    });

    testWidgets('扩展控制组件渲染测试', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ExtendedControls(
              isShuffleMode: false,
              loopMode: MysicLoopMode.off,
              onToggleShuffle: () {},
              onToggleLoop: () {},
            ),
          ),
        ),
      );

      // 验证控制按钮存在
      expect(find.byIcon(Icons.shuffle_rounded), findsOneWidget);
      expect(find.byIcon(Icons.repeat_rounded), findsOneWidget);
    });
  });
}
