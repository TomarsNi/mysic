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
      Playlist? favoritesPlaylist,
      Future<void> Function(Playlist)? onPlaylistTap,
      Future<void> Function(Playlist)? onFavoritesTap,
      VoidCallback? onScanSettingsTap,
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
                    favoritesPlaylist: favoritesPlaylist,
                    onPlaylistTap: onPlaylistTap,
                    onFavoritesTap: onFavoritesTap,
                    onScanSettingsTap: onScanSettingsTap,
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

      expect(find.text('扫描设置'), findsOneWidget);
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
        onPlaylistTap: (playlist) async {
          tappedPlaylist = playlist;
        },
      );

      await tester.tap(find.text('我喜欢的音乐'));
      await tester.pumpAndSettle();

      expect(tappedPlaylist, isNotNull);
      expect(tappedPlaylist?.id, 1);
    });

    testWidgets('should call onScanSettingsTap when scan button is tapped', (tester) async {
      bool scanTapped = false;

      await pumpAppDrawer(
        tester,
        onScanSettingsTap: () => scanTapped = true,
      );

      await tester.tap(find.text('扫描设置'));
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

    testWidgets('should render favorites section when favoritesPlaylist is provided', (tester) async {
      final favoritesPlaylist = Playlist(
        id: 100,
        name: '我喜欢听',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        songs: [_createMockSong(1), _createMockSong(2)],
      );

      await pumpAppDrawer(tester, favoritesPlaylist: favoritesPlaylist);

      // 应该显示"我喜欢听"文本（标题 + 歌单名称，共2个）
      expect(find.text('我喜欢听'), findsWidgets);
      // 应该显示歌曲数量
      expect(find.text('2 首歌曲'), findsOneWidget);
    });

    testWidgets('should not render favorites entry when favoritesPlaylist is null', (tester) async {
      await pumpAppDrawer(tester, favoritesPlaylist: null);

      // "我喜欢听"标题仍然存在，但没有歌单条目
      // 由于 favoritesPlaylist 为 null，_FavoritesListTile 不会渲染
      // 所以只会找到一个"我喜欢听"（标题）
      expect(find.text('我喜欢听'), findsOneWidget);
    });

    testWidgets('should call onFavoritesTap when favorites playlist is tapped', (tester) async {
      Playlist? tappedPlaylist;
      final favoritesPlaylist = Playlist(
        id: 100,
        name: '我喜欢听',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        songs: [],
      );

      await pumpAppDrawer(
        tester,
        favoritesPlaylist: favoritesPlaylist,
        onFavoritesTap: (playlist) async {
          tappedPlaylist = playlist;
        },
      );

      // 点击"我喜欢听"歌单条目（第二个，即歌单名称）
      // 第一个是标题，第二个是歌单条目
      final textWidgets = find.text('我喜欢听');
      expect(textWidgets, findsWidgets);
      await tester.tap(textWidgets.last);
      await tester.pumpAndSettle();

      expect(tappedPlaylist, isNotNull);
      expect(tappedPlaylist?.id, 100);
    });

    testWidgets('should highlight selected favorites playlist', (tester) async {
      final favoritesPlaylist = Playlist(
        id: 100,
        name: '我喜欢听',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        songs: [],
      );

      await pumpAppDrawer(
        tester,
        favoritesPlaylist: favoritesPlaylist,
        selectedPlaylistId: 100,
      );

      // 找到"我喜欢听"文本
      final textWidgets = find.text('我喜欢听');
      expect(textWidgets, findsWidgets);

      // 验证选中状态（accent 颜色）
      final selectedTextWidget = tester.widget<Text>(textWidgets.last);
      expect(selectedTextWidget.style?.color, AppColors.accent);
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
