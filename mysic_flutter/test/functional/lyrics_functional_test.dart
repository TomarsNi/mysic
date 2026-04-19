import 'package:flutter_test/flutter_test.dart';
import 'package:mysic_flutter/features/lyrics/data/services/lyrics_parser.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('歌词显示功能测试', () {
    late LyricsParser parser;

    setUp(() {
      parser = LyricsParser();
    });

    group('LRC 格式解析', () {
      test('解析简单歌词应正确', () {
        const lrcContent = '''
[ti:测试歌曲]
[ar:测试艺术家]
[al:测试专辑]
[00:00.00]第一行歌词
[00:05.00]第二行歌词
[00:10.00]第三行歌词
''';

        final result = parser.parse(lrcContent);

        expect(result.isValid, isTrue);
        expect(result.lines.length, 3);
        expect(result.title, '测试歌曲');
        expect(result.artist, '测试艺术家');
        expect(result.album, '测试专辑');
      });

      test('解析空歌词应返回空结果', () {
        final result = parser.parse('');
        expect(result.isValid, isFalse);
        expect(result.lines, isEmpty);
      });

      test('解析空白内容应返回空结果', () {
        final result = parser.parse('   \n\n   ');
        expect(result.isValid, isFalse);
        expect(result.lines, isEmpty);
      });

      test('解析无时间标签的歌词应返回空结果', () {
        const lrcContent = '''
第一行歌词
第二行歌词
第三行歌词
''';
        final result = parser.parse(lrcContent);
        expect(result.isValid, isFalse);
        expect(result.lines, isEmpty);
      });

      test('解析不同时间格式应正确', () {
        const lrcContent = '''
[00:00]第一行
[00:05.50]第二行
[00:10.100]第三行
[01:30.00]第四行
''';
        final result = parser.parse(lrcContent);

        expect(result.isValid, isTrue);
        expect(result.lines.length, 4);

        expect(result.lines[0].timestamp, const Duration(seconds: 0));
        expect(result.lines[1].timestamp, const Duration(seconds: 5, milliseconds: 500));
        expect(result.lines[2].timestamp, const Duration(seconds: 10, milliseconds: 100));
        expect(result.lines[3].timestamp, const Duration(minutes: 1, seconds: 30));
      });

      test('解析多时间标签行应正确', () {
        // 同一行歌词有多个时间标签
        const lrcContent = '[00:00.00][00:30.00]重复歌词';
        final result = parser.parse(lrcContent);

        expect(result.isValid, isTrue);
        expect(result.lines.length, 2);
        expect(result.lines[0].text, '重复歌词');
        expect(result.lines[1].text, '重复歌词');
        expect(result.lines[0].timestamp, Duration.zero);
        expect(result.lines[1].timestamp, const Duration(seconds: 30));
      });

      test('歌词行应按时间排序', () {
        const lrcContent = '''
[00:10.00]第三行
[00:00.00]第一行
[00:05.00]第二行
''';
        final result = parser.parse(lrcContent);

        expect(result.lines[0].timestamp, const Duration(seconds: 0));
        expect(result.lines[1].timestamp, const Duration(seconds: 5));
        expect(result.lines[2].timestamp, const Duration(seconds: 10));
      });
    });

    group('歌词时间同步', () {
      test('获取当前歌词行索引应正确', () {
        const lrcContent = '''
[00:00.00]第一行
[00:05.00]第二行
[00:10.00]第三行
[00:15.00]第四行
''';
        final result = parser.parse(lrcContent);

        expect(result.getCurrentLineIndex(const Duration(seconds: 0)), 0);
        expect(result.getCurrentLineIndex(const Duration(seconds: 3)), 0);
        expect(result.getCurrentLineIndex(const Duration(seconds: 5)), 1);
        expect(result.getCurrentLineIndex(const Duration(seconds: 7)), 1);
        expect(result.getCurrentLineIndex(const Duration(seconds: 12)), 2);
        expect(result.getCurrentLineIndex(const Duration(seconds: 20)), 3);
      });

      test('获取当前歌词行应正确', () {
        const lrcContent = '''
[00:00.00]第一行
[00:05.00]第二行
[00:10.00]第三行
''';
        final result = parser.parse(lrcContent);

        expect(result.getCurrentLine(const Duration(seconds: 0))?.text, '第一行');
        expect(result.getCurrentLine(const Duration(seconds: 6))?.text, '第二行');
        expect(result.getCurrentLine(const Duration(seconds: 11))?.text, '第三行');
      });

      test('空歌词获取当前行应返回 null', () {
        final result = LyricsResult.empty;
        expect(result.getCurrentLine(const Duration(seconds: 0)), isNull);
        expect(result.getCurrentLineIndex(const Duration(seconds: 0)), -1);
      });

      test('播放位置在第一行之前应返回第一行', () {
        const lrcContent = '''
[00:05.00]第一行
[00:10.00]第二行
''';
        final result = parser.parse(lrcContent);
        expect(result.getCurrentLineIndex(const Duration(seconds: 0)), 0);
        expect(result.getCurrentLineIndex(const Duration(seconds: 3)), 0);
      });
    });

    group('歌词滚动和高亮', () {
      test('歌词行应包含正确的时间戳', () {
        const lrcContent = '''
[00:00.00]第一行
[00:05.50]第二行
[01:30.00]第三行
''';
        final result = parser.parse(lrcContent);

        expect(result.lines[0].timestamp, const Duration(seconds: 0));
        expect(result.lines[1].timestamp, const Duration(seconds: 5, milliseconds: 500));
        expect(result.lines[2].timestamp, const Duration(minutes: 1, seconds: 30));
      });

      test('歌词行应包含正确的文本', () {
        const lrcContent = '''
[00:00.00]这是第一行歌词
[00:05.00]这是第二行歌词
[00:10.00]这是第三行歌词
''';
        final result = parser.parse(lrcContent);

        expect(result.lines[0].text, '这是第一行歌词');
        expect(result.lines[1].text, '这是第二行歌词');
        expect(result.lines[2].text, '这是第三行歌词');
      });

      test('LyricLine 相等性应正确', () {
        final line1 = const LyricLine(
          timestamp: Duration(seconds: 10),
          text: '测试歌词',
        );
        final line2 = const LyricLine(
          timestamp: Duration(seconds: 10),
          text: '测试歌词',
        );
        final line3 = const LyricLine(
          timestamp: Duration(seconds: 10),
          text: '其他歌词',
        );

        expect(line1 == line2, isTrue);
        expect(line1 == line3, isFalse);
      });
    });

    group('元数据解析', () {
      test('解析标题元数据应正确', () {
        const lrcContent = '[ti:歌曲标题]';
        final result = parser.parse(lrcContent);
        expect(result.title, '歌曲标题');
      });

      test('解析艺术家元数据应正确', () {
        const lrcContent = '[ar:艺术家名称]';
        final result = parser.parse(lrcContent);
        expect(result.artist, '艺术家名称');
      });

      test('解析专辑元数据应正确', () {
        const lrcContent = '[al:专辑名称]';
        final result = parser.parse(lrcContent);
        expect(result.album, '专辑名称');
      });

      test('解析歌词作者元数据应正确', () {
        const lrcContent = '[au:歌词作者]';
        final result = parser.parse(lrcContent);
        expect(result.author, '歌词作者');
      });

      test('解析时长元数据应正确', () {
        const lrcContent = '[length:03:30]';
        final result = parser.parse(lrcContent);
        expect(result.duration, const Duration(minutes: 3, seconds: 30));
      });

      test('解析多个元数据应正确', () {
        const lrcContent = '''
[ti:歌曲标题]
[ar:艺术家]
[al:专辑]
[au:歌词作者]
[length:04:30]
''';
        final result = parser.parse(lrcContent);

        expect(result.title, '歌曲标题');
        expect(result.artist, '艺术家');
        expect(result.album, '专辑');
        expect(result.author, '歌词作者');
        expect(result.duration, const Duration(minutes: 4, seconds: 30));
      });
    });

    group('LRC 格式输出', () {
      test('将歌词转换为 LRC 格式应正确', () {
        const lrcContent = '''
[ti:测试歌曲]
[ar:测试艺术家]
[00:00.000]第一行
[00:05.000]第二行
''';
        final result = parser.parse(lrcContent);
        final output = parser.toLrc(result);

        expect(output, contains('[ti:测试歌曲]'));
        expect(output, contains('[ar:测试艺术家]'));
        expect(output, contains('第一行'));
        expect(output, contains('第二行'));
      });

      test('空歌词转换应只包含元数据', () {
        final result = LyricsResult(
          lines: [],
          metadata: {'ti': '测试歌曲'},
          isValid: false,
        );
        final output = parser.toLrc(result);

        expect(output, contains('[ti:测试歌曲]'));
      });
    });

    group('LyricsResult 测试', () {
      test('空结果应正确', () {
        expect(LyricsResult.empty.isValid, isFalse);
        expect(LyricsResult.empty.lines, isEmpty);
        expect(LyricsResult.empty.metadata, isEmpty);
        expect(LyricsResult.empty.title, isNull);
        expect(LyricsResult.empty.artist, isNull);
      });

      test('有效结果应正确', () {
        final result = LyricsResult(
          lines: [
            const LyricLine(timestamp: Duration.zero, text: '测试'),
          ],
          metadata: {'ti': '标题'},
          isValid: true,
        );

        expect(result.isValid, isTrue);
        expect(result.lines.length, 1);
        expect(result.title, '标题');
      });
    });
  });
}
