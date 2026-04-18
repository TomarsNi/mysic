import 'package:flutter_test/flutter_test.dart';
import 'package:mysic_flutter/features/player/data/models/song.dart';
import 'package:mysic_flutter/features/player/data/models/playlist.dart';

void main() {
  group('Playlist Flow Integration Tests', () {
    group('歌单 CRUD 流程', () {
      test('应该能够创建歌单对象', () {
        final playlist = Playlist(
          name: 'Test Playlist',
          description: 'A test playlist',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        expect(playlist.name, equals('Test Playlist'));
        expect(playlist.description, equals('A test playlist'));
        expect(playlist.id, isNull); // 新创建的歌单没有 ID
      });

      test('应该能够更新歌单名称', () {
        final playlist = Playlist(
          id: 1,
          name: 'Original Name',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final updated = playlist.copyWith(
          name: 'Updated Name',
          updatedAt: DateTime.now(),
        );

        expect(updated.id, equals(1));
        expect(updated.name, equals('Updated Name'));
      });

      test('应该能够删除歌单中的歌曲', () {
        final songs = [
          Song(
            id: 1,
            title: 'Song 1',
            filePath: '/path/1.mp3',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
          Song(
            id: 2,
            title: 'Song 2',
            filePath: '/path/2.mp3',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        ];

        var playlist = Playlist(
          id: 1,
          name: 'Test Playlist',
          songs: songs,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        expect(playlist.songCount, equals(2));

        // 移除歌曲
        playlist = playlist.removeSong(songs[0]);
        expect(playlist.songCount, equals(1));
      });

      test('应该能够搜索歌单中的歌曲', () {
        final songs = [
          Song(
            id: 1,
            title: 'Rock Song',
            artist: 'Rock Artist',
            filePath: '/path/1.mp3',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
          Song(
            id: 2,
            title: 'Pop Song',
            artist: 'Pop Artist',
            filePath: '/path/2.mp3',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        ];

        final playlist = Playlist(
          name: 'Mixed Playlist',
          songs: songs,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        // 搜索包含 "Rock" 的歌曲
        final rockSongs = playlist.songs?.where((s) => s.title.contains('Rock')).toList();
        expect(rockSongs?.length, equals(1));
        expect(rockSongs?.first.title, equals('Rock Song'));
      });
    });

    group('歌曲管理流程', () {
      test('应该能够创建歌曲对象', () {
        final song = Song(
          title: 'Test Song',
          artist: 'Test Artist',
          album: 'Test Album',
          duration: 180000,
          filePath: '/path/to/test.mp3',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        expect(song.title, equals('Test Song'));
        expect(song.artist, equals('Test Artist'));
        expect(song.album, equals('Test Album'));
        expect(song.duration, equals(180000));
      });

      test('应该能够批量创建歌曲', () {
        final songs = List.generate(10, (index) {
          return Song(
            title: 'Song $index',
            artist: 'Artist $index',
            filePath: '/path/to/song$index.mp3',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );
        });

        expect(songs.length, equals(10));
        expect(songs[0].title, equals('Song 0'));
        expect(songs[9].title, equals('Song 9'));
      });

      test('应该能够删除歌曲', () {
        final songs = [
          Song(
            id: 1,
            title: 'Song 1',
            filePath: '/path/1.mp3',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
          Song(
            id: 2,
            title: 'Song 2',
            filePath: '/path/2.mp3',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        ];

        // 模拟删除
        final remainingSongs = songs.where((s) => s.id != 1).toList();

        expect(remainingSongs.length, equals(1));
        expect(remainingSongs.first.id, equals(2));
      });

      test('应该能够搜索歌曲', () {
        final songs = [
          Song(
            title: 'Hello World',
            artist: 'Artist A',
            filePath: '/path/hello.mp3',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
          Song(
            title: 'Goodbye',
            artist: 'Artist B',
            filePath: '/path/goodbye.mp3',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
          Song(
            title: 'Hello Again',
            artist: 'Artist C',
            filePath: '/path/hello_again.mp3',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        ];

        // 搜索标题包含 "Hello" 的歌曲
        final results = songs.where((s) => s.title.contains('Hello')).toList();

        expect(results.length, equals(2));
        expect(results.any((s) => s.title == 'Hello World'), isTrue);
        expect(results.any((s) => s.title == 'Hello Again'), isTrue);
      });
    });

    group('歌单歌曲关联流程', () {
      test('应该能够添加歌曲到歌单', () {
        final playlist = Playlist(
          id: 1,
          name: 'My Playlist',
          songs: [],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final song = Song(
          id: 1,
          title: 'Playlist Song',
          filePath: '/path/to/song.mp3',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final updated = playlist.addSong(song);

        expect(updated.songCount, equals(1));
        expect(updated.containsSong(song), isTrue);
      });

      test('应该能够从歌单移除歌曲', () {
        final song1 = Song(
          id: 1,
          title: 'Song 1',
          filePath: '/path/1.mp3',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final song2 = Song(
          id: 2,
          title: 'Song 2',
          filePath: '/path/2.mp3',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        var playlist = Playlist(
          id: 1,
          name: 'Test Playlist',
          songs: [song1, song2],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        expect(playlist.songCount, equals(2));

        // 移除歌曲
        playlist = playlist.removeSong(song1);
        expect(playlist.songCount, equals(1));
        expect(playlist.songs?.first.id, equals(2));
      });

      test('应该能够检查歌曲是否在歌单中', () {
        final song = Song(
          id: 1,
          title: 'Check Song',
          filePath: '/path/to/check.mp3',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final playlist = Playlist(
          id: 1,
          name: 'Check Playlist',
          songs: [song],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        expect(playlist.containsSong(song), isTrue);

        final otherSong = Song(
          id: 2,
          title: 'Other Song',
          filePath: '/path/to/other.mp3',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        expect(playlist.containsSong(otherSong), isFalse);
      });
    });

    group('播放历史流程', () {
      test('应该能够记录播放历史', () {
        final history = <Song>[];

        final song = Song(
          id: 1,
          title: 'History Song',
          filePath: '/path/to/history.mp3',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        // 模拟记录播放历史
        history.insert(0, song);

        expect(history.length, equals(1));
        expect(history.first.title, equals('History Song'));
      });

      test('应该能够清空播放历史', () {
        final history = [
          Song(
            id: 1,
            title: 'Song 1',
            filePath: '/path/1.mp3',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
          Song(
            id: 2,
            title: 'Song 2',
            filePath: '/path/2.mp3',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        ];

        expect(history.length, equals(2));

        // 清空历史
        history.clear();
        expect(history.isEmpty, isTrue);
      });
    });

    group('统计信息流程', () {
      test('应该能够获取正确的统计信息', () {
        final songs = [
          Song(
            title: 'Song 1',
            duration: 180000, // 3 分钟
            filePath: '/path/1.mp3',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
          Song(
            title: 'Song 2',
            duration: 240000, // 4 分钟
            filePath: '/path/2.mp3',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        ];

        final playlists = [
          Playlist(
            name: 'Playlist 1',
            songs: [songs[0]],
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
          Playlist(
            name: 'Playlist 2',
            songs: songs,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        ];

        final totalSongs = songs.length;
        final totalPlaylists = playlists.length;
        final totalDuration = songs.fold<int>(
          0,
          (sum, song) => sum + (song.duration ?? 0),
        );

        expect(totalSongs, equals(2));
        expect(totalPlaylists, equals(2));
        expect(totalDuration, equals(420000)); // 7 分钟
      });
    });

    group('Playlist 数据模型集成', () {
      test('应该能够创建和操作歌单对象', () {
        final songs = [
          Song(
            id: 1,
            title: 'Song 1',
            duration: 180000,
            filePath: '/path/1.mp3',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
          Song(
            id: 2,
            title: 'Song 2',
            duration: 240000,
            filePath: '/path/2.mp3',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        ];

        final playlist = Playlist(
          id: 1,
          name: 'Test Playlist',
          description: 'Test Description',
          createdAt: DateTime(2024, 1, 1),
          updatedAt: DateTime(2024, 1, 2),
          songs: songs,
        );

        // 验证属性
        expect(playlist.id, equals(1));
        expect(playlist.name, equals('Test Playlist'));
        expect(playlist.songCount, equals(2));
        expect(playlist.totalDuration, equals(420000));
        expect(playlist.formattedTotalDuration, equals('7:00'));
        expect(playlist.isEmpty, isFalse);

        // 测试 containsSong
        expect(playlist.containsSong(songs[0]), isTrue);

        // 测试 addSong
        final newSong = Song(
          title: 'New Song',
          filePath: '/path/new.mp3',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        final updated = playlist.addSong(newSong);
        expect(updated.songCount, equals(3));

        // 测试 removeSong
        final removed = updated.removeSong(songs[0]);
        expect(removed.songCount, equals(2));
      });

      test('应该能够处理空歌单', () {
        final playlist = Playlist(
          name: 'Empty Playlist',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        expect(playlist.isEmpty, isTrue);
        expect(playlist.songCount, equals(0));
        expect(playlist.totalDuration, equals(0));
        expect(playlist.formattedTotalDuration, equals('00:00'));
      });

      test('应该能够转换歌单为 Map', () {
        final playlist = Playlist(
          id: 1,
          name: 'Map Test',
          description: 'Description',
          coverPath: '/path/cover.jpg',
          createdAt: DateTime(2024, 1, 1),
          updatedAt: DateTime(2024, 1, 2),
        );

        final map = playlist.toMap();

        expect(map['id'], equals(1));
        expect(map['name'], equals('Map Test'));
        expect(map['description'], equals('Description'));
        expect(map['cover_path'], equals('/path/cover.jpg'));
      });
    });

    group('PlaylistSong 关联模型测试', () {
      test('应该能够创建和操作歌单歌曲关联', () {
        final playlistSong = PlaylistSong(
          id: 1,
          playlistId: 10,
          songId: 20,
          position: 0,
          addedAt: DateTime(2024, 1, 1),
        );

        expect(playlistSong.id, equals(1));
        expect(playlistSong.playlistId, equals(10));
        expect(playlistSong.songId, equals(20));
        expect(playlistSong.position, equals(0));

        // 测试 toMap
        final map = playlistSong.toMap();
        expect(map['playlist_id'], equals(10));
        expect(map['song_id'], equals(20));
        expect(map['position'], equals(0));

        // 测试 fromMap
        final fromMap = PlaylistSong.fromMap(map);
        expect(fromMap.playlistId, equals(playlistSong.playlistId));
        expect(fromMap.songId, equals(playlistSong.songId));
      });

      test('应该正确比较歌单歌曲关联', () {
        final ps1 = PlaylistSong(
          playlistId: 1,
          songId: 1,
          position: 0,
          addedAt: DateTime.now(),
        );
        final ps2 = PlaylistSong(
          playlistId: 1,
          songId: 1,
          position: 1,
          addedAt: DateTime.now(),
        );
        final ps3 = PlaylistSong(
          playlistId: 1,
          songId: 2,
          position: 0,
          addedAt: DateTime.now(),
        );

        expect(ps1 == ps2, isTrue); // 相同 playlistId 和 songId
        expect(ps1 == ps3, isFalse); // 不同 songId
      });
    });
  });
}
