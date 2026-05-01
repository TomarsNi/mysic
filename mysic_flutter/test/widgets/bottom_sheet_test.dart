import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mysic_flutter/shared/widgets/bottom_sheet.dart';
import 'package:mysic_flutter/core/theme/app_colors.dart';
import 'package:mysic_flutter/features/player/data/models/playlist.dart';
import 'package:mysic_flutter/features/player/data/models/song.dart';

void main() {
  group('AddToPlaylistSheet', () {
    Future<void> pumpAddToPlaylistSheet(
      WidgetTester tester, {
      List<Playlist> playlists = const [],
      Song? song,
      void Function(Playlist)? onPlaylistSelected,
      VoidCallback? onCreatePlaylist,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AddToPlaylistSheet(
              playlists: playlists,
              song: song,
              onPlaylistSelected: onPlaylistSelected,
              onCreatePlaylist: onCreatePlaylist,
            ),
          ),
        ),
      );
    }

    testWidgets('should render create playlist button', (tester) async {
      await pumpAddToPlaylistSheet(tester);

      expect(find.text('创建新歌单'), findsOneWidget);
    });

    testWidgets('should render empty state when no playlists', (tester) async {
      await pumpAddToPlaylistSheet(tester, playlists: []);

      expect(find.text('暂无歌单'), findsOneWidget);
      expect(find.text('点击上方按钮创建新歌单'), findsOneWidget);
    });

    testWidgets('should render playlists list', (tester) async {
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

      await pumpAddToPlaylistSheet(tester, playlists: playlists);

      expect(find.text('我喜欢的音乐'), findsOneWidget);
      expect(find.text('运动歌单'), findsOneWidget);
    });

    testWidgets('should call onCreatePlaylist when create button tapped', (tester) async {
      bool createTapped = false;

      await pumpAddToPlaylistSheet(
        tester,
        onCreatePlaylist: () => createTapped = true,
      );

      await tester.tap(find.text('创建新歌单'));
      await tester.pumpAndSettle();

      expect(createTapped, isTrue);
    });

    testWidgets('should call onPlaylistSelected when playlist tapped', (tester) async {
      Playlist? selectedPlaylist;
      final playlists = [
        Playlist(
          id: 1,
          name: '我喜欢的音乐',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];

      await pumpAddToPlaylistSheet(
        tester,
        playlists: playlists,
        onPlaylistSelected: (playlist) => selectedPlaylist = playlist,
      );

      await tester.tap(find.text('我喜欢的音乐'));
      await tester.pumpAndSettle();

      expect(selectedPlaylist, isNotNull);
      expect(selectedPlaylist?.id, 1);
    });

    testWidgets('should display song info when song provided', (tester) async {
      final song = Song(
        id: 1,
        title: 'Test Song',
        artist: 'Test Artist',
        filePath: '/path/song.mp3',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await pumpAddToPlaylistSheet(tester, song: song);

      expect(find.text('Test Song'), findsOneWidget);
      expect(find.text('Test Artist'), findsOneWidget);
    });
  });

  group('PlaylistOptionsSheet', () {
    Future<void> pumpPlaylistOptionsSheet(
      WidgetTester tester, {
      required Playlist playlist,
      VoidCallback? onEdit,
      VoidCallback? onDelete,
      VoidCallback? onRename,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlaylistOptionsSheet(
              playlist: playlist,
              onEdit: onEdit,
              onDelete: onDelete,
              onRename: onRename,
            ),
          ),
        ),
      );
    }

    testWidgets('should render playlist name', (tester) async {
      final playlist = Playlist(
        id: 1,
        name: '我喜欢的音乐',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await pumpPlaylistOptionsSheet(tester, playlist: playlist);

      expect(find.text('我喜欢的音乐'), findsOneWidget);
    });

    testWidgets('should render all options', (tester) async {
      final playlist = Playlist(
        id: 1,
        name: '我喜欢的音乐',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await pumpPlaylistOptionsSheet(tester, playlist: playlist);

      expect(find.text('重命名'), findsOneWidget);
      expect(find.text('编辑歌曲'), findsOneWidget);
      expect(find.text('分享'), findsOneWidget);
      expect(find.text('删除歌单'), findsOneWidget);
    });

    testWidgets('should call onRename when rename tapped', (tester) async {
      bool renameTapped = false;
      final playlist = Playlist(
        id: 1,
        name: '我喜欢的音乐',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await pumpPlaylistOptionsSheet(
        tester,
        playlist: playlist,
        onRename: () => renameTapped = true,
      );

      await tester.tap(find.text('重命名'));
      await tester.pumpAndSettle();

      expect(renameTapped, isTrue);
    });

    testWidgets('should call onEdit when edit tapped', (tester) async {
      bool editTapped = false;
      final playlist = Playlist(
        id: 1,
        name: '我喜欢的音乐',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await pumpPlaylistOptionsSheet(
        tester,
        playlist: playlist,
        onEdit: () => editTapped = true,
      );

      await tester.tap(find.text('编辑歌曲'));
      await tester.pumpAndSettle();

      expect(editTapped, isTrue);
    });

    testWidgets('should call onDelete when delete tapped', (tester) async {
      bool deleteTapped = false;
      final playlist = Playlist(
        id: 1,
        name: '我喜欢的音乐',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await pumpPlaylistOptionsSheet(
        tester,
        playlist: playlist,
        onDelete: () => deleteTapped = true,
      );

      await tester.tap(find.text('删除歌单'));
      await tester.pumpAndSettle();

      expect(deleteTapped, isTrue);
    });
  });

  group('CreatePlaylistDialog', () {
    Future<void> pumpCreatePlaylistDialog(
      WidgetTester tester, {
      void Function(String name, String? description, List<Song>? scannedSongs)? onCreate,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => CreatePlaylistDialog(onCreate: onCreate),
                    );
                  },
                  child: const Text('Show Dialog'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();
    }

    testWidgets('should render dialog title', (tester) async {
      await pumpCreatePlaylistDialog(tester);

      expect(find.text('创建歌单'), findsOneWidget);
    });

    testWidgets('should render input fields', (tester) async {
      await pumpCreatePlaylistDialog(tester);

      expect(find.text('歌单名称'), findsOneWidget);
      expect(find.text('描述（可选）'), findsOneWidget);
    });

    testWidgets('should have disabled create button initially', (tester) async {
      await pumpCreatePlaylistDialog(tester);

      final createButton = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, '创建'),
      );

      expect(createButton.enabled, isFalse);
    });

    testWidgets('should enable create button when name entered', (tester) async {
      await pumpCreatePlaylistDialog(tester);

      await tester.enterText(find.byType(TextField).first, '新歌单');
      await tester.pump();

      final createButton = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, '创建'),
      );

      expect(createButton.enabled, isTrue);
    });

    testWidgets('should call onCreate with name when create tapped', (tester) async {
      String? createdName;
      String? createdDescription;
      List<Song>? createdSongs;

      await pumpCreatePlaylistDialog(
        tester,
        onCreate: (name, description, scannedSongs) {
          createdName = name;
          createdDescription = description;
          createdSongs = scannedSongs;
        },
      );

      await tester.enterText(find.byType(TextField).first, '新歌单');
      await tester.pump();

      await tester.tap(find.text('创建'));
      await tester.pumpAndSettle();

      expect(createdName, '新歌单');
      expect(createdDescription, isNull);
      expect(createdSongs, isNull);
    });

    testWidgets('should call onCreate with description when provided', (tester) async {
      String? createdName;
      String? createdDescription;
      List<Song>? createdSongs;

      await pumpCreatePlaylistDialog(
        tester,
        onCreate: (name, description, scannedSongs) {
          createdName = name;
          createdDescription = description;
          createdSongs = scannedSongs;
        },
      );

      await tester.enterText(find.byType(TextField).first, '新歌单');
      await tester.enterText(find.byType(TextField).last, '歌单描述');
      await tester.pump();

      await tester.tap(find.text('创建'));
      await tester.pumpAndSettle();

      expect(createdName, '新歌单');
      expect(createdDescription, '歌单描述');
    });

    testWidgets('should close dialog when cancel tapped', (tester) async {
      await pumpCreatePlaylistDialog(tester);

      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();

      expect(find.text('创建歌单'), findsNothing);
    });
  });

  group('CreatePlaylistDialog with directory selection', () {
    Future<void> pumpCreatePlaylistDialog(
      WidgetTester tester, {
      void Function(String name, String? description, List<Song>? scannedSongs)? onCreate,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => CreatePlaylistDialog(onCreate: onCreate),
                    );
                  },
                  child: const Text('Show Dialog'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();
    }

    testWidgets('should render directory selection field', (tester) async {
      await pumpCreatePlaylistDialog(tester);

      expect(find.text('扫描目录（可选）'), findsOneWidget);
      expect(find.text('选择'), findsOneWidget);
    });

    testWidgets('should show placeholder when no directory selected', (tester) async {
      await pumpCreatePlaylistDialog(tester);

      expect(find.text('未选择目录'), findsOneWidget);
    });
  });
}
