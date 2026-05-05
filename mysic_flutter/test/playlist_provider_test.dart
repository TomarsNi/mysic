import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:mysic_flutter/core/database/database_helper.dart';
import 'package:mysic_flutter/features/player/data/models/song.dart';
import 'package:mysic_flutter/features/player/data/models/playlist.dart';
import 'package:mysic_flutter/features/playlist/data/playlist_repository.dart';
import 'package:mysic_flutter/features/playlist/presentation/providers/playlist_provider.dart';

void main() {
  // 初始化 sqflite_ffi 用于测试
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('PlaylistProvider 基础测试', () {
    late PlaylistProvider provider;
    late DatabaseHelper dbHelper;

    setUp(() async {
      dbHelper = DatabaseHelper();
      await dbHelper.clearAllTables();
      provider = PlaylistProvider(
        repository: PlaylistRepository(dbHelper: dbHelper),
      );
      // 等待初始加载完成
      await Future.delayed(Duration(milliseconds: 100));
    });

    tearDown(() async {
      await dbHelper.close();
    });

    test('初始状态正确', () async {
      // 等待加载完成
      await Future.delayed(Duration(milliseconds: 200));
      expect(provider.isLoading, isFalse);
      expect(provider.error, isNull);
      // 系统歌单会自动创建
      expect(provider.playlists.length, equals(1));
      expect(provider.playlists.first.name, equals('本地音乐'));
      expect(provider.systemPlaylistId, isNotNull);
      expect(provider.allSongs, isEmpty);
      expect(provider.hasPlaylists, isTrue);
      expect(provider.hasSongs, isFalse);
    });

    test('创建歌单成功', () async {
      final playlist = await provider.createPlaylist(
        name: '测试歌单',
        description: '描述',
      );

      expect(playlist, isNotNull);
      expect(playlist!.name, equals('测试歌单'));
      // 系统歌单 + 新创建的歌单
      expect(provider.playlists.length, equals(2));
      expect(provider.hasPlaylists, isTrue);
    });

    test('获取歌单统计信息', () async {
      await provider.createPlaylist(name: '歌单1');
      await provider.createPlaylist(name: '歌单2');

      final stats = provider.getStatistics();

      // 系统歌单 + 歌单1 + 歌单2 = 3
      expect(stats['totalPlaylists'], equals(3));
      expect(stats['totalSongs'], equals(0));
    });
  });

  group('PlaylistProvider 歌单操作测试', () {
    late PlaylistProvider provider;
    late DatabaseHelper dbHelper;

    setUp(() async {
      dbHelper = DatabaseHelper();
      await dbHelper.clearAllTables();
      provider = PlaylistProvider(
        repository: PlaylistRepository(dbHelper: dbHelper),
      );
      await Future.delayed(Duration(milliseconds: 100));
    });

    tearDown(() async {
      await dbHelper.close();
    });

    test('选择歌单', () async {
      final playlist = await provider.createPlaylist(name: '测试歌单');
      expect(playlist, isNotNull);

      await provider.selectPlaylist(playlist!.id!);

      expect(provider.selectedPlaylist, isNotNull);
      expect(provider.selectedPlaylist!.name, equals('测试歌单'));
    });

    test('取消选择歌单', () async {
      final playlist = await provider.createPlaylist(name: '测试歌单');
      expect(playlist, isNotNull);

      await provider.selectPlaylist(playlist!.id!);
      expect(provider.selectedPlaylist, isNotNull);

      provider.deselectPlaylist();
      expect(provider.selectedPlaylist, isNull);
      expect(provider.selectedPlaylistSongs, isEmpty);
    });

    test('更新歌单名称', () async {
      final playlist = await provider.createPlaylist(name: '旧名称');
      expect(playlist, isNotNull);

      final success = await provider.updatePlaylistName(playlist!.id!, '新名称');

      expect(success, isTrue);
      expect(provider.playlists.first.name, equals('新名称'));
    });

    test('删除歌单', () async {
      final playlist = await provider.createPlaylist(name: '待删除');
      expect(playlist, isNotNull);

      final success = await provider.deletePlaylist(playlist!.id!);

      expect(success, isTrue);
      // 只有系统歌单剩余
      expect(provider.playlists.length, equals(1));
      expect(provider.playlists.first.name, equals('本地音乐'));
    });

    test('删除选中的歌单后清除选择', () async {
      final playlist = await provider.createPlaylist(name: '待删除');
      expect(playlist, isNotNull);

      await provider.selectPlaylist(playlist!.id!);
      expect(provider.selectedPlaylist, isNotNull);

      await provider.deletePlaylist(playlist!.id!);
      expect(provider.selectedPlaylist, isNull);
    });
  });

  group('PlaylistProvider 歌曲操作测试', () {
    late PlaylistProvider provider;
    late DatabaseHelper dbHelper;

    setUp(() async {
      dbHelper = DatabaseHelper();
      await dbHelper.clearAllTables();
      provider = PlaylistProvider(
        repository: PlaylistRepository(dbHelper: dbHelper),
      );
      await Future.delayed(Duration(milliseconds: 100));
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

    test('保存歌曲', () async {
      final song = createTestSong('歌曲A');

      final saved = await provider.saveSong(song);

      expect(saved, isNotNull);
      expect(saved!.id, isNotNull);
      expect(provider.allSongs.length, equals(1));
    });

    test('批量保存歌曲', () async {
      final songs = [
        createTestSong('歌曲A'),
        createTestSong('歌曲B'),
        createTestSong('歌曲C'),
      ];

      final saved = await provider.saveSongs(songs);

      expect(saved.length, equals(3));
      expect(provider.allSongs.length, equals(3));
    });

    test('删除歌曲', () async {
      final song = await provider.saveSong(createTestSong('歌曲A'));
      expect(song, isNotNull);

      final success = await provider.deleteSong(song!.id!);

      expect(success, isTrue);
      expect(provider.allSongs, isEmpty);
    });

    test('删除歌曲时可以选择同时删除文件', () async {
      final song = await provider.saveSong(createTestSong('歌曲A'));
      expect(song, isNotNull);

      // 注意：这里只测试数据库删除逻辑
      // 文件删除由 FileUtils 单独测试
      final success = await provider.deleteSong(song!.id!, deleteFile: true);

      expect(success, isTrue);
      expect(provider.allSongs, isEmpty);
    });

    test('搜索歌曲', () async {
      await provider.saveSong(createTestSong('晴天'));
      await provider.saveSong(createTestSong('阴天'));
      await provider.saveSong(createTestSong('稻香'));

      final results = await provider.searchSongs('天');

      expect(results.length, equals(2));
    });
  });

  group('PlaylistProvider 歌单歌曲关联测试', () {
    late PlaylistProvider provider;
    late DatabaseHelper dbHelper;

    setUp(() async {
      dbHelper = DatabaseHelper();
      await dbHelper.clearAllTables();
      provider = PlaylistProvider(
        repository: PlaylistRepository(dbHelper: dbHelper),
      );
      await Future.delayed(Duration(milliseconds: 100));
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
      final playlist = await provider.createPlaylist(name: '测试歌单');
      final song = await provider.saveSong(createTestSong('歌曲A'));
      expect(playlist, isNotNull);
      expect(song, isNotNull);

      final success = await provider.addSongToPlaylist(playlist!.id!, song!);

      expect(success, isTrue);

      await provider.selectPlaylist(playlist.id!);
      expect(provider.selectedPlaylistSongs.length, equals(1));
    });

    test('批量添加歌曲到歌单', () async {
      final playlist = await provider.createPlaylist(name: '测试歌单');
      expect(playlist, isNotNull);

      final songs = [
        await provider.saveSong(createTestSong('歌曲A')),
        await provider.saveSong(createTestSong('歌曲B')),
      ];

      final count = await provider.addSongsToPlaylist(
        playlist!.id!,
        songs.whereType<Song>().toList(),
      );

      expect(count, equals(2));
    });

    test('从歌单移除歌曲', () async {
      final playlist = await provider.createPlaylist(name: '测试歌单');
      final song = await provider.saveSong(createTestSong('歌曲A'));
      expect(playlist, isNotNull);
      expect(song, isNotNull);

      await provider.addSongToPlaylist(playlist!.id!, song!);
      await provider.selectPlaylist(playlist.id!);
      expect(provider.selectedPlaylistSongs.length, equals(1));

      final success = await provider.removeSongFromPlaylist(
        playlist.id!,
        song.id!,
      );

      expect(success, isTrue);
      expect(provider.selectedPlaylistSongs, isEmpty);
    });

    test('检查歌曲是否在歌单中', () async {
      final playlist = await provider.createPlaylist(name: '测试歌单');
      final song = await provider.saveSong(createTestSong('歌曲A'));
      expect(playlist, isNotNull);
      expect(song, isNotNull);

      final before = await provider.isSongInPlaylist(playlist!.id!, song!.id!);
      expect(before, isFalse);

      await provider.addSongToPlaylist(playlist.id!, song);

      final after = await provider.isSongInPlaylist(playlist.id!, song.id!);
      expect(after, isTrue);
    });
  });

  group('PlaylistProvider 播放历史测试', () {
    late PlaylistProvider provider;
    late DatabaseHelper dbHelper;

    setUp(() async {
      dbHelper = DatabaseHelper();
      await dbHelper.clearAllTables();
      provider = PlaylistProvider(
        repository: PlaylistRepository(dbHelper: dbHelper),
      );
      await Future.delayed(Duration(milliseconds: 100));
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
      final song = await provider.saveSong(createTestSong('歌曲A'));
      expect(song, isNotNull);

      await provider.recordPlayHistory(song!.id!);

      expect(provider.playHistory.length, equals(1));
    });

    test('清空播放历史', () async {
      final song = await provider.saveSong(createTestSong('歌曲A'));
      expect(song, isNotNull);
      await provider.recordPlayHistory(song!.id!);
      expect(provider.playHistory.length, equals(1));

      await provider.clearPlayHistory();

      expect(provider.playHistory, isEmpty);
    });
  });

  group('PlaylistProvider 错误处理测试', () {
    late PlaylistProvider provider;
    late DatabaseHelper dbHelper;

    setUp(() async {
      dbHelper = DatabaseHelper();
      await dbHelper.clearAllTables();
      provider = PlaylistProvider(
        repository: PlaylistRepository(dbHelper: dbHelper),
      );
      await Future.delayed(Duration(milliseconds: 100));
    });

    tearDown(() async {
      await dbHelper.close();
    });

    test('清除错误', () async {
      provider.clearError();
      expect(provider.error, isNull);
    });

    test('刷新数据', () async {
      await provider.createPlaylist(name: '歌单1');
      await provider.refresh();

      // 系统歌单 + 歌单1 = 2
      expect(provider.playlists.length, equals(2));
    });
  });
}
