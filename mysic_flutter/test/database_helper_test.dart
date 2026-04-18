import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:mysic_flutter/core/database/database_helper.dart';

void main() {
  // 初始化 sqflite_ffi 用于测试
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('DatabaseHelper', () {
    late DatabaseHelper dbHelper;

    setUp(() async {
      dbHelper = DatabaseHelper();
      // 每个测试前清空数据
      final db = await dbHelper.database;
      await db.delete(DatabaseHelper.tablePlayHistory);
      await db.delete(DatabaseHelper.tableLyrics);
      await db.delete(DatabaseHelper.tablePlaylistSongs);
      await db.delete(DatabaseHelper.tablePlaylists);
      await db.delete(DatabaseHelper.tableSongs);
    });

    tearDown(() async {
      await dbHelper.close();
    });

    test('数据库初始化成功', () async {
      // Act
      final db = await dbHelper.database;

      // Assert
      expect(db, isNotNull);
      expect(db.isOpen, isTrue);
    });

    test('数据库包含所有必需的表', () async {
      // Arrange
      final db = await dbHelper.database;

      // Act
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table'",
      );
      final tableNames = tables.map((t) => t['name'] as String).toList();

      // Assert
      expect(tableNames, contains(DatabaseHelper.tableSongs));
      expect(tableNames, contains(DatabaseHelper.tablePlaylists));
      expect(tableNames, contains(DatabaseHelper.tablePlaylistSongs));
      expect(tableNames, contains(DatabaseHelper.tableLyrics));
      expect(tableNames, contains(DatabaseHelper.tablePlayHistory));
    });

    test('歌曲表结构正确', () async {
      // Arrange
      final db = await dbHelper.database;

      // Act
      final columns = await db.rawQuery(
        'PRAGMA table_info(${DatabaseHelper.tableSongs})',
      );
      final columnNames = columns.map((c) => c['name'] as String).toList();

      // Assert
      expect(columnNames, contains('id'));
      expect(columnNames, contains('title'));
      expect(columnNames, contains('artist'));
      expect(columnNames, contains('album'));
      expect(columnNames, contains('duration'));
      expect(columnNames, contains('file_path'));
      expect(columnNames, contains('album_art_path'));
      expect(columnNames, contains('date_added'));
      expect(columnNames, contains('created_at'));
      expect(columnNames, contains('updated_at'));
    });

    test('歌单表结构正确', () async {
      // Arrange
      final db = await dbHelper.database;

      // Act
      final columns = await db.rawQuery(
        'PRAGMA table_info(${DatabaseHelper.tablePlaylists})',
      );
      final columnNames = columns.map((c) => c['name'] as String).toList();

      // Assert
      expect(columnNames, contains('id'));
      expect(columnNames, contains('name'));
      expect(columnNames, contains('description'));
      expect(columnNames, contains('cover_path'));
      expect(columnNames, contains('created_at'));
      expect(columnNames, contains('updated_at'));
    });

    test('歌词表结构正确', () async {
      // Arrange
      final db = await dbHelper.database;

      // Act
      final columns = await db.rawQuery(
        'PRAGMA table_info(${DatabaseHelper.tableLyrics})',
      );
      final columnNames = columns.map((c) => c['name'] as String).toList();

      // Assert
      expect(columnNames, contains('id'));
      expect(columnNames, contains('song_id'));
      expect(columnNames, contains('lrc_content'));
      expect(columnNames, contains('is_synced'));
      expect(columnNames, contains('source'));
      expect(columnNames, contains('created_at'));
      expect(columnNames, contains('updated_at'));
    });

    test('播放历史表结构正确', () async {
      // Arrange
      final db = await dbHelper.database;

      // Act
      final columns = await db.rawQuery(
        'PRAGMA table_info(${DatabaseHelper.tablePlayHistory})',
      );
      final columnNames = columns.map((c) => c['name'] as String).toList();

      // Assert
      expect(columnNames, contains('id'));
      expect(columnNames, contains('song_id'));
      expect(columnNames, contains('played_at'));
      expect(columnNames, contains('play_duration'));
    });

    test('插入歌曲成功', () async {
      // Arrange
      final db = await dbHelper.database;
      final song = {
        'title': '测试歌曲',
        'artist': '测试艺术家',
        'album': '测试专辑',
        'duration': 180000,
        'file_path': '/path/to/song.mp3',
        'created_at': DatabaseHelper.currentTimestamp(),
        'updated_at': DatabaseHelper.currentTimestamp(),
      };

      // Act
      final id = await db.insert(DatabaseHelper.tableSongs, song);

      // Assert
      expect(id, greaterThan(0));

      // Verify
      final songs = await db.query(DatabaseHelper.tableSongs);
      expect(songs.length, equals(1));
      expect(songs.first['title'], equals('测试歌曲'));
    });

    test('插入歌单成功', () async {
      // Arrange
      final db = await dbHelper.database;
      final playlist = {
        'name': '我的歌单',
        'description': '测试描述',
        'created_at': DatabaseHelper.currentTimestamp(),
        'updated_at': DatabaseHelper.currentTimestamp(),
      };

      // Act
      final id = await db.insert(DatabaseHelper.tablePlaylists, playlist);

      // Assert
      expect(id, greaterThan(0));

      // Verify
      final playlists = await db.query(DatabaseHelper.tablePlaylists);
      expect(playlists.length, equals(1));
      expect(playlists.first['name'], equals('我的歌单'));
    });

    test('歌曲添加到歌单成功', () async {
      // Arrange
      final db = await dbHelper.database;
      final now = DatabaseHelper.currentTimestamp();

      // 创建歌曲
      final songId = await db.insert(DatabaseHelper.tableSongs, {
        'title': '测试歌曲',
        'duration': 180000,
        'file_path': '/path/to/song.mp3',
        'created_at': now,
        'updated_at': now,
      });

      // 创建歌单
      final playlistId = await db.insert(DatabaseHelper.tablePlaylists, {
        'name': '我的歌单',
        'created_at': now,
        'updated_at': now,
      });

      // Act - 添加歌曲到歌单
      final id = await db.insert(DatabaseHelper.tablePlaylistSongs, {
        'playlist_id': playlistId,
        'song_id': songId,
        'position': 0,
        'added_at': now,
      });

      // Assert
      expect(id, greaterThan(0));

      // Verify
      final playlistSongs = await db.query(
        DatabaseHelper.tablePlaylistSongs,
        where: 'playlist_id = ?',
        whereArgs: [playlistId],
      );
      expect(playlistSongs.length, equals(1));
      expect(playlistSongs.first['song_id'], equals(songId));
    });

    test('清空所有表成功', () async {
      // Arrange
      final db = await dbHelper.database;
      final now = DatabaseHelper.currentTimestamp();

      // 插入测试数据
      await db.insert(DatabaseHelper.tableSongs, {
        'title': '测试歌曲',
        'duration': 180000,
        'file_path': '/path/to/song.mp3',
        'created_at': now,
        'updated_at': now,
      });
      await db.insert(DatabaseHelper.tablePlaylists, {
        'name': '我的歌单',
        'created_at': now,
        'updated_at': now,
      });

      // Act
      await dbHelper.clearAllTables();

      // Assert
      final songs = await db.query(DatabaseHelper.tableSongs);
      final playlists = await db.query(DatabaseHelper.tablePlaylists);
      expect(songs, isEmpty);
      expect(playlists, isEmpty);
    });

    test('currentTimestamp 返回有效时间戳', () {
      // Act
      final timestamp = DatabaseHelper.currentTimestamp();

      // Assert
      expect(timestamp, greaterThan(0));
      expect(timestamp, lessThanOrEqualTo(DateTime.now().millisecondsSinceEpoch));
    });
  });
}
