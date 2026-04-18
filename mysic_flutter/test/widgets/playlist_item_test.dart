import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mysic_flutter/features/playlist/presentation/widgets/playlist_item.dart';
import 'package:mysic_flutter/core/theme/app_colors.dart';
import 'package:mysic_flutter/features/player/data/models/playlist.dart';
import 'package:mysic_flutter/features/player/data/models/song.dart';

void main() {
  group('PlaylistItem', () {
    Future<void> pumpPlaylistItem(
      WidgetTester tester, {
      required Playlist playlist,
      VoidCallback? onTap,
      VoidCallback? onLongPress,
      bool isSelected = false,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlaylistItem(
              playlist: playlist,
              onTap: onTap,
              onLongPress: onLongPress,
              isSelected: isSelected,
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

      await pumpPlaylistItem(tester, playlist: playlist);

      expect(find.text('我喜欢的音乐'), findsOneWidget);
    });

    testWidgets('should render song count', (tester) async {
      final playlist = Playlist(
        id: 1,
        name: '我喜欢的音乐',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        songs: List.generate(25, (i) => _createMockSong(i)),
      );

      await pumpPlaylistItem(tester, playlist: playlist);

      expect(find.text('25 首歌曲'), findsOneWidget);
    });

    testWidgets('should render description when provided', (tester) async {
      final playlist = Playlist(
        id: 1,
        name: '我喜欢的音乐',
        description: '我最爱的歌曲合集',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await pumpPlaylistItem(
        tester,
        playlist: playlist,
      );

      expect(find.text('我最爱的歌曲合集'), findsOneWidget);
    });

    testWidgets('should highlight when selected', (tester) async {
      final playlist = Playlist(
        id: 1,
        name: '我喜欢的音乐',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await pumpPlaylistItem(
        tester,
        playlist: playlist,
        isSelected: true,
      );

      final textWidget = tester.widget<Text>(find.text('我喜欢的音乐'));
      expect(textWidget.style?.color, AppColors.accent);
    });

    testWidgets('should call onTap when tapped', (tester) async {
      bool tapped = false;
      final playlist = Playlist(
        id: 1,
        name: '我喜欢的音乐',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await pumpPlaylistItem(
        tester,
        playlist: playlist,
        onTap: () => tapped = true,
      );

      await tester.tap(find.text('我喜欢的音乐'));
      await tester.pumpAndSettle();

      expect(tapped, isTrue);
    });

    testWidgets('should call onLongPress when long pressed', (tester) async {
      bool longPressed = false;
      final playlist = Playlist(
        id: 1,
        name: '我喜欢的音乐',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await pumpPlaylistItem(
        tester,
        playlist: playlist,
        onLongPress: () => longPressed = true,
      );

      await tester.longPress(find.text('我喜欢的音乐'));
      await tester.pumpAndSettle();

      expect(longPressed, isTrue);
    });
  });

  group('PlaylistSongItem', () {
    Future<void> pumpPlaylistSongItem(
      WidgetTester tester, {
      required Song song,
      required int index,
      bool isPlaying = false,
      VoidCallback? onTap,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlaylistSongItem(
              song: song,
              index: index,
              isPlaying: isPlaying,
              onTap: onTap,
            ),
          ),
        ),
      );
    }

    testWidgets('should render song title', (tester) async {
      final song = _createMockSong(0);

      await pumpPlaylistSongItem(tester, song: song, index: 0);

      expect(find.text('Song 0'), findsOneWidget);
    });

    testWidgets('should render song artist', (tester) async {
      final song = Song(
        id: 1,
        title: 'Test Song',
        artist: 'Test Artist',
        filePath: '/path/song.mp3',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await pumpPlaylistSongItem(tester, song: song, index: 0);

      expect(find.text('Test Artist'), findsOneWidget);
    });

    testWidgets('should render index number', (tester) async {
      final song = _createMockSong(0);

      await pumpPlaylistSongItem(tester, song: song, index: 4);

      expect(find.text('5'), findsOneWidget);
    });

    testWidgets('should show playing indicator when playing', (tester) async {
      final song = _createMockSong(0);

      await pumpPlaylistSongItem(
        tester,
        song: song,
        index: 0,
        isPlaying: true,
      );

      expect(find.byIcon(Icons.volume_up_rounded), findsOneWidget);
    });

    testWidgets('should highlight when playing', (tester) async {
      final song = _createMockSong(0);

      await pumpPlaylistSongItem(
        tester,
        song: song,
        index: 0,
        isPlaying: true,
      );

      final textWidget = tester.widget<Text>(find.text('Song 0'));
      expect(textWidget.style?.color, AppColors.accent);
    });

    testWidgets('should call onTap when tapped', (tester) async {
      bool tapped = false;
      final song = _createMockSong(0);

      await pumpPlaylistSongItem(
        tester,
        song: song,
        index: 0,
        onTap: () => tapped = true,
      );

      await tester.tap(find.text('Song 0'));
      await tester.pumpAndSettle();

      expect(tapped, isTrue);
    });
  });

  group('PlaylistHeader', () {
    Future<void> pumpPlaylistHeader(
      WidgetTester tester, {
      required Playlist playlist,
      VoidCallback? onPlayAll,
      VoidCallback? onShufflePlay,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlaylistHeader(
              playlist: playlist,
              onPlayAll: onPlayAll,
              onShufflePlay: onShufflePlay,
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

      await pumpPlaylistHeader(tester, playlist: playlist);

      expect(find.text('我喜欢的音乐'), findsOneWidget);
    });

    testWidgets('should render play all button', (tester) async {
      final playlist = Playlist(
        id: 1,
        name: '我喜欢的音乐',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await pumpPlaylistHeader(tester, playlist: playlist);

      expect(find.text('播放全部'), findsOneWidget);
    });

    testWidgets('should render shuffle button', (tester) async {
      final playlist = Playlist(
        id: 1,
        name: '我喜欢的音乐',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await pumpPlaylistHeader(tester, playlist: playlist);

      expect(find.text('随机播放'), findsOneWidget);
    });

    testWidgets('should call onPlayAll when play all button tapped', (tester) async {
      bool playAllTapped = false;
      final playlist = Playlist(
        id: 1,
        name: '我喜欢的音乐',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await pumpPlaylistHeader(
        tester,
        playlist: playlist,
        onPlayAll: () => playAllTapped = true,
      );

      await tester.tap(find.text('播放全部'));
      await tester.pumpAndSettle();

      expect(playAllTapped, isTrue);
    });

    testWidgets('should call onShufflePlay when shuffle button tapped', (tester) async {
      bool shuffleTapped = false;
      final playlist = Playlist(
        id: 1,
        name: '我喜欢的音乐',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await pumpPlaylistHeader(
        tester,
        playlist: playlist,
        onShufflePlay: () => shuffleTapped = true,
      );

      await tester.tap(find.text('随机播放'));
      await tester.pumpAndSettle();

      expect(shuffleTapped, isTrue);
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
