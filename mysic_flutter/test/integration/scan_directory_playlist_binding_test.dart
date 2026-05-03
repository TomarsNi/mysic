import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite/sqflite.dart';
import 'package:mysic_flutter/core/database/database_helper.dart';
import 'package:mysic_flutter/shared/utils/scan_directory_provider.dart';
import 'package:mysic_flutter/features/playlist/data/playlist_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Scan Directory Playlist Binding Integration', () {
    late DatabaseHelper dbHelper;
    late ScanDirectoryProvider scanProvider;
    late PlaylistRepository playlistRepository;

    setUp(() async {
      dbHelper = DatabaseHelper();
      // 先关闭现有数据库连接，然后删除数据库文件
      await dbHelper.close();
      await dbHelper.deleteDatabase();

      // 重新获取数据库实例（会创建新的数据库）
      final db = await dbHelper.database;

      // 清空测试相关的表
      await db.delete(DatabaseHelper.tableSettings);
      await db.delete(DatabaseHelper.tablePlaylists);
      await db.delete(DatabaseHelper.tablePlaylistSongs);
      await db.delete(DatabaseHelper.tableSongs);

      scanProvider = ScanDirectoryProvider();
      playlistRepository = PlaylistRepository();
    });

    tearDown(() async {
      await dbHelper.close();
    });

    test('adding directory creates playlist and links them', () async {
      // 创建歌单
      final playlist = await playlistRepository.createPlaylist(name: 'Music');
      expect(playlist, isNotNull);
      expect(playlist.id, isNotNull);

      // 添加目录并关联歌单
      await scanProvider.addDirectoryWithPlaylist(
        'Music',
        playlistId: playlist.id,
        playlistName: playlist.name,
      );

      // 验证关联
      final configs = await scanProvider.getConfigs();
      expect(configs.length, 1);
      expect(configs.first.directory, 'Music');
      expect(configs.first.playlistId, playlist.id);
    });

    test('multiple directories can be linked to different playlists', () async {
      // 创建两个歌单
      final playlist1 = await playlistRepository.createPlaylist(name: 'Music');
      final playlist2 = await playlistRepository.createPlaylist(name: 'Downloads');
      expect(playlist1.id, isNotNull);
      expect(playlist2.id, isNotNull);

      // 关联目录
      await scanProvider.addDirectoryWithPlaylist(
        'Music',
        playlistId: playlist1.id,
        playlistName: playlist1.name,
      );
      await scanProvider.addDirectoryWithPlaylist(
        'Downloads',
        playlistId: playlist2.id,
        playlistName: playlist2.name,
      );

      // 验证
      final configs = await scanProvider.getConfigs();
      expect(configs.length, 2);

      final musicConfig = configs.firstWhere((c) => c.directory == 'Music');
      expect(musicConfig.playlistId, playlist1.id);

      final downloadsConfig = configs.firstWhere((c) => c.directory == 'Downloads');
      expect(downloadsConfig.playlistId, playlist2.id);
    });

    test('updating playlist link works correctly', () async {
      final playlist1 = await playlistRepository.createPlaylist(name: 'Music');
      final playlist2 = await playlistRepository.createPlaylist(name: 'NewMusic');
      expect(playlist1.id, isNotNull);
      expect(playlist2.id, isNotNull);

      await scanProvider.addDirectoryWithPlaylist(
        'Music',
        playlistId: playlist1.id,
        playlistName: playlist1.name,
      );

      // 更新关联
      await scanProvider.updateDirectoryPlaylist(
        'Music',
        playlist2.id!,
        playlist2.name,
      );

      final config = await scanProvider.getConfigByDirectory('Music');
      expect(config, isNotNull);
      expect(config!.playlistId, playlist2.id);
      expect(config.playlistName, 'NewMusic');
    });
  });
}
