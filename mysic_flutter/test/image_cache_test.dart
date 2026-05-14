import 'package:flutter_test/flutter_test.dart';
import 'package:mysic_flutter/shared/utils/image_cache.dart';

void main() {
  group('ImageCache', () {
    late ImageCache cache;

    setUp(() {
      cache = ImageCache();
    });

    test('同名 jpg 图片被正确匹配', () {
      cache.addDirectory('/music', {
        'song.jpg': '/music/song.jpg',
      });

      final result = cache.findImagePath('/music/song.mp3');
      expect(result, '/music/song.jpg');
    });

    test('多格式共存时按优先级选择 (jpg > png > webp > gif)', () {
      cache.addDirectory('/music', {
        'song.png': '/music/song.png',
        'song.gif': '/music/song.gif',
      });

      // png > gif
      var result = cache.findImagePath('/music/song.mp3');
      expect(result, '/music/song.png');

      // 添加 jpg 后，jpg 优先
      cache.addDirectory('/music', {
        'song.jpg': '/music/song.jpg',
        'song.png': '/music/song.png',
        'song.gif': '/music/song.gif',
      });

      result = cache.findImagePath('/music/song.mp3');
      expect(result, '/music/song.jpg');
    });

    test('无同名图片时返回 null', () {
      cache.addDirectory('/music', {
        'other.jpg': '/music/other.jpg',
      });

      final result = cache.findImagePath('/music/song.mp3');
      expect(result, isNull);
    });

    test('不同目录同名文件不混淆', () {
      cache.addDirectory('/music/album1', {
        'song.jpg': '/music/album1/song.jpg',
      });
      cache.addDirectory('/music/album2', {
        'song.jpg': '/music/album2/song.jpg',
      });

      expect(
        cache.findImagePath('/music/album1/song.mp3'),
        '/music/album1/song.jpg',
      );
      expect(
        cache.findImagePath('/music/album2/song.mp3'),
        '/music/album2/song.jpg',
      );
    });

    test('文件名大小写不敏感', () {
      cache.addDirectory('/music', {
        'song.jpg': '/music/Song.JPG',
      });

      final result = cache.findImagePath('/music/SONG.mp3');
      expect(result, '/music/Song.JPG');
    });

    test('clear 清空缓存', () {
      cache.addDirectory('/music', {
        'song.jpg': '/music/song.jpg',
      });

      expect(cache.cachedDirectoryCount, 1);
      cache.clear();
      expect(cache.cachedDirectoryCount, 0);
      expect(cache.findImagePath('/music/song.mp3'), isNull);
    });

    test('空路径返回 null', () {
      cache.addDirectory('/music', {
        'song.jpg': '/music/song.jpg',
      });

      expect(cache.findImagePath(''), isNull);
    });

    test('Windows 路径分隔符兼容', () {
      cache.addDirectory('C:/music', {
        'song.jpg': 'C:/music/song.jpg',
      });

      // 使用反斜杠的路径也能匹配
      final result = cache.findImagePath('C:\\music\\song.mp3');
      expect(result, 'C:/music/song.jpg');
    });
  });
}
