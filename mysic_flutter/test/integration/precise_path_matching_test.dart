import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite/sqflite.dart';
import 'package:mysic_flutter/shared/utils/scan_directory_config.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Precise Path Matching Integration', () {
    test('full path should match files in that directory only', () {
      // 模拟路径匹配函数（核心逻辑测试）
      // 这个测试验证路径匹配逻辑，不涉及数据库操作
      bool isPathInDirectory(String filePath, String directoryPath) {
        final normalizedFile = filePath.replaceAll(r'\', '/').toLowerCase();
        final normalizedDir =
            directoryPath.replaceAll(r'\', '/').toLowerCase();
        final dirWithSeparator =
            normalizedDir.endsWith('/') ? normalizedDir : '$normalizedDir/';
        return normalizedFile.startsWith(dirWithSeparator);
      }

      // 场景：两个目录配置
      const config1 = ScanDirectoryConfig(
        directory: r'G:\music',
        playlistId: 1,
        playlistName: 'Music',
      );
      const config2 = ScanDirectoryConfig(
        directory: r'G:\music\成名曲',
        playlistId: 2,
        playlistName: '成名曲',
      );

      // 文件路径
      const file1 = r'G:\music\song1.mp3';
      const file2 = r'G:\music\成名曲\song2.mp3';
      const file3 = r'G:\music\other\song3.mp3';

      // 验证：file1 只属于 config1
      expect(isPathInDirectory(file1, config1.directory), isTrue);
      expect(isPathInDirectory(file1, config2.directory), isFalse);

      // 验证：file2 属于 config1 和 config2（因为 config1 是父目录）
      expect(isPathInDirectory(file2, config1.directory), isTrue);
      expect(isPathInDirectory(file2, config2.directory), isTrue);

      // 验证：file3 只属于 config1
      expect(isPathInDirectory(file3, config1.directory), isTrue);
      expect(isPathInDirectory(file3, config2.directory), isFalse);
    });

    test('ScanDirectoryConfig effectiveDisplayName works correctly', () {
      // 测试 displayName 优先级
      const configWithDisplayName = ScanDirectoryConfig(
        directory: r'G:\music\成名曲',
        displayName: '我的成名曲',
      );
      expect(configWithDisplayName.effectiveDisplayName, '我的成名曲');

      // 测试从路径提取名称
      const configWithoutDisplayName = ScanDirectoryConfig(
        directory: r'G:\music\成名曲',
      );
      expect(configWithoutDisplayName.effectiveDisplayName, '成名曲');

      // 测试 Windows 路径
      const configWindowsPath = ScanDirectoryConfig(
        directory: r'C:\Users\Test\Music\MySongs',
      );
      expect(configWindowsPath.effectiveDisplayName, 'MySongs');

      // 测试末尾有斜杠的路径
      const configTrailingSlash = ScanDirectoryConfig(
        directory: r'G:\music\成名曲\',
      );
      expect(configTrailingSlash.effectiveDisplayName, '成名曲');
    });

    test('ScanDirectoryConfig serialization works correctly', () {
      const config = ScanDirectoryConfig(
        directory: r'G:\music\成名曲',
        playlistId: 1,
        playlistName: '成名曲',
        displayName: '我的成名曲',
      );

      // 测试 JSON 序列化
      final json = config.toJson();
      expect(json['directory'], r'G:\music\成名曲');
      expect(json['playlistId'], 1);
      expect(json['playlistName'], '成名曲');
      expect(json['displayName'], '我的成名曲');

      // 测试 JSON 反序列化
      final fromJson = ScanDirectoryConfig.fromJson(json);
      expect(fromJson.directory, config.directory);
      expect(fromJson.playlistId, config.playlistId);
      expect(fromJson.playlistName, config.playlistName);
      expect(fromJson.displayName, config.displayName);
    });

    test('ScanDirectoryConfig copyWith works correctly', () {
      const original = ScanDirectoryConfig(
        directory: r'G:\music\成名曲',
        playlistId: 1,
        playlistName: '成名曲',
        displayName: '我的成名曲',
      );

      // 测试更新 playlist
      final updatedPlaylist = original.copyWith(
        playlistId: 2,
        playlistName: '新歌单',
      );
      expect(updatedPlaylist.directory, r'G:\music\成名曲');
      expect(updatedPlaylist.playlistId, 2);
      expect(updatedPlaylist.playlistName, '新歌单');
      expect(updatedPlaylist.displayName, '我的成名曲');

      // 测试清除 playlist
      final clearedPlaylist = original.copyWith(clearPlaylist: true);
      expect(clearedPlaylist.playlistId, isNull);
      expect(clearedPlaylist.playlistName, isNull);
      expect(clearedPlaylist.displayName, '我的成名曲');
    });
  });
}
