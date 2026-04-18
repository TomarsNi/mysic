import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:mysic_flutter/core/database/database_helper.dart';
import 'package:mysic_flutter/features/player/data/models/song.dart';
import 'package:mysic_flutter/features/player/data/models/playlist.dart';
import 'package:mysic_flutter/features/playlist/data/playlist_repository.dart';

void main() {
  // 初始化 sqflite_ffi 用于测试
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('PlaylistRepository 歌单操作测试', () {
    late PlaylistRepository repository;
    late DatabaseHelper dbHelper;

    setUp(() async {
      dbHelper = DatabaseHelper();
      // 清空数据库
      await dbHelper.clearAllTables();
      repository = PlaylistRepository(dbHelper: dbHelper);
    });

    tearDown(() async {
      await dbHelper.close();
    });

    test('创建歌单成功', () async {
      final playlist = await repository.createPlaylist(
        name: '我喜欢的',
        description: '收藏的歌曲',
      );

      expect(playlist.id, isNotNull);
      expect(playlist.name, equals('我喜欢的'));
      expect(playlist.description, equals('收藏的歌曲'));
      expect(playlist.songs, isEmpty);
    });

    test('获取所有歌单', () async {
      // 创建多个歌单
      await repository.createPlaylist(name: '歌单1');
      await repository.createPlaylist(name: '歌单2');
      await repository.createPlaylist(name: '歌单3');

      final playlists = await repository.getAllPlaylists();

      expect(playlists.length, equals(3));
      // 按更新时间倒序
      expect(playlists[0].name, equals('歌单3'));
      expect(playlists[1].name, equals('歌单2'));
      expect(playlists[2].name, equals('歌单1'));
    });

    test('根据 ID 获取歌单', () async {
      final created = await repository.createPlaylist(
        name: '测试歌单',
        description: '描述',
      );

      final found = await repository.getPlaylistById(created.id!);

      expect(found, isNotNull);
      expect(found!.name, equals('测试歌单'));
      expect(found.description, equals('描述'));
    });

    test('更新歌单名称', () async {
      final playlist = await repository.createPlaylist(name: '旧名称');

      final success = await repository.updatePlaylistName(
        playlist.id!,
        '新名称',
      );

      expect(success, isTrue);

      final updated = await repository.getPlaylistById(playlist.id!);
      expect(updated!.name, equals('新名称'));
    });

    test('删除歌单', () async {
      final playlist = await repository.createPlaylist(name: '待删除');

      final success = await repository.deletePlaylist(playlist.id!);

      expect(success, isTrue);

      final found = await repository.getPlaylistById(playlist.id!);
      expect(found, isNull);
    });

    test('搜索歌单', () async {
      await repository.createPlaylist(name: '流行音乐');
      await repository.createPlaylist(name: '古典音乐');
      await repository.createPlaylist(name: '摇滚');

      final results = await repository.searchPlaylists('音乐');

      expect(results.length, equals(2));
      expect(results.any((p) => p.name == '流行音乐'), isTrue);
      expect(results.any((p) => p.name == '古典音乐'), isTrue);
    });

    test('获取歌单数量', () async {
      await repository.createPlaylist(name: '歌单1');
      await repository.createPlaylist(name: '歌单2');

      final count = await repository.getPlaylistCount();

      expect(count, equals(2));
    });
  });

  group('PlaylistRepository 歌曲操作测试', () {
    late PlaylistRepository repository;
    late DatabaseHelper dbHelper;

    setUp(() async {
      dbHelper = DatabaseHelper();
      await dbHelper.clearAllTables();
      repository = PlaylistRepository(dbHelper: dbHelper);
    });

    tearDown(() async {
      await dbHelper.close();
    });

    Song createTestSong({String title = '测试歌曲', String? path}) {
      final now = DateTime.now();
      return Song(
        title: title,
        artist: '测试艺术家',
        album: '测试专辑',
        duration: 180000,
        filePath: path ?? '/test/song_$title.mp3',
        createdAt: now,
        updatedAt: now,
      );
    }

    test('保存歌曲到数据库', () async {
      final song = createTestSong();

      final saved = await repository.saveSong(song);

      expect(saved.id, isNotNull);
      expect(saved.title, equals('测试歌曲'));
      expect(saved.artist, equals('测试艺术家'));
    });

    test('重复保存相同路径的歌曲返回已存在的记录', () async {
      final song = createTestSong(path: '/test/same.mp3');

      final first = await repository.saveSong(song);
      final second = await repository.saveSong(song);

      expect(first.id, equals(second.id));
    });

    test('获取所有歌曲', () async {
      await repository.saveSong(createTestSong(title: '歌曲A', path: '/a.mp3'));
      await repository.saveSong(createTestSong(title: '歌曲B', path: '/b.mp3'));

      final songs = await repository.getAllSongs();

      expect(songs.length, equals(2));
    });

    test('根据 ID 获取歌曲', () async {
      final saved = await repository.saveSong(createTestSong());

      final found = await repository.getSongById(saved.id!);

      expect(found, isNotNull);
      expect(found!.title, equals('测试歌曲'));
    });

    test('根据路径获取歌曲', () async {
      final saved = await repository.saveSong(
        createTestSong(path: '/unique/path.mp3'),
      );

      final found = await repository.getSongByPath('/unique/path.mp3');

      expect(found, isNotNull);
      expect(found!.id, equals(saved.id));
    });

    test('搜索歌曲', () async {
      await repository.saveSong(
        createTestSong(title: '晴天', path: '/qingtian.mp3'),
      );
      await repository.saveSong(
        createTestSong(title: '阴天', path: '/yintian.mp3'),
      );
      await repository.saveSong(
        createTestSong(title: '稻香', path: '/daoxiang.mp3'),
      );

      final results = await repository.searchSongs('天');

      expect(results.length, equals(2));
    });

    test('删除歌曲', () async {
      final song = await repository.saveSong(createTestSong());

      final success = await repository.deleteSong(song.id!);

      expect(success, isTrue);

      final found = await repository.getSongById(song.id!);
      expect(found, isNull);
    });

    test('获取歌曲数量', () async {
      await repository.saveSong(createTestSong(path: '/a.mp3'));
      await repository.saveSong(createTestSong(path: '/b.mp3'));

      final count = await repository.getSongCount();

      expect(count, equals(2));
    });
  });

  group('PlaylistRepository 歌单歌曲关联测试', () {
    late PlaylistRepository repository;
    late DatabaseHelper dbHelper;

    setUp(() async {
      dbHelper = DatabaseHelper();
      await dbHelper.clearAllTables();
      repository = PlaylistRepository(dbHelper: dbHelper);
    });

    tearDown(() async {
      await dbHelper.close();
    });

    Song createTestSong(String title) {
      final now = DateTime.now();
      return Song(
        title: title,
        artist: '艺术家',
        duration: 180000,
        filePath: '/test/$title.mp3',
        createdAt: now,
        updatedAt: now,
      );
    }

    test('添加歌曲到歌单', () async {
      final playlist = await repository.createPlaylist(name: '测试歌单');
      final song = await repository.saveSong(createTestSong('歌曲A'));

      final success = await repository.addSongToPlaylist(playlist.id!, song);

      expect(success, isTrue);

      final songs = await repository.getSongsInPlaylist(playlist.id!);
      expect(songs.length, equals(1));
      expect(songs[0].title, equals('歌曲A'));
    });

    test('重复添加相同歌曲到歌单失败', () async {
      final playlist = await repository.createPlaylist(name: '测试歌单');
      final song = await repository.saveSong(createTestSong('歌曲A'));

      await repository.addSongToPlaylist(playlist.id!, song);
      final second = await repository.addSongToPlaylist(playlist.id!, song);

      expect(second, isFalse);

      final songs = await repository.getSongsInPlaylist(playlist.id!);
      expect(songs.length, equals(1));
    });

    test('批量添加歌曲到歌单', () async {
      final playlist = await repository.createPlaylist(name: '测试歌单');
      final songs = [
        await repository.saveSong(createTestSong('歌曲A')),
        await repository.saveSong(createTestSong('歌曲B')),
        await repository.saveSong(createTestSong('歌曲C')),
      ];

      final count = await repository.addSongsToPlaylist(playlist.id!, songs);

      expect(count, equals(3));

      final playlistSongs = await repository.getSongsInPlaylist(playlist.id!);
      expect(playlistSongs.length, equals(3));
    });

    test('从歌单移除歌曲', () async {
      final playlist = await repository.createPlaylist(name: '测试歌单');
      final song = await repository.saveSong(createTestSong('歌曲A'));
      await repository.addSongToPlaylist(playlist.id!, song);

      final success = await repository.removeSongFromPlaylist(
        playlist.id!,
        song.id!,
      );

      expect(success, isTrue);

      final songs = await repository.getSongsInPlaylist(playlist.id!);
      expect(songs, isEmpty);
    });

    test('检查歌曲是否在歌单中', () async {
      final playlist = await repository.createPlaylist(name: '测试歌单');
      final song = await repository.saveSong(createTestSong('歌曲A'));

      final before = await repository.isSongInPlaylist(playlist.id!, song.id!);
      expect(before, isFalse);

      await repository.addSongToPlaylist(playlist.id!, song);

      final after = await repository.isSongInPlaylist(playlist.id!, song.id!);
      expect(after, isTrue);
    });

    test('获取歌单歌曲数量', () async {
      final playlist = await repository.createPlaylist(name: '测试歌单');
      final songs = [
        await repository.saveSong(createTestSong('歌曲A')),
        await repository.saveSong(createTestSong('歌曲B')),
      ];
      await repository.addSongsToPlaylist(playlist.id!, songs);

      final count = await repository.getPlaylistSongCount(playlist.id!);

      expect(count, equals(2));
    });

    test('获取歌单及歌曲', () async {
      final playlist = await repository.createPlaylist(name: '测试歌单');
      final songs = [
        await repository.saveSong(createTestSong('歌曲A')),
        await repository.saveSong(createTestSong('歌曲B')),
      ];
      await repository.addSongsToPlaylist(playlist.id!, songs);

      final found = await repository.getPlaylistById(playlist.id!);

      expect(found!.songs!.length, equals(2));
    });

    test('删除歌单时同时删除歌曲关联', () async {
      final playlist = await repository.createPlaylist(name: '测试歌单');
      final song = await repository.saveSong(createTestSong('歌曲A'));
      await repository.addSongToPlaylist(playlist.id!, song);

      await repository.deletePlaylist(playlist.id!);

      // 歌曲应该仍然存在
      final songFound = await repository.getSongById(song.id!);
      expect(songFound, isNotNull);
    });
  });

  group('PlaylistRepository 播放历史测试', () {
    late PlaylistRepository repository;
    late DatabaseHelper dbHelper;

    setUp(() async {
      dbHelper = DatabaseHelper();
      await dbHelper.clearAllTables();
      repository = PlaylistRepository(dbHelper: dbHelper);
    });

    tearDown(() async {
      await dbHelper.close();
    });

    Song createTestSong(String title) {
      final now = DateTime.now();
      return Song(
        title: title,
        artist: '艺术家',
        duration: 180000,
        filePath: '/test/$title.mp3',
        createdAt: now,
        updatedAt: now,
      );
    }

    test('记录播放历史', () async {
      final song = await repository.saveSong(createTestSong('歌曲A'));

      await repository.recordPlayHistory(song.id!, playDuration: 60000);

      final history = await repository.getPlayHistory();

      expect(history.length, equals(1));
      expect(history[0].title, equals('歌曲A'));
    });

    test('获取播放历史按时间倒序', () async {
      final songA = await repository.saveSong(createTestSong('歌曲A'));
      final songB = await repository.saveSong(createTestSong('歌曲B'));

      await repository.recordPlayHistory(songA.id!);
      await Future.delayed(Duration(milliseconds: 10));
      await repository.recordPlayHistory(songB.id!);

      final history = await repository.getPlayHistory();

      expect(history[0].title, equals('歌曲B'));
      expect(history[1].title, equals('歌曲A'));
    });

    test('清空播放历史', () async {
      final song = await repository.saveSong(createTestSong('歌曲A'));
      await repository.recordPlayHistory(song.id!);

      await repository.clearPlayHistory();

      final history = await repository.getPlayHistory();
      expect(history, isEmpty);
    });
  });
}
