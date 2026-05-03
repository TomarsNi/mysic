import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:mysic_flutter/core/database/database_helper.dart';
import 'package:mysic_flutter/shared/utils/scan_directory_provider.dart';
import 'package:sqflite/sqflite.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('ScanDirectoryProvider', () {
    late ScanDirectoryProvider provider;
    late DatabaseHelper dbHelper;

    setUp(() async {
      dbHelper = DatabaseHelper();
      // 清除 settings 表中的数据
      final db = await dbHelper.database;
      await db.delete(DatabaseHelper.tableSettings);
      provider = ScanDirectoryProvider();
    });

    tearDown(() async {
      await dbHelper.close();
    });

    test('getDirectories returns default directories when empty', () async {
      final directories = await provider.getDirectories();
      expect(directories, isNotEmpty);
      expect(directories, contains('Music'));
      expect(directories, contains('音乐'));
    });

    test('addDirectory adds a new directory', () async {
      await provider.addDirectory('MyMusic');
      final directories = await provider.getDirectories();
      expect(directories, contains('MyMusic'));
    });

    test('removeDirectory removes a directory', () async {
      await provider.addDirectory('TestDir');
      await provider.removeDirectory('TestDir');
      final directories = await provider.getDirectories();
      expect(directories, isNot(contains('TestDir')));
    });

    test('resetToDefault resets to default directories', () async {
      await provider.addDirectory('CustomDir');
      await provider.resetToDefault();
      final directories = await provider.getDirectories();
      expect(directories, isNot(contains('CustomDir')));
      expect(directories, contains('Music'));
    });
  });

  group('ScanDirectoryProvider with configs', () {
    late ScanDirectoryProvider provider;
    late DatabaseHelper dbHelper;

    setUp(() async {
      dbHelper = DatabaseHelper();
      // 清除 settings 表中的数据
      final db = await dbHelper.database;
      await db.delete(DatabaseHelper.tableSettings);
      provider = ScanDirectoryProvider();
    });

    tearDown(() async {
      await dbHelper.close();
    });

    test('getConfigs returns empty list initially', () async {
      final configs = await provider.getConfigs();
      expect(configs, isEmpty);
    });

    test('addDirectoryWithPlaylist creates config with playlist', () async {
      await provider.addDirectoryWithPlaylist(
        'MyMusic',
        playlistId: 1,
        playlistName: 'My Playlist',
      );

      final configs = await provider.getConfigs();
      expect(configs.length, 1);
      expect(configs[0].directory, 'MyMusic');
      expect(configs[0].playlistId, 1);
      expect(configs[0].playlistName, 'My Playlist');
      expect(configs[0].isLinked, isTrue);
    });

    test('updateDirectoryPlaylist updates existing config', () async {
      await provider.addDirectoryWithPlaylist(
        'TestDir',
        playlistId: 1,
        playlistName: 'First Playlist',
      );

      await provider.updateDirectoryPlaylist(
        'TestDir',
        2,
        'Second Playlist',
      );

      final configs = await provider.getConfigs();
      expect(configs.length, 1);
      expect(configs[0].playlistId, 2);
      expect(configs[0].playlistName, 'Second Playlist');
    });

    test('getConfigByDirectory returns correct config', () async {
      await provider.addDirectoryWithPlaylist(
        'Dir1',
        playlistId: 1,
        playlistName: 'Playlist1',
      );
      await provider.addDirectoryWithPlaylist(
        'Dir2',
        playlistId: 2,
        playlistName: 'Playlist2',
      );

      final config = await provider.getConfigByDirectory('Dir1');
      expect(config, isNotNull);
      expect(config!.directory, 'Dir1');
      expect(config.playlistId, 1);

      final notFound = await provider.getConfigByDirectory('NonExistent');
      expect(notFound, isNull);
    });

    test('removeConfig removes correct config', () async {
      await provider.addDirectoryWithPlaylist('Dir1', playlistId: 1, playlistName: 'P1');
      await provider.addDirectoryWithPlaylist('Dir2', playlistId: 2, playlistName: 'P2');

      await provider.removeConfig('Dir1');

      final configs = await provider.getConfigs();
      expect(configs.length, 1);
      expect(configs[0].directory, 'Dir2');
    });

    test('migrates old string list to new config format', () async {
      // 首先使用旧格式保存数据
      await provider.addDirectory('OldDir1');
      await provider.addDirectory('OldDir2');

      // 执行迁移
      final configs = await provider.migrateIfNeeded();

      // 注意：addDirectory 会初始化默认目录，所以迁移后可能包含默认目录 + OldDir1 + OldDir2
      expect(configs.any((c) => c.directory == 'OldDir1'), isTrue);
      expect(configs.any((c) => c.directory == 'OldDir2'), isTrue);
      // 迁移后的配置不应该有关联的歌单
      expect(configs.every((c) => !c.isLinked), isTrue);

      // 再次调用 getConfigs 应该返回已迁移的数据
      final configs2 = await provider.getConfigs();
      expect(configs2.any((c) => c.directory == 'OldDir1'), isTrue);
      expect(configs2.any((c) => c.directory == 'OldDir2'), isTrue);
    });
  });
}
