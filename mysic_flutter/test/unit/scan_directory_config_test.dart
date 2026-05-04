import 'package:flutter_test/flutter_test.dart';
import 'package:mysic_flutter/shared/utils/scan_directory_config.dart';

void main() {
  group('ScanDirectoryConfig', () {
    test('displayName field should be serialized correctly', () {
      final config = ScanDirectoryConfig(
        directory: r'G:\music\成名曲',
        playlistId: 1,
        playlistName: '成名曲',
        displayName: '成名曲',
      );

      final json = config.toJson();
      expect(json['directory'], r'G:\music\成名曲');
      expect(json['displayName'], '成名曲');

      final fromJson = ScanDirectoryConfig.fromJson(json);
      expect(fromJson.displayName, '成名曲');
    });

    test('copyWith should preserve displayName', () {
      final config = ScanDirectoryConfig(
        directory: r'G:\music',
        displayName: 'music',
      );

      final copied = config.copyWith(playlistId: 1, playlistName: 'Music');
      expect(copied.displayName, 'music');
    });

    test('displayName defaults to null for backward compatibility', () {
      final json = {
        'directory': 'music',
        'playlistId': 1,
        'playlistName': 'Music',
      };

      final config = ScanDirectoryConfig.fromJson(json);
      expect(config.displayName, isNull);
    });

    test('effectiveDisplayName returns displayName when set', () {
      final config = ScanDirectoryConfig(
        directory: r'G:\music\成名曲',
        displayName: '成名曲',
      );

      expect(config.effectiveDisplayName, '成名曲');
    });

    test('effectiveDisplayName extracts last path segment when displayName is null', () {
      final config = ScanDirectoryConfig(
        directory: r'G:\music\成名曲',
      );

      expect(config.effectiveDisplayName, '成名曲');
    });

    test('effectiveDisplayName handles forward slashes', () {
      final config = ScanDirectoryConfig(
        directory: '/home/user/music/songs',
      );

      expect(config.effectiveDisplayName, 'songs');
    });

    test('effectiveDisplayName handles trailing slashes', () {
      final config = ScanDirectoryConfig(
        directory: r'G:\music\成名曲\',
      );

      expect(config.effectiveDisplayName, '成名曲');
    });

    test('equality considers all fields', () {
      final config1 = ScanDirectoryConfig(
        directory: 'music',
        displayName: 'Music',
      );
      final config2 = ScanDirectoryConfig(
        directory: 'music',
        displayName: 'Music',
      );
      final config3 = ScanDirectoryConfig(
        directory: 'music',
        displayName: 'Different',
      );

      expect(config1, equals(config2));
      expect(config1, isNot(equals(config3)));
    });
  });
}
