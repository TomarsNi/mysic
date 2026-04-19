import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mysic_flutter/shared/widgets/app_drawer.dart';
import 'package:mysic_flutter/core/theme/app_colors.dart';
import 'package:mysic_flutter/features/player/data/models/playlist.dart';
import 'package:mysic_flutter/features/player/data/models/song.dart';
import 'package:mysic_flutter/features/player/presentation/providers/player_provider.dart';
import 'package:mysic_flutter/features/player/data/services/audio_player_service.dart';
import 'package:provider/provider.dart';

void main() {
  group('AppDrawer', () {
    // Helper to pump AppDrawer with necessary providers and proper window size
    Future<void> pumpAppDrawer(
      WidgetTester tester, {
      List<Playlist> playlists = const [],
      int? selectedPlaylistId,
      void Function(Playlist)? onPlaylistTap,
      VoidCallback? onScanTap,
      VoidCallback? onSettingsTap,
      VoidCallback? onAboutTap,
      VoidCallback? onCreatePlaylistTap,
    }) async {
      // Set a larger window size to avoid overflow
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<PlayerProvider>(
            create: (_) => PlayerProvider(audioPlayerService: AudioPlayerService()),
            child: Scaffold(
              body: Row(
                children: [
                  AppDrawer(
                    playlists: playlists,
                    selectedPlaylistId: selectedPlaylistId,
                    onPlaylistTap: onPlaylistTap,
                    onScanTap: onScanTap,
                    onSettingsTap: onSettingsTap,
                    onAboutTap: onAboutTap,
                    onCreatePlaylistTap: onCreatePlaylistTap,
                  ),
                  const Expanded(child: Text('Content')),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('should render header with app name', (tester) async {
      await pumpAppDrawer(tester);

      expect(find.text('Mysic'), findsOneWidget);
      expect(find.text('本地音乐播放器'), findsOneWidget);
    });

    testWidgets('should render scan button', (tester) async {
      await pumpAppDrawer(tester);

      expect(find.text('本地音乐'), findsOneWidget);
      expect(find.text('扫描设备中的音乐文件'), findsOneWidget);
    });

    testWidgets('should render empty state when no playlists', (tester) async {
      await pumpAppDrawer(tester, playlists: []);

      expect(find.text('暂无歌单'), findsOneWidget);
      expect(find.text('创建歌单'), findsOneWidget);
    });

    testWidgets('should render playlists list', (tester) async {
      final playlists = [
        Playlist(
          id: 1,
          name: '我喜欢的音乐',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          songs: [],
        ),
        Playlist(
          id: 2,
          name: '运动歌单',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          songs: [],
        ),
      ];

      await pumpAppDrawer(tester, playlists: playlists);

      expect(find.text('我喜欢的音乐'), findsOneWidget);
      expect(find.text('运动歌单'), findsOneWidget);
    });

    testWidgets('should highlight selected playlist', (tester) async {
      final playlists = [
        Playlist(
          id: 1,
          name: '我喜欢的音乐',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        Playlist(
          id: 2,
          name: '运动歌单',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];

      await pumpAppDrawer(
        tester,
        playlists: playlists,
        selectedPlaylistId: 1,
      );

      // 找到所有歌单名称文本
      final textWidgets = find.text('我喜欢的音乐');
      expect(textWidgets, findsWidgets);

      // 验证选中状态存在（通过查找 accent 颜色的文本）
      final selectedTextWidget = tester.widget<Text>(textWidgets.first);
      expect(selectedTextWidget.style?.color, AppColors.accent);
    });

    testWidgets('should call onPlaylistTap when playlist is tapped', (tester) async {
      Playlist? tappedPlaylist;
      final playlists = [
        Playlist(
          id: 1,
          name: '我喜欢的音乐',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];

      await pumpAppDrawer(
        tester,
        playlists: playlists,
        onPlaylistTap: (playlist) => tappedPlaylist = playlist,
      );

      await tester.tap(find.text('我喜欢的音乐'));
      await tester.pumpAndSettle();

      expect(tappedPlaylist, isNotNull);
      expect(tappedPlaylist?.id, 1);
    });

    testWidgets('should call onScanTap when scan button is tapped', (tester) async {
      bool scanTapped = false;

      await pumpAppDrawer(
        tester,
        onScanTap: () => scanTapped = true,
      );

      await tester.tap(find.text('本地音乐'));
      await tester.pumpAndSettle();

      expect(scanTapped, isTrue);
    });

    testWidgets('should call onCreatePlaylistTap when create button is tapped', (tester) async {
      bool createTapped = false;

      await pumpAppDrawer(
        tester,
        onCreatePlaylistTap: () => createTapped = true,
      );

      // 找到歌单标题区域的添加按钮
      final addButtons = find.byIcon(Icons.add_rounded);
      expect(addButtons, findsWidgets);

      // 点击第一个添加按钮（歌单标题旁边的）
      await tester.tap(addButtons.first);
      await tester.pumpAndSettle();

      expect(createTapped, isTrue);
    });

    testWidgets('should render settings and about buttons', (tester) async {
      await pumpAppDrawer(tester);

      expect(find.text('设置'), findsOneWidget);
      expect(find.text('关于'), findsOneWidget);
    });

    testWidgets('should call onSettingsTap when settings is tapped', (tester) async {
      bool settingsTapped = false;

      await pumpAppDrawer(
        tester,
        onSettingsTap: () => settingsTapped = true,
      );

      await tester.tap(find.text('设置'));
      await tester.pumpAndSettle();

      expect(settingsTapped, isTrue);
    });

    testWidgets('should call onAboutTap when about is tapped', (tester) async {
      bool aboutTapped = false;

      await pumpAppDrawer(
        tester,
        onAboutTap: () => aboutTapped = true,
      );

      await tester.tap(find.text('关于'));
      await tester.pumpAndSettle();

      expect(aboutTapped, isTrue);
    });

    testWidgets('should display song count for playlists', (tester) async {
      final playlists = [
        Playlist(
          id: 1,
          name: '我喜欢的音乐',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          songs: List.generate(10, (i) => _createMockSong(i)),
        ),
      ];

      await pumpAppDrawer(tester, playlists: playlists);

      expect(find.text('10 首歌曲'), findsOneWidget);
    });
  });
}

Song _createMockSong(int id) {
  return Song(
    id: id,
    title: 'Song $id',
    filePath: '/path/song$id.mp3',
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );
}
