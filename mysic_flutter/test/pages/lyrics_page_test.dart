import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mysic_flutter/features/lyrics/presentation/pages/lyrics_page.dart';
import 'package:mysic_flutter/features/player/presentation/providers/player_provider.dart';
import 'package:mysic_flutter/features/player/data/services/audio_player_service.dart';
import 'package:mysic_flutter/features/player/data/models/song.dart';

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
}

void main() {
  group('LyricsPage', () {
    testWidgets('renders with sample lyrics', (WidgetTester tester) async {
      await tester.pumpWidget(
        ChangeNotifierProvider<PlayerProvider>(
          create: (_) => MockPlayerProvider(),
          child: const MaterialApp(
            home: LyricsPage(),
          ),
        ),
      );

      // 应该显示示例歌词
      expect(find.text('♪ 前奏 ♪'), findsOneWidget);
    });

    testWidgets('shows back button', (WidgetTester tester) async {
      await tester.pumpWidget(
        ChangeNotifierProvider<PlayerProvider>(
          create: (_) => MockPlayerProvider(),
          child: const MaterialApp(
            home: LyricsPage(),
          ),
        ),
      );

      // 应该显示返回按钮
      expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
    });

    testWidgets('shows more options button', (WidgetTester tester) async {
      await tester.pumpWidget(
        ChangeNotifierProvider<PlayerProvider>(
          create: (_) => MockPlayerProvider(),
          child: const MaterialApp(
            home: LyricsPage(),
          ),
        ),
      );

      // 应该显示更多选项按钮
      expect(find.byIcon(Icons.more_vert_rounded), findsOneWidget);
    });

    testWidgets('shows mini player controls', (WidgetTester tester) async {
      await tester.pumpWidget(
        ChangeNotifierProvider<PlayerProvider>(
          create: (_) => MockPlayerProvider(),
          child: const MaterialApp(
            home: LyricsPage(),
          ),
        ),
      );

      // 应该显示迷你播放器控制按钮
      expect(find.byIcon(Icons.skip_previous_rounded), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
      expect(find.byIcon(Icons.skip_next_rounded), findsOneWidget);
    });

    testWidgets('shows unknown song title when no song', (WidgetTester tester) async {
      await tester.pumpWidget(
        ChangeNotifierProvider<PlayerProvider>(
          create: (_) => MockPlayerProvider(),
          child: const MaterialApp(
            home: LyricsPage(),
          ),
        ),
      );

      // 应该显示默认歌曲信息
      expect(find.text('未知歌曲'), findsOneWidget);
      expect(find.text('未知艺术家'), findsOneWidget);
    });
  });

  group('LyricLine', () {
    test('creates with timestamp and text', () {
      const line = LyricLine(
        timestamp: Duration(seconds: 10),
        text: 'Test lyric line',
      );

      expect(line.timestamp, const Duration(seconds: 10));
      expect(line.text, 'Test lyric line');
    });

    test('equality works correctly', () {
      const line1 = LyricLine(
        timestamp: Duration(seconds: 10),
        text: 'Test lyric line',
      );

      const line2 = LyricLine(
        timestamp: Duration(seconds: 10),
        text: 'Test lyric line',
      );

      const line3 = LyricLine(
        timestamp: Duration(seconds: 20),
        text: 'Different line',
      );

      expect(line1, equals(line2));
      expect(line1, isNot(equals(line3)));
    });

    test('hashCode is consistent', () {
      const line1 = LyricLine(
        timestamp: Duration(seconds: 10),
        text: 'Test lyric line',
      );

      const line2 = LyricLine(
        timestamp: Duration(seconds: 10),
        text: 'Test lyric line',
      );

      expect(line1.hashCode, equals(line2.hashCode));
    });
  });
}
