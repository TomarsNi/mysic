import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:mysic_flutter/core/database/database_helper.dart';
import 'package:mysic_flutter/features/playlist/data/playlist_repository.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('重复歌单测试', () {
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

    test('模拟 PlaylistProvider 初始化两次', () async {
      // 第一次：确保系统歌单存在
      final systemPlaylist = await repository.getSystemPlaylist();
      if (systemPlaylist == null) {
        final existing = await repository.getLocalMusicPlaylist();
        if (existing != null) {
          await repository.upgradeToSystemPlaylist(existing.id!);
        } else {
          await repository.createSystemPlaylist(name: '本地音乐');
        }
      }

      // 第二次：再次确保系统歌单存在（模拟另一个 Provider 实例）
      final systemPlaylist2 = await repository.getSystemPlaylist();
      if (systemPlaylist2 == null) {
        final existing2 = await repository.getLocalMusicPlaylist();
        if (existing2 != null) {
          await repository.upgradeToSystemPlaylist(existing2.id!);
        } else {
          await repository.createSystemPlaylist(name: '本地音乐');
        }
      }

      // 检查结果
      final allPlaylists = await repository.getAllPlaylists();
      print('歌单数量: ${allPlaylists.length}');
      for (final p in allPlaylists) {
        print('  - ${p.name}, isSystem: ${p.isSystem}');
      }

      expect(allPlaylists.length, equals(1));
      expect(allPlaylists.first.isSystem, isTrue);
    });
  });
}
