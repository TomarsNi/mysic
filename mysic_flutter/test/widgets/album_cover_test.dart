import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mysic_flutter/features/player/presentation/widgets/album_cover.dart';
import 'package:mysic_flutter/features/player/data/models/song.dart';

void main() {
  group('AlbumCover', () {
    testWidgets('renders without song', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AlbumCover(song: null),
          ),
        ),
      );

      // 应该显示默认的音乐图标
      expect(find.byIcon(Icons.music_note_rounded), findsOneWidget);
    });

    testWidgets('renders with song without album art', (WidgetTester tester) async {
      final song = Song(
        id: 1,
        title: 'Test Song',
        artist: 'Test Artist',
        filePath: '/path/to/song.mp3',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AlbumCover(song: song),
          ),
        ),
      );

      // 应该显示默认的音乐图标
      expect(find.byIcon(Icons.music_note_rounded), findsOneWidget);
    });

    testWidgets('shows correct size with vinyl-ring', (WidgetTester tester) async {
      const testSize = 150.0;
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AlbumCover(
              song: null,
              size: testSize,
            ),
          ),
        ),
      );

      // vinyl-ring 效果包含三层容器
      // 外层边框环：size + 16 (166)
      // 内层边框环：size + 8 (158)
      // 主封面：size (150)

      // 验证所有容器都存在
      final containers = find.descendant(
        of: find.byType(AlbumCover),
        matching: find.byType(Container),
      );

      // 应该有多个容器（vinyl-ring + 主封面）
      expect(containers, findsWidgets);

      // 验证主封面容器的尺寸（第三个容器）
      // 由于 vinyl-ring 使用 Stack，主封面是最后一个 Container
      final allContainers = tester.widgetList<Container>(containers).toList();

      // 验证存在 vinyl-ring 外层容器 (166x166)
      final outerRing = allContainers.first;
      expect(outerRing.constraints?.maxWidth, testSize + 16);
      expect(outerRing.constraints?.maxHeight, testSize + 16);
    });

    testWidgets('animation controller is created', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AlbumCover(
              song: null,
              isPlaying: true,
            ),
          ),
        ),
      );

      // 等待动画帧
      await tester.pump(const Duration(milliseconds: 100));

      // 组件应该正常渲染
      expect(find.byType(AlbumCover), findsOneWidget);
    });

    testWidgets('stops animation when isPlaying changes to false',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AlbumCover(
              song: null,
              isPlaying: true,
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 500));

      // 更新为不播放状态
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AlbumCover(
              song: null,
              isPlaying: false,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 组件应该正常渲染
      expect(find.byType(AlbumCover), findsOneWidget);
    });
  });

  group('AlbumCoverSmall', () {
    testWidgets('renders without song', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AlbumCoverSmall(song: null),
          ),
        ),
      );

      // 应该显示默认的音乐图标
      expect(find.byIcon(Icons.music_note_rounded), findsOneWidget);
    });

    testWidgets('renders with default size', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AlbumCoverSmall(song: null),
          ),
        ),
      );

      // 组件应该正常渲染
      expect(find.byType(AlbumCoverSmall), findsOneWidget);
    });

    testWidgets('renders with custom size', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AlbumCoverSmall(
              song: null,
              size: 64,
            ),
          ),
        ),
      );

      // 组件应该正常渲染
      expect(find.byType(AlbumCoverSmall), findsOneWidget);
    });
  });
}
