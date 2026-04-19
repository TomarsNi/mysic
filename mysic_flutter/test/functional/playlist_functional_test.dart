import 'package:flutter_test/flutter_test.dart';
import 'package:mysic_flutter/features/player/data/models/song.dart';
import 'package:mysic_flutter/features/player/data/models/playlist.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('歌单管理功能测试', () {
    group('Playlist 模型测试', () {
      test('创建歌单应正确', () {
        final now = DateTime.now();
        final playlist = Playlist(
          id: 1,
          name: '我的歌单',
          description: '测试歌单描述',
          coverPath: '/path/to/cover.jpg',
          createdAt: now,
          updatedAt: now,
        );

        expect(playlist.id, 1);
        expect(playlist.name, '我的歌单');
        expect(playlist.description, '测试歌单描述');
        expect(playlist.coverPath, '/path/to/cover.jpg');
        expect(playlist.createdAt, now);
        expect(playlist.updatedAt, now);
        expect(playlist.songs, isNull);
      });

      test('歌单歌曲数量应正确计算', () {
        final songs = [
          Song(
            id: 1,
            title: '歌曲1',
            artist: '艺术家1',
            duration: 180000,
            filePath: '/path/song1.mp3',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
          Song(
            id: 2,
            title: '歌曲2',
            artist: '艺术家2',
            duration: 240000,
            filePath: '/path/song2.mp3',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        ];

        final playlist = Playlist(
          id: 1,
          name: '我的歌单',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          songs: songs,
        );

        expect(playlist.songCount, 2);
        expect(playlist.isEmpty, isFalse);
      });

      test('空歌单应正确判断', () {
        final playlist = Playlist(
          id: 1,
          name: '空歌单',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        expect(playlist.songCount, 0);
        expect(playlist.isEmpty, isTrue);
      });

      test('歌单总时长应正确计算', () {
        final songs = [
          Song(
            id: 1,
            title: '歌曲1',
            artist: '艺术家1',
            duration: 180000, // 3分钟
            filePath: '/path/song1.mp3',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
          Song(
            id: 2,
            title: '歌曲2',
            artist: '艺术家2',
            duration: 240000, // 4分钟
            filePath: '/path/song2.mp3',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        ];

        final playlist = Playlist(
          id: 1,
          name: '我的歌单',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          songs: songs,
        );

        expect(playlist.totalDuration, 420000); // 7分钟
        expect(playlist.formattedTotalDuration, '7:00');
      });

      test('歌单应可添加歌曲', () {
        final playlist = Playlist(
          id: 1,
          name: '我的歌单',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final song = Song(
          id: 1,
          title: '测试歌曲',
          artist: '艺术家',
          duration: 180000,
          filePath: '/path/song.mp3',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final updatedPlaylist = playlist.addSong(song);
        expect(updatedPlaylist.songCount, 1);
        expect(updatedPlaylist.containsSong(song), isTrue);
      });

      test('歌单应可移除歌曲', () {
        final song = Song(
          id: 1,
          title: '测试歌曲',
          artist: '艺术家',
          duration: 180000,
          filePath: '/path/song.mp3',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final playlist = Playlist(
          id: 1,
          name: '我的歌单',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          songs: [song],
        );

        final updatedPlaylist = playlist.removeSong(song);
        expect(updatedPlaylist.songCount, 0);
        expect(updatedPlaylist.containsSong(song), isFalse);
      });

      test('重复添加歌曲应被忽略', () {
        final song = Song(
          id: 1,
          title: '测试歌曲',
          artist: '艺术家',
          duration: 180000,
          filePath: '/path/song.mp3',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final playlist = Playlist(
          id: 1,
          name: '我的歌单',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          songs: [song],
        );

        final updatedPlaylist = playlist.addSong(song);
        expect(updatedPlaylist.songCount, 1); // 仍然是1首
      });

      test('歌单 copyWith 应正确工作', () {
        final playlist = Playlist(
          id: 1,
          name: '原名称',
          description: '原描述',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final updatedPlaylist = playlist.copyWith(
          name: '新名称',
          description: '新描述',
        );

        expect(updatedPlaylist.id, 1);
        expect(updatedPlaylist.name, '新名称');
        expect(updatedPlaylist.description, '新描述');
      });
    });

    group('PlaylistSong 关联模型测试', () {
      test('创建歌单-歌曲关联应正确', () {
        final now = DateTime.now();
        final playlistSong = PlaylistSong(
          id: 1,
          playlistId: 1,
          songId: 100,
          position: 0,
          addedAt: now,
        );

        expect(playlistSong.id, 1);
        expect(playlistSong.playlistId, 1);
        expect(playlistSong.songId, 100);
        expect(playlistSong.position, 0);
        expect(playlistSong.addedAt, now);
      });

      test('PlaylistSong 相等性应正确', () {
        final now = DateTime.now();
        final ps1 = PlaylistSong(
          playlistId: 1,
          songId: 100,
          position: 0,
          addedAt: now,
        );
        final ps2 = PlaylistSong(
          playlistId: 1,
          songId: 100,
          position: 1,
          addedAt: now,
        );

        expect(ps1 == ps2, isTrue); // 相同的 playlistId 和 songId
      });
    });

    group('歌单 CRUD 操作测试', () {
      test('创建歌单应正确', () {
        final playlist = Playlist(
          name: '新建歌单',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        expect(playlist.id, isNull); // 未保存到数据库
        expect(playlist.name, '新建歌单');
        expect(playlist.isEmpty, isTrue);
      });

      test('歌单重命名应正确', () {
        final playlist = Playlist(
          id: 1,
          name: '原名称',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final renamedPlaylist = playlist.copyWith(name: '新名称');
        expect(renamedPlaylist.name, '新名称');
        expect(renamedPlaylist.id, 1);
      });

      test('歌单 toMap 应正确转换', () {
        final now = DateTime(2024, 4, 18, 12, 0, 0);
        final playlist = Playlist(
          id: 1,
          name: '测试歌单',
          description: '描述',
          coverPath: '/cover.jpg',
          createdAt: now,
          updatedAt: now,
        );

        final map = playlist.toMap();

        expect(map['id'], 1);
        expect(map['name'], '测试歌单');
        expect(map['description'], '描述');
        expect(map['cover_path'], '/cover.jpg');
        expect(map['created_at'], now.toIso8601String());
        expect(map['updated_at'], now.toIso8601String());
      });

      test('歌单 fromMap 应正确创建', () {
        final now = DateTime(2024, 4, 18, 12, 0, 0);
        final map = {
          'id': 1,
          'name': '测试歌单',
          'description': '描述',
          'cover_path': '/cover.jpg',
          'created_at': now.toIso8601String(),
          'updated_at': now.toIso8601String(),
        };

        final playlist = Playlist.fromMap(map);

        expect(playlist.id, 1);
        expect(playlist.name, '测试歌单');
        expect(playlist.description, '描述');
        expect(playlist.coverPath, '/cover.jpg');
      });
    });

    group('歌单歌曲管理测试', () {
      test('添加歌曲到歌单应正确', () {
        final song = Song(
          id: 1,
          title: '测试歌曲',
          artist: '艺术家',
          duration: 180000,
          filePath: '/path/song.mp3',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final playlist = Playlist(
          id: 1,
          name: '我的歌单',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final updatedPlaylist = playlist.addSong(song);

        expect(updatedPlaylist.songCount, 1);
        expect(updatedPlaylist.songs?.first.id, 1);
        expect(updatedPlaylist.songs?.first.title, '测试歌曲');
      });

      test('从歌单移除歌曲应正确', () {
        final song1 = Song(
          id: 1,
          title: '歌曲1',
          artist: '艺术家1',
          duration: 180000,
          filePath: '/path/song1.mp3',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final song2 = Song(
          id: 2,
          title: '歌曲2',
          artist: '艺术家2',
          duration: 240000,
          filePath: '/path/song2.mp3',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final playlist = Playlist(
          id: 1,
          name: '我的歌单',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          songs: [song1, song2],
        );

        final updatedPlaylist = playlist.removeSong(song1);

        expect(updatedPlaylist.songCount, 1);
        expect(updatedPlaylist.songs?.first.id, 2);
      });

      test('检查歌曲是否在歌单中应正确', () {
        final song = Song(
          id: 1,
          title: '测试歌曲',
          artist: '艺术家',
          duration: 180000,
          filePath: '/path/song.mp3',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final otherSong = Song(
          id: 2,
          title: '其他歌曲',
          artist: '艺术家',
          duration: 180000,
          filePath: '/path/other.mp3',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final playlist = Playlist(
          id: 1,
          name: '我的歌单',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          songs: [song],
        );

        expect(playlist.containsSong(song), isTrue);
        expect(playlist.containsSong(otherSong), isFalse);
      });
    });

    group('歌单统计功能测试', () {
      test('歌单歌曲数量统计应正确', () {
        final songs = List.generate(
          10,
          (i) => Song(
            id: i,
            title: '歌曲 $i',
            artist: '艺术家',
            duration: 180000,
            filePath: '/path/song_$i.mp3',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );

        final playlist = Playlist(
          id: 1,
          name: '我的歌单',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          songs: songs,
        );

        expect(playlist.songCount, 10);
      });

      test('歌单时长格式化应正确', () {
        // 1小时5分30秒
        final songs = [
          Song(
            id: 1,
            title: '歌曲1',
            artist: '艺术家',
            duration: 3600000, // 1小时
            filePath: '/path/song1.mp3',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
          Song(
            id: 2,
            title: '歌曲2',
            artist: '艺术家',
            duration: 330000, // 5分30秒
            filePath: '/path/song2.mp3',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        ];

        final playlist = Playlist(
          id: 1,
          name: '我的歌单',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          songs: songs,
        );

        expect(playlist.totalDuration, 3930000);
        expect(playlist.formattedTotalDuration, '1:05:30');
      });
    });
  });
}
