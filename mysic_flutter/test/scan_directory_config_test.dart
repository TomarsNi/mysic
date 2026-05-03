import 'package:flutter_test/flutter_test.dart';
import 'package:mysic_flutter/shared/utils/scan_directory_config.dart';

void main() {
  group('ScanDirectoryConfig', () {
    group('fromJson', () {
      test('解析包含所有字段的 JSON', () {
        final json = {
          'directory': r'D:\Music',
          'playlistId': 1,
          'playlistName': '我的歌单',
        };

        final config = ScanDirectoryConfig.fromJson(json);

        expect(config.directory, equals(r'D:\Music'));
        expect(config.playlistId, equals(1));
        expect(config.playlistName, equals('我的歌单'));
      });

      test('处理 null playlist 字段', () {
        final json = {
          'directory': r'C:\Users\Music',
          'playlistId': null,
          'playlistName': null,
        };

        final config = ScanDirectoryConfig.fromJson(json);

        expect(config.directory, equals(r'C:\Users\Music'));
        expect(config.playlistId, isNull);
        expect(config.playlistName, isNull);
      });

      test('处理缺少 playlist 字段的 JSON', () {
        final json = {'directory': r'E:\Music'};

        final config = ScanDirectoryConfig.fromJson(json);

        expect(config.directory, equals(r'E:\Music'));
        expect(config.playlistId, isNull);
        expect(config.playlistName, isNull);
      });
    });

    group('toJson', () {
      test('生成正确的 JSON（已关联歌单）', () {
        final config = ScanDirectoryConfig(
          directory: r'D:\Music',
          playlistId: 1,
          playlistName: '我的歌单',
        );

        final json = config.toJson();

        expect(json['directory'], equals(r'D:\Music'));
        expect(json['playlistId'], equals(1));
        expect(json['playlistName'], equals('我的歌单'));
      });

      test('生成正确的 JSON（未关联歌单）', () {
        final config = ScanDirectoryConfig(directory: r'C:\Music');

        final json = config.toJson();

        expect(json['directory'], equals(r'C:\Music'));
        expect(json['playlistId'], isNull);
        expect(json['playlistName'], isNull);
      });
    });

    group('copyWith', () {
      test('创建修改部分字段的副本', () {
        final original = ScanDirectoryConfig(
          directory: r'D:\Music',
          playlistId: 1,
          playlistName: '旧歌单',
        );

        final modified = original.copyWith(playlistName: '新歌单');

        expect(modified.directory, equals(r'D:\Music'));
        expect(modified.playlistId, equals(1));
        expect(modified.playlistName, equals('新歌单'));
        // 确保原对象未修改
        expect(original.playlistName, equals('旧歌单'));
      });

      test('clearPlaylist 参数清除关联', () {
        final original = ScanDirectoryConfig(
          directory: r'D:\Music',
          playlistId: 1,
          playlistName: '我的歌单',
        );

        final cleared = original.copyWith(clearPlaylist: true);

        expect(cleared.directory, equals(r'D:\Music'));
        expect(cleared.playlistId, isNull);
        expect(cleared.playlistName, isNull);
      });
    });

    group('isLinked', () {
      test('已关联时返回 true', () {
        final config = ScanDirectoryConfig(
          directory: r'D:\Music',
          playlistId: 1,
          playlistName: '我的歌单',
        );

        expect(config.isLinked, isTrue);
      });

      test('未关联时返回 false', () {
        final config = ScanDirectoryConfig(
          directory: r'D:\Music',
          playlistId: null,
          playlistName: null,
        );

        expect(config.isLinked, isFalse);
      });

      test('仅 playlistId 存在时返回 false（需要完整关联）', () {
        final config = ScanDirectoryConfig(
          directory: r'D:\Music',
          playlistId: 1,
          playlistName: null,
        );

        expect(config.isLinked, isFalse);
      });
    });
  });
}
