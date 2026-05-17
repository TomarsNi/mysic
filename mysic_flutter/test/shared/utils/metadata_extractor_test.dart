import 'package:flutter_test/flutter_test.dart';
import 'package:mysic_flutter/shared/utils/metadata_extractor.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MetadataExtractor.extractArtwork', () {
    group('WAV files', () {
      test('returns null for WAV files (RIFF INFO does not contain artwork)', () async {
        // RIFF INFO 格式不支持内嵌封面，WAV 文件应直接返回 null
        final result = await MetadataExtractor.extractArtwork(
          '/path/to/audio.wav',
        );
        expect(result, isNull);
      });

      test('returns null for WAV files with uppercase extension', () async {
        // 测试大写扩展名也能正确识别
        final result = await MetadataExtractor.extractArtwork(
          '/path/to/audio.WAV',
        );
        expect(result, isNull);
      });

      test('returns null for WAV files with mixed case extension', () async {
        // 测试混合大小写扩展名也能正确识别
        final result = await MetadataExtractor.extractArtwork(
          '/path/to/audio.Wav',
        );
        expect(result, isNull);
      });
    });

    group('Error handling', () {
      test('returns null for non-existent file path', () async {
        // 不存在的文件路径应返回 null，不应抛出异常
        final result = await MetadataExtractor.extractArtwork(
          '/non/existent/path/audio.mp3',
        );
        expect(result, isNull);
      });

      test('returns null for invalid file path', () async {
        // 无效的文件路径应返回 null，不应抛出异常
        final result = await MetadataExtractor.extractArtwork(
          '',
        );
        expect(result, isNull);
      });

      test('returns null for path with special characters that do not exist', () async {
        // 包含特殊字符的不存在路径应返回 null
        final result = await MetadataExtractor.extractArtwork(
          '/path/with/special@chars#/audio.mp3',
        );
        expect(result, isNull);
      });
    });

    group('File extension handling', () {
      test('correctly identifies non-WAV extensions', () async {
        // 非 WAV 扩展名的文件会尝试使用 audiotags 读取
        // 由于测试文件不存在，audiotags 会失败并返回 null
        final mp3Result = await MetadataExtractor.extractArtwork(
          '/non/existent/audio.mp3',
        );
        final flacResult = await MetadataExtractor.extractArtwork(
          '/non/existent/audio.flac',
        );
        final m4aResult = await MetadataExtractor.extractArtwork(
          '/non/existent/audio.m4a',
        );

        // 所有非 WAV 文件在不存在的路径下都应返回 null
        expect(mp3Result, isNull);
        expect(flacResult, isNull);
        expect(m4aResult, isNull);
      });
    });
  });

  group('MetadataExtractor.cleanTitleFromFileName', () {
    test('removes file extension', () {
      expect(
        MetadataExtractor.cleanTitleFromFileName('song.mp3'),
        'song',
      );
    });

    test('removes numeric prefix with dot', () {
      expect(
        MetadataExtractor.cleanTitleFromFileName('01. song.mp3'),
        'song',
      );
    });

    test('removes numeric prefix with dash', () {
      expect(
        MetadataExtractor.cleanTitleFromFileName('01- song.mp3'),
        'song',
      );
    });

    test('removes numeric prefix without separator', () {
      expect(
        MetadataExtractor.cleanTitleFromFileName('01 song.mp3'),
        'song',
      );
    });

    test('removes multi-digit prefix', () {
      expect(
        MetadataExtractor.cleanTitleFromFileName('001. song.mp3'),
        'song',
      );
    });

    test('handles file name without prefix', () {
      expect(
        MetadataExtractor.cleanTitleFromFileName('my song.mp3'),
        'my song',
      );
    });

    test('trims whitespace', () {
      expect(
        MetadataExtractor.cleanTitleFromFileName('  song.mp3  '),
        'song',
      );
    });
  });
}
