import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:mysic_flutter/core/database/database_helper.dart';
import 'package:mysic_flutter/features/player/data/models/song.dart';
import 'package:mysic_flutter/features/player/data/models/playlist.dart';
import 'package:mysic_flutter/features/playlist/data/playlist_repository.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('本地音乐歌单测试', () {
    late PlaylistRepository repository;
    late DatabaseHelper dbHelper;

    setUp(() async {
      dbHelper = DatabaseHelper();
      await dbHelper.clearAllTables();
      repository = PlaylistRepository(dbHelper: dbHelper);
    });

    tearDown() async {
      await dbHelper.close();
    }

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

    test('创建系统歌单', () async {
      final playlist = await repository.createSystemPlaylist(
        name: '本地音乐',
        description: '自动同步',
      );

      expect(playlist.id, isNotNull);
      expect(playlist.name, equals('本地音乐'));
      expect(playlist.isSystem, isTrue);
    });

    test('获取系统歌单', () async {
      await repository.createSystemPlaylist(name: '本地音乐');

      final found = await repository.getSystemPlaylist();

      expect(found, isNotNull);
      expect(found!.isSystem, isTrue);
    });

    test('系统歌单不可删除', () async {
      final playlist = await repository.createSystemPlaylist(name: '本地音乐');

      final success = await repository.deletePlaylist(playlist.id!);

      expect(success, isFalse);

      final found = await repository.getPlaylistById(playlist.id!);
      expect(found, isNotNull);
    });

    test('用户歌单可以删除', () async {
      final playlist = await repository.createPlaylist(name: '用户歌单');

      final success = await repository.deletePlaylist(playlist.id!);

      expect(success, isTrue);
    });

    test('系统歌单排在第一位', () async {
      await repository.createPlaylist(name: '用户歌单A');
      await repository.createSystemPlaylist(name: '本地音乐');
      await repository.createPlaylist(name: '用户歌单B');

      final playlists = await repository.getAllPlaylists();

      expect(playlists.first.isSystem, isTrue);
      expect(playlists.first.name, equals('本地音乐'));
    });

    test('排除歌曲', () async {
      final song = await repository.saveSong(createTestSong('歌曲A'));

      await repository.excludeSong(song.id!);

      final excluded = await repository.getExcludedSongIds();
      expect(excluded.contains(song.id!), isTrue);

      final isExcluded = await repository.isSongExcluded(song.id!);
      expect(isExcluded, isTrue);
    });

    test('恢复被排除的歌曲', () async {
      final song = await repository.saveSong(createTestSong('歌曲A'));
      await repository.excludeSong(song.id!);

      await repository.restoreSong(song.id!);

      final excluded = await repository.getExcludedSongIds();
      expect(excluded.contains(song.id!), isFalse);
    });

    test('删除歌曲时清理排除记录', () async {
      final song = await repository.saveSong(createTestSong('歌曲A'));
      await repository.excludeSong(song.id!);

      await repository.deleteSong(song.id!);

      final excluded = await repository.getExcludedSongIds();
      expect(excluded.contains(song.id!), isFalse);
    });
  });
}
