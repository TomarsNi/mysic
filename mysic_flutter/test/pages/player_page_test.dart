import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mysic_flutter/features/player/presentation/pages/player_page.dart';
import 'package:mysic_flutter/features/player/presentation/providers/player_provider.dart';
import 'package:mysic_flutter/features/player/data/services/audio_player_service.dart';
import 'package:mysic_flutter/features/player/data/models/song.dart';
import 'package:mysic_flutter/features/lyrics/data/services/lyrics_parser.dart';
import 'package:mysic_flutter/features/lyrics/presentation/pages/lyrics_page.dart' hide LyricLine;

// Mock PlayerProvider for testing
class MockPlayerProvider extends ChangeNotifier implements PlayerProvider {
  @override
  MysicPlayerState get playerState => MysicPlayerState.idle;

  @override
  Song? get currentSong => null;

  @override
  Duration get position => Duration.zero;

  @override
  Duration? get duration => null;

  @override
  List<Song> get playlist => [];

  @override
  int get currentIndex => -1;

  @override
  bool get isShuffleMode => false;

  @override
  MysicLoopMode get loopMode => MysicLoopMode.off;

  @override
  bool get isPlaying => false;

  @override
  bool get isPaused => false;

  @override
  bool get isLoading => false;

  @override
  bool get hasCurrentSong => false;

  @override
  bool get hasPlaylist => false;

  @override
  double get progress => 0.0;

  @override
  String get formattedPosition => '0:00';

  @override
  String get formattedDuration => '--:--';

  @override
  bool get isScanning => false;

  @override
  double? get scanProgress => null;

  @override
  LyricsResult get currentLyrics => LyricsResult.empty;

  @override
  bool get hasLyrics => false;

  @override
  LyricLine? get currentLyricLine => null;

  @override
  LyricLine? get nextLyricLine => null;

  @override
  Future<void> playSong(Song song) async {}

  @override
  Future<void> setPlaylist(List<Song> songs, {int startIndex = 0}) async {}

  @override
  Future<void> play() async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> togglePlayPause() async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> next() async {}

  @override
  Future<void> previous() async {}

  @override
  Future<void> seek(Duration position) async {}

  @override
  Future<void> seekToProgress(double progress) async {}

  @override
  Future<void> seekToIndex(int index) async {}

  @override
  Future<void> setSpeed(double speed) async {}

  @override
  Future<void> toggleShuffleMode() async {}

  @override
  Future<void> setLoopMode(MysicLoopMode mode) async {}

  @override
  Future<void> toggleLoopMode() async {}

  @override
  void addToPlaylist(Song song) {}

  @override
  void removeFromPlaylist(int index) {}

  @override
  Future<void> clearPlaylist() async {}

  @override
  void startScan() {}

  @override
  void updateScanProgress(double progress) {}

  @override
  void finishScan() {}
}

void main() {
  group('PlayerPage', () {
    testWidgets('renders without current song', (WidgetTester tester) async {
      await tester.pumpWidget(
        ChangeNotifierProvider<PlayerProvider>(
          create: (_) => MockPlayerProvider(),
          child: const MaterialApp(
            home: PlayerPage(),
          ),
        ),
      );

      // 应该显示默认文本
      expect(find.text('未选择歌曲'), findsOneWidget);
      expect(find.text('请选择要播放的歌曲'), findsOneWidget);
    });

    testWidgets('shows app bar with title', (WidgetTester tester) async {
      await tester.pumpWidget(
        ChangeNotifierProvider<PlayerProvider>(
          create: (_) => MockPlayerProvider(),
          child: const MaterialApp(
            home: PlayerPage(),
          ),
        ),
      );

      // 应该显示标题
      expect(find.text('正在播放'), findsOneWidget);
    });

    testWidgets('shows play controls', (WidgetTester tester) async {
      await tester.pumpWidget(
        ChangeNotifierProvider<PlayerProvider>(
          create: (_) => MockPlayerProvider(),
          child: const MaterialApp(
            home: PlayerPage(),
          ),
        ),
      );

      // 应该显示播放控制按钮
      expect(find.byIcon(Icons.skip_previous_rounded), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
      expect(find.byIcon(Icons.skip_next_rounded), findsOneWidget);
    });

    testWidgets('shows extended controls', (WidgetTester tester) async {
      await tester.pumpWidget(
        ChangeNotifierProvider<PlayerProvider>(
          create: (_) => MockPlayerProvider(),
          child: const MaterialApp(
            home: PlayerPage(),
          ),
        ),
      );

      // 应该显示扩展控制按钮
      expect(find.byIcon(Icons.shuffle_rounded), findsOneWidget);
      expect(find.byIcon(Icons.repeat_rounded), findsOneWidget);
    });

    testWidgets('shows add button', (WidgetTester tester) async {
      await tester.pumpWidget(
        ChangeNotifierProvider<PlayerProvider>(
          create: (_) => MockPlayerProvider(),
          child: const MaterialApp(
            home: PlayerPage(),
          ),
        ),
      );

      // 应该显示添加按钮
      expect(find.byIcon(Icons.add_rounded), findsOneWidget);
    });
  });

  group('LyricsPage', () {
    testWidgets('renders lyrics content', (WidgetTester tester) async {
      await tester.pumpWidget(
        ChangeNotifierProvider<PlayerProvider>(
          create: (_) => MockPlayerProvider(),
          child: const MaterialApp(
            home: LyricsPage(),
          ),
        ),
      );

      // 应该显示歌词内容
      expect(find.text('♪ 前奏 ♪'), findsOneWidget);
    });

    testWidgets('shows close button', (WidgetTester tester) async {
      await tester.pumpWidget(
        ChangeNotifierProvider<PlayerProvider>(
          create: (_) => MockPlayerProvider(),
          child: const MaterialApp(
            home: LyricsPage(),
          ),
        ),
      );

      // 应该显示关闭按钮（向下箭头）
      expect(find.byIcon(Icons.keyboard_arrow_down_rounded), findsOneWidget);
    });
  });
}
