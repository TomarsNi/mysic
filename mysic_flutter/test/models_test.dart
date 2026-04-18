import 'package:flutter_test/flutter_test.dart';
import 'package:mysic_flutter/features/player/data/models/song.dart';
import 'package:mysic_flutter/features/player/data/models/playlist.dart';

void main() {
  group('Song Model Tests', () {
    late Song testSong;

    setUp(() {
      testSong = Song(
        id: 1,
        title: '测试歌曲',
        artist: '测试艺术家',
        album: '测试专辑',
        duration: 180000, // 3分钟
        filePath: '/path/to/song.mp3',
        albumArtPath: '/path/to/cover.jpg',
        dateAdded: 1713408000,
        createdAt: DateTime(2024, 4, 18),
        updatedAt: DateTime(2024, 4, 18),
      );
    });

    test('Song should be created with correct properties', () {
      expect(testSong.id, 1);
      expect(testSong.title, '测试歌曲');
      expect(testSong.artist, '测试艺术家');
      expect(testSong.album, '测试专辑');
      expect(testSong.duration, 180000);
      expect(testSong.filePath, '/path/to/song.mp3');
      expect(testSong.albumArtPath, '/path/to/cover.jpg');
    });

    test('Song.formattedDuration should return correct format', () {
      expect(testSong.formattedDuration, '3:00');

      final shortSong = testSong.copyWith(duration: 45000); // 45秒
      expect(shortSong.formattedDuration, '0:45');

      final longSong = testSong.copyWith(duration: 3723000); // 62分3秒
      expect(longSong.formattedDuration, '62:03');
    });

    test('Song.displayArtist should return default for null artist', () {
      final songWithoutArtist = Song(
        title: '测试歌曲',
        filePath: '/path/to/song.mp3',
        createdAt: DateTime(2024, 4, 18),
        updatedAt: DateTime(2024, 4, 18),
      );
      expect(songWithoutArtist.displayArtist, '未知艺术家');
    });

    test('Song.displayAlbum should return default for null album', () {
      final songWithoutAlbum = Song(
        title: '测试歌曲',
        filePath: '/path/to/song.mp3',
        createdAt: DateTime(2024, 4, 18),
        updatedAt: DateTime(2024, 4, 18),
      );
      expect(songWithoutAlbum.displayAlbum, '未知专辑');
    });

    test('Song.toMap should convert to correct map', () {
      final map = testSong.toMap();
      expect(map['id'], 1);
      expect(map['title'], '测试歌曲');
      expect(map['artist'], '测试艺术家');
      expect(map['file_path'], '/path/to/song.mp3');
    });

    test('Song.fromMap should create correct Song object', () {
      final map = {
        'id': 2,
        'title': '新歌曲',
        'artist': '新艺术家',
        'album': '新专辑',
        'duration': 240000,
        'file_path': '/new/path.mp3',
        'album_art_path': null,
        'date_added': null,
        'created_at': '2024-04-18T00:00:00.000',
        'updated_at': '2024-04-18T00:00:00.000',
      };

      final song = Song.fromMap(map);
      expect(song.id, 2);
      expect(song.title, '新歌曲');
      expect(song.artist, '新艺术家');
      expect(song.duration, 240000);
    });

    test('Song equality should work correctly', () {
      final sameSong = Song(
        id: 1,
        title: '测试歌曲',
        artist: '测试艺术家',
        album: '测试专辑',
        duration: 180000,
        filePath: '/path/to/song.mp3',
        createdAt: DateTime(2024, 4, 18),
        updatedAt: DateTime(2024, 4, 18),
      );

      expect(testSong, equals(sameSong));
    });

    test('Song.copyWith should create modified copy', () {
      final modifiedSong = testSong.copyWith(title: '修改后的标题');
      expect(modifiedSong.title, '修改后的标题');
      expect(modifiedSong.id, testSong.id); // 其他字段保持不变
    });
  });

  group('Playlist Model Tests', () {
    late Playlist testPlaylist;
    late List<Song> testSongs;

    setUp(() {
      testSongs = [
        Song(
          id: 1,
          title: '歌曲1',
          artist: '艺术家1',
          duration: 180000,
          filePath: '/path/1.mp3',
          createdAt: DateTime(2024, 4, 18),
          updatedAt: DateTime(2024, 4, 18),
        ),
        Song(
          id: 2,
          title: '歌曲2',
          artist: '艺术家2',
          duration: 240000,
          filePath: '/path/2.mp3',
          createdAt: DateTime(2024, 4, 18),
          updatedAt: DateTime(2024, 4, 18),
        ),
      ];

      testPlaylist = Playlist(
        id: 1,
        name: '测试歌单',
        description: '这是一个测试歌单',
        coverPath: '/path/to/cover.jpg',
        createdAt: DateTime(2024, 4, 18),
        updatedAt: DateTime(2024, 4, 18),
        songs: testSongs,
      );
    });

    test('Playlist should be created with correct properties', () {
      expect(testPlaylist.id, 1);
      expect(testPlaylist.name, '测试歌单');
      expect(testPlaylist.description, '这是一个测试歌单');
      expect(testPlaylist.songs?.length, 2);
    });

    test('Playlist.songCount should return correct count', () {
      expect(testPlaylist.songCount, 2);

      final emptyPlaylist = testPlaylist.copyWith(songs: []);
      expect(emptyPlaylist.songCount, 0);
    });

    test('Playlist.totalDuration should calculate correctly', () {
      // 180000 + 240000 = 420000 ms = 7分钟
      expect(testPlaylist.totalDuration, 420000);
    });

    test('Playlist.formattedTotalDuration should return correct format', () {
      expect(testPlaylist.formattedTotalDuration, '7:00');

      final longPlaylist = testPlaylist.copyWith(songs: [
        ...testSongs,
        Song(
          id: 3,
          title: '长歌曲',
          duration: 3600000, // 1小时
          filePath: '/path/3.mp3',
          createdAt: DateTime(2024, 4, 18),
          updatedAt: DateTime(2024, 4, 18),
        ),
      ]);
      expect(longPlaylist.formattedTotalDuration, '1:07:00');
    });

    test('Playlist.containsSong should work correctly', () {
      final songInPlaylist = testSongs[0];
      expect(testPlaylist.containsSong(songInPlaylist), true);

      final songNotInPlaylist = Song(
        id: 999,
        title: '不在歌单中',
        filePath: '/other/path.mp3',
        createdAt: DateTime(2024, 4, 18),
        updatedAt: DateTime(2024, 4, 18),
      );
      expect(testPlaylist.containsSong(songNotInPlaylist), false);
    });

    test('Playlist.addSong should add song correctly', () {
      final newSong = Song(
        id: 3,
        title: '新歌曲',
        filePath: '/path/3.mp3',
        createdAt: DateTime(2024, 4, 18),
        updatedAt: DateTime(2024, 4, 18),
      );

      final updatedPlaylist = testPlaylist.addSong(newSong);
      expect(updatedPlaylist.songCount, 3);
      expect(updatedPlaylist.containsSong(newSong), true);

      // 添加已存在的歌曲不应重复
      final samePlaylist = updatedPlaylist.addSong(newSong);
      expect(samePlaylist.songCount, 3);
    });

    test('Playlist.removeSong should remove song correctly', () {
      final songToRemove = testSongs[0];
      final updatedPlaylist = testPlaylist.removeSong(songToRemove);

      expect(updatedPlaylist.songCount, 1);
      expect(updatedPlaylist.containsSong(songToRemove), false);
    });

    test('Playlist.toMap should convert to correct map', () {
      final map = testPlaylist.toMap();
      expect(map['id'], 1);
      expect(map['name'], '测试歌单');
      expect(map['description'], '这是一个测试歌单');
      // songs 不应包含在 toMap 中
      expect(map.containsKey('songs'), false);
    });

    test('Playlist.fromMap should create correct Playlist object', () {
      final map = {
        'id': 2,
        'name': '新歌单',
        'description': null,
        'cover_path': '/new/cover.jpg',
        'created_at': '2024-04-18T00:00:00.000',
        'updated_at': '2024-04-18T00:00:00.000',
      };

      final playlist = Playlist.fromMap(map);
      expect(playlist.id, 2);
      expect(playlist.name, '新歌单');
      expect(playlist.description, null);
      expect(playlist.songs, null);
    });

    test('Playlist.isEmpty should work correctly', () {
      expect(testPlaylist.isEmpty, false);

      final emptyPlaylist = testPlaylist.copyWith(songs: []);
      expect(emptyPlaylist.isEmpty, true);

      final nullSongsPlaylist = Playlist(
        id: 1,
        name: '测试歌单',
        createdAt: DateTime(2024, 4, 18),
        updatedAt: DateTime(2024, 4, 18),
      );
      expect(nullSongsPlaylist.isEmpty, true);
    });
  });

  group('PlaylistSong Model Tests', () {
    test('PlaylistSong should be created with correct properties', () {
      final playlistSong = PlaylistSong(
        id: 1,
        playlistId: 1,
        songId: 2,
        position: 0,
        addedAt: DateTime(2024, 4, 18),
      );

      expect(playlistSong.id, 1);
      expect(playlistSong.playlistId, 1);
      expect(playlistSong.songId, 2);
      expect(playlistSong.position, 0);
    });

    test('PlaylistSong.toMap should convert correctly', () {
      final playlistSong = PlaylistSong(
        id: 1,
        playlistId: 1,
        songId: 2,
        position: 0,
        addedAt: DateTime(2024, 4, 18),
      );

      final map = playlistSong.toMap();
      expect(map['id'], 1);
      expect(map['playlist_id'], 1);
      expect(map['song_id'], 2);
      expect(map['position'], 0);
    });

    test('PlaylistSong.fromMap should create correct object', () {
      final map = {
        'id': 1,
        'playlist_id': 1,
        'song_id': 2,
        'position': 0,
        'added_at': '2024-04-18T00:00:00.000',
      };

      final playlistSong = PlaylistSong.fromMap(map);
      expect(playlistSong.id, 1);
      expect(playlistSong.playlistId, 1);
      expect(playlistSong.songId, 2);
    });

    test('PlaylistSong equality should work correctly', () {
      final ps1 = PlaylistSong(
        playlistId: 1,
        songId: 2,
        position: 0,
        addedAt: DateTime(2024, 4, 18),
      );

      final ps2 = PlaylistSong(
        playlistId: 1,
        songId: 2,
        position: 1, // position 不同
        addedAt: DateTime(2024, 4, 19),
      );

      expect(ps1, equals(ps2)); // 只比较 playlistId 和 songId
    });
  });
}
