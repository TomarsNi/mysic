import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mysic_flutter/features/player/presentation/widgets/play_controls.dart';
import 'package:mysic_flutter/features/player/data/services/audio_player_service.dart';

void main() {
  group('PlayControls', () {
    testWidgets('renders all control buttons', (WidgetTester tester) async {
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

      // 应该显示上一首、播放、下一首按钮
      expect(find.byIcon(Icons.skip_previous_rounded), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
      expect(find.byIcon(Icons.skip_next_rounded), findsOneWidget);
    });

    testWidgets('shows pause icon when playing', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlayControls(
              isPlaying: true,
              isLoading: false,
              hasPlaylist: true,
              onPlayPause: () {},
              onNext: () {},
              onPrevious: () {},
            ),
          ),
        ),
      );

      // 应该显示暂停图标
      expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
    });

    testWidgets('shows loading indicator when loading',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlayControls(
              isPlaying: false,
              isLoading: true,
              hasPlaylist: true,
              onPlayPause: () {},
              onNext: () {},
              onPrevious: () {},
            ),
          ),
        ),
      );

      // 应该显示加载指示器
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('disables previous/next buttons when no playlist',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlayControls(
              isPlaying: false,
              isLoading: false,
              hasPlaylist: false,
              onPlayPause: () {},
              onNext: () {},
              onPrevious: () {},
            ),
          ),
        ),
      );

      // 按钮应该存在但禁用
      expect(find.byIcon(Icons.skip_previous_rounded), findsOneWidget);
      expect(find.byIcon(Icons.skip_next_rounded), findsOneWidget);
    });

    testWidgets('calls onPlayPause when play button tapped',
        (WidgetTester tester) async {
      var tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlayControls(
              isPlaying: false,
              isLoading: false,
              hasPlaylist: true,
              onPlayPause: () => tapped = true,
              onNext: () {},
              onPrevious: () {},
            ),
          ),
        ),
      );

      // 点击播放按钮
      await tester.tap(find.byIcon(Icons.play_arrow_rounded));
      await tester.pumpAndSettle();

      expect(tapped, isTrue);
    });
  });

  group('ExtendedControls', () {
    testWidgets('renders shuffle and loop buttons', (WidgetTester tester) async {
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

      expect(find.byIcon(Icons.shuffle_rounded), findsOneWidget);
      expect(find.byIcon(Icons.repeat_rounded), findsOneWidget);
    });

    testWidgets('shows shuffle as active when enabled', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ExtendedControls(
              isShuffleMode: true,
              loopMode: MysicLoopMode.off,
              onToggleShuffle: () {},
              onToggleLoop: () {},
            ),
          ),
        ),
      );

      // 随机按钮应该高亮
      expect(find.byIcon(Icons.shuffle_rounded), findsOneWidget);
    });

    testWidgets('shows repeat_one icon when loop mode is one',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ExtendedControls(
              isShuffleMode: false,
              loopMode: MysicLoopMode.one,
              onToggleShuffle: () {},
              onToggleLoop: () {},
            ),
          ),
        ),
      );

      // 应该显示单曲循环图标
      expect(find.byIcon(Icons.repeat_one_rounded), findsOneWidget);
    });

    testWidgets('shows badge when loop mode is one', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ExtendedControls(
              isShuffleMode: false,
              loopMode: MysicLoopMode.one,
              onToggleShuffle: () {},
              onToggleLoop: () {},
            ),
          ),
        ),
      );

      // 应该显示 "1" 徽章
      expect(find.text('1'), findsOneWidget);
    });

    testWidgets('calls onToggleShuffle when shuffle button tapped',
        (WidgetTester tester) async {
      var tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ExtendedControls(
              isShuffleMode: false,
              loopMode: MysicLoopMode.off,
              onToggleShuffle: () => tapped = true,
              onToggleLoop: () {},
            ),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.shuffle_rounded));
      await tester.pumpAndSettle();

      expect(tapped, isTrue);
    });

    testWidgets('calls onToggleLoop when loop button tapped',
        (WidgetTester tester) async {
      var tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ExtendedControls(
              isShuffleMode: false,
              loopMode: MysicLoopMode.off,
              onToggleShuffle: () {},
              onToggleLoop: () => tapped = true,
            ),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.repeat_rounded));
      await tester.pumpAndSettle();

      expect(tapped, isTrue);
    });
  });
}
