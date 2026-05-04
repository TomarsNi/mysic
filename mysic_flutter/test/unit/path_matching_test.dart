import 'package:flutter_test/flutter_test.dart';
import 'package:mysic_flutter/shared/utils/path_utils.dart';

void main() {
  group('PathUtils.isPathInDirectory', () {
    test('exact match - file directly in directory', () {
      expect(PathUtils.isPathInDirectory(r'G:\music\song.mp3', r'G:\music'), isTrue);
      expect(PathUtils.isPathInDirectory(r'G:/music/song.mp3', r'G:/music'), isTrue);
    });

    test('exact match - file in subdirectory', () {
      expect(
        PathUtils.isPathInDirectory(r'G:\music\成名曲\song.mp3', r'G:\music\成名曲'),
        isTrue,
      );
    });

    test('no match - different directory', () {
      expect(
        PathUtils.isPathInDirectory(r'G:\music\song.mp3', r'G:\music2'),
        isFalse,
      );
    });

    test('no match - partial path name', () {
      expect(
        PathUtils.isPathInDirectory(r'G:\music\成名曲\song.mp3', r'G:\music\成名'),
        isFalse,
      );
    });

    test('no match - file in parent of configured directory', () {
      expect(
        PathUtils.isPathInDirectory(r'G:\music\song.mp3', r'G:\music\成名曲'),
        isFalse,
      );
    });

    test('case insensitive', () {
      expect(PathUtils.isPathInDirectory(r'G:\Music\song.mp3', r'G:\music'), isTrue);
      expect(PathUtils.isPathInDirectory(r'g:\music\song.mp3', r'G:\MUSIC'), isTrue);
    });

    test('mixed path separators', () {
      expect(PathUtils.isPathInDirectory(r'G:\music/subfolder\song.mp3', r'G:\music'), isTrue);
    });

    test('directory with trailing separator', () {
      expect(PathUtils.isPathInDirectory(r'G:\music\song.mp3', r'G:\music\'), isTrue);
    });
  });
}
