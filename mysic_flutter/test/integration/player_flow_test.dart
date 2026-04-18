import 'package:flutter_test/flutter_test.dart';
import 'package:mysic_flutter/features/player/data/models/song.dart';
import 'package:mysic_flutter/features/player/data/models/playlist.dart';
import 'package:mysic_flutter/features/player/data/services/audio_player_service.dart';

void main() {
  group('Player Flow Integration Tests', () {
    group('播放列表管理流程', () {
      test('应该能够创建和管理播放列表状态', () {
        // 创建测试歌曲列表
        final songs = [
          Song(
            title: 'Song 1',
            artist: 'Artist 1',
            filePath: '/path/to/song1.mp3',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
          Song(
            title: 'Song 2',
            artist: 'Artist 2',
            filePath: '/path/to/song2.mp3',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
          Song(
            title: 'Song 3',
            artist: 'Artist 3',
            filePath: '/path/to/song3.mp3',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        ];

        // 验证歌曲列表
        expect(songs.length, equals(3));
        expect(songs[0].title, equals('Song 1'));
        expect(songs[1].artist, equals('Artist 2'));
      });

      test('应该能够正确计算播放列表总时长', () {
        final songs = [
          Song(
            title: 'Song 1',
            duration: 180000, // 3 分钟
            filePath: '/path/to/song1.mp3',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
          Song(
            title: 'Song 2',
            duration: 240000, // 4 分钟
            filePath: '/path/to/song2.mp3',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        ];

        final totalDuration = songs.fold<int>(
          0,
          (sum, song) => sum + (song.duration ?? 0),
        );

        expect(totalDuration, equals(420000)); // 7 分钟
      });
    });

    group('播放模式测试', () {
      test('应该能够正确切换循环模式', () {
        // 测试循环模式枚举
        expect(MysicLoopMode.off.index, equals(0));
        expect(MysicLoopMode.one.index, equals(1));
        expect(MysicLoopMode.all.index, equals(2));
      });

      test('应该能够正确表示播放器状态', () {
        // 测试播放器状态枚举
        expect(MysicPlayerState.idle.index, equals(0));
        expect(MysicPlayerState.loading.index, equals(1));
        expect(MysicPlayerState.ready.index, equals(2));
        expect(MysicPlayerState.playing.index, equals(3));
        expect(MysicPlayerState.paused.index, equals(4));
        expect(MysicPlayerState.completed.index, equals(5));
        expect(MysicPlayerState.error.index, equals(6));
      });
    });

    group('歌曲数据模型集成', () {
      test('应该能够创建和操作歌曲对象', () {
        final song = Song(
          id: 1,
          title: 'Test Song',
          artist: 'Test Artist',
          album: 'Test Album',
          duration: 180000, // 3 分钟
          filePath: '/path/to/test.mp3',
          albumArtPath: '/path/to/art.jpg',
          dateAdded: 1234567890,
          createdAt: DateTime(2024, 1, 1),
          updatedAt: DateTime(2024, 1, 2),
        );

        // 验证属性
        expect(song.id, equals(1));
        expect(song.title, equals('Test Song'));
        expect(song.artist, equals('Test Artist'));
        expect(song.album, equals('Test Album'));
        expect(song.duration, equals(180000));
        expect(song.formattedDuration, equals('3:00'));
        expect(song.displayArtist, equals('Test Artist'));
        expect(song.displayAlbum, equals('Test Album'));

        // 测试 toMap 和 fromMap
        final map = song.toMap();
        final fromMap = Song.fromMap(map);
        expect(fromMap.title, equals(song.title));
        expect(fromMap.artist, equals(song.artist));
      });

      test('应该能够处理未知艺术家和专辑', () {
        final song = Song(
          title: 'Unknown Song',
          filePath: '/path/to/unknown.mp3',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        expect(song.displayArtist, equals('未知艺术家'));
        expect(song.displayAlbum, equals('未知专辑'));
        expect(song.formattedDuration, equals('--:--'));
      });

      test('应该能够复制并修改歌曲', () {
        final song = Song(
          id: 1,
          title: 'Original',
          filePath: '/path/to/song.mp3',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final modified = song.copyWith(title: 'Modified');

        expect(modified.id, equals(1));
        expect(modified.title, equals('Modified'));
        expect(song.title, equals('Original')); // 原对象不变
      });

      test('应该能够正确比较歌曲', () {
        final song1 = Song(
          id: 1,
          title: 'Song',
          filePath: '/path/to/song.mp3',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final song2 = Song(
          id: 1,
          title: 'Song',
          filePath: '/path/to/song.mp3',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final song3 = Song(
          id: 2,
          title: 'Different Song',
          filePath: '/path/to/different.mp3',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        expect(song1 == song2, isTrue);
        expect(song1 == song3, isFalse);
      });
    });

    group('歌单数据模型集成', () {
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

    group('时间格式化测试', () {
      test('应该能够正确格式化歌曲时长', () {
        final testCases = [
          {'duration': 0, 'expected': '0:00'},
          {'duration': 1000, 'expected': '0:01'},
          {'duration': 60000, 'expected': '1:00'},
          {'duration': 90000, 'expected': '1:30'},
          {'duration': 180000, 'expected': '3:00'},
          {'duration': 3600000, 'expected': '60:00'},
        ];

        for (final testCase in testCases) {
          final song = Song(
            title: 'Test',
            duration: testCase['duration'] as int,
            filePath: '/path/test.mp3',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );
          expect(song.formattedDuration, equals(testCase['expected']));
        }
      });

      test('应该能够正确格式化歌单总时长', () {
        final songs = [
          Song(
            title: 'Song 1',
            duration: 3600000, // 1 小时
            filePath: '/path/1.mp3',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
          Song(
            title: 'Song 2',
            duration: 1800000, // 30 分钟
            filePath: '/path/2.mp3',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        ];

        final playlist = Playlist(
          name: 'Long Playlist',
          songs: songs,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        expect(playlist.formattedTotalDuration, equals('1:30:00'));
      });
    });
  });
}
