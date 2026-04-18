import 'package:flutter_test/flutter_test.dart';
import 'package:mysic_flutter/features/lyrics/data/services/lyrics_parser.dart';

void main() {
  group('LyricsParser', () {
    late LyricsParser parser;

    setUp(() {
      parser = LyricsParser();
    });

    group('parse', () {
      test('parses empty content', () {
        final result = parser.parse('');
        expect(result.isValid, isFalse);
        expect(result.lines, isEmpty);
      });

      test('parses whitespace content', () {
        final result = parser.parse('   \n\n   ');
        expect(result.isValid, isFalse);
        expect(result.lines, isEmpty);
      });

      test('parses simple lyrics', () {
        const content = '''
[00:00.000]First line
[00:05.000]Second line
[00:10.000]Third line
''';

        final result = parser.parse(content);

        expect(result.isValid, isTrue);
        expect(result.lines.length, equals(3));
        expect(result.lines[0].text, equals('First line'));
        expect(result.lines[0].timestamp, equals(const Duration(seconds: 0)));
        expect(result.lines[1].text, equals('Second line'));
        expect(result.lines[1].timestamp, equals(const Duration(seconds: 5)));
        expect(result.lines[2].text, equals('Third line'));
        expect(result.lines[2].timestamp, equals(const Duration(seconds: 10)));
      });

      test('parses metadata', () {
        const content = '''
[ti:Song Title]
[ar:Artist Name]
[al:Album Name]
[00:00.000]First line
''';

        final result = parser.parse(content);

        expect(result.title, equals('Song Title'));
        expect(result.artist, equals('Artist Name'));
        expect(result.album, equals('Album Name'));
      });

      test('parses time tags without milliseconds', () {
        const content = '''
[00:00]First line
[01:30]Second line
''';

        final result = parser.parse(content);

        expect(result.lines.length, equals(2));
        expect(result.lines[0].timestamp, equals(const Duration(seconds: 0)));
        expect(result.lines[1].timestamp, equals(const Duration(minutes: 1, seconds: 30)));
      });

      test('parses time tags with colon separator', () {
        const content = '''
[00:00:000]First line
[01:30:500]Second line
''';

        final result = parser.parse(content);

        expect(result.lines.length, equals(2));
        expect(result.lines[0].timestamp, equals(const Duration(seconds: 0)));
        expect(result.lines[1].timestamp, equals(const Duration(minutes: 1, seconds: 30, milliseconds: 500)));
      });

      test('handles multiple time tags on same line', () {
        const content = '[00:00.000][00:10.000]Same text';

        final result = parser.parse(content);

        expect(result.lines.length, equals(2));
        expect(result.lines[0].text, equals('Same text'));
        expect(result.lines[0].timestamp, equals(const Duration(seconds: 0)));
        expect(result.lines[1].text, equals('Same text'));
        expect(result.lines[1].timestamp, equals(const Duration(seconds: 10)));
      });

      test('sorts lines by timestamp', () {
        const content = '''
[00:10.000]Third
[00:00.000]First
[00:05.000]Second
''';

        final result = parser.parse(content);

        expect(result.lines.length, equals(3));
        expect(result.lines[0].text, equals('First'));
        expect(result.lines[1].text, equals('Second'));
        expect(result.lines[2].text, equals('Third'));
      });

      test('ignores empty lines', () {
        const content = '''
[00:00.000]First line

[00:05.000]Second line

''';

        final result = parser.parse(content);

        expect(result.lines.length, equals(2));
      });

      test('handles lines without time tags', () {
        const content = '''
This is not a lyric line
[00:00.000]First line
Another line without time tag
[00:05.000]Second line
''';

        final result = parser.parse(content);

        expect(result.lines.length, equals(2));
        expect(result.lines[0].text, equals('First line'));
        expect(result.lines[1].text, equals('Second line'));
      });
    });

    group('LyricsResult', () {
      test('getCurrentLineIndex returns correct index', () {
        final lines = [
          const LyricLine(timestamp: Duration(seconds: 0), text: 'Line 1'),
          const LyricLine(timestamp: Duration(seconds: 5), text: 'Line 2'),
          const LyricLine(timestamp: Duration(seconds: 10), text: 'Line 3'),
        ];

        final result = LyricsResult(lines: lines, metadata: {});

        expect(result.getCurrentLineIndex(const Duration(seconds: 0)), equals(0));
        expect(result.getCurrentLineIndex(const Duration(seconds: 3)), equals(0));
        expect(result.getCurrentLineIndex(const Duration(seconds: 5)), equals(1));
        expect(result.getCurrentLineIndex(const Duration(seconds: 8)), equals(1));
        expect(result.getCurrentLineIndex(const Duration(seconds: 10)), equals(2));
        expect(result.getCurrentLineIndex(const Duration(seconds: 20)), equals(2));
      });

      test('getCurrentLine returns correct line', () {
        final lines = [
          const LyricLine(timestamp: Duration(seconds: 0), text: 'Line 1'),
          const LyricLine(timestamp: Duration(seconds: 5), text: 'Line 2'),
          const LyricLine(timestamp: Duration(seconds: 10), text: 'Line 3'),
        ];

        final result = LyricsResult(lines: lines, metadata: {});

        expect(result.getCurrentLine(const Duration(seconds: 3))?.text, equals('Line 1'));
        expect(result.getCurrentLine(const Duration(seconds: 7))?.text, equals('Line 2'));
        expect(result.getCurrentLine(const Duration(seconds: 15))?.text, equals('Line 3'));
      });

      test('empty result returns -1 for getCurrentLineIndex', () {
        const result = LyricsResult.empty;
        expect(result.getCurrentLineIndex(const Duration(seconds: 0)), equals(-1));
      });
    });

    group('LyricLine', () {
      test('creates with timestamp and text', () {
        const line = LyricLine(
          timestamp: Duration(seconds: 10),
          text: 'Test line',
        );

        expect(line.timestamp, equals(const Duration(seconds: 10)));
        expect(line.text, equals('Test line'));
      });

      test('equality works correctly', () {
        const line1 = LyricLine(
          timestamp: Duration(seconds: 10),
          text: 'Test line',
        );

        const line2 = LyricLine(
          timestamp: Duration(seconds: 10),
          text: 'Test line',
        );

        const line3 = LyricLine(
          timestamp: Duration(seconds: 20),
          text: 'Different line',
        );

        expect(line1, equals(line2));
        expect(line1, isNot(equals(line3)));
      });

      test('hashCode is consistent', () {
        const line1 = LyricLine(
          timestamp: Duration(seconds: 10),
          text: 'Test line',
        );

        const line2 = LyricLine(
          timestamp: Duration(seconds: 10),
          text: 'Test line',
        );

        expect(line1.hashCode, equals(line2.hashCode));
      });
    });

    group('toLrc', () {
      test('converts lyrics to LRC format', () {
        final lines = [
          const LyricLine(timestamp: Duration(seconds: 0), text: 'First line'),
          const LyricLine(timestamp: Duration(seconds: 5), text: 'Second line'),
        ];

        final result = LyricsResult(
          lines: lines,
          metadata: {'ti': 'Test Song', 'ar': 'Test Artist'},
        );

        final lrc = parser.toLrc(result);

        expect(lrc, contains('[ti:Test Song]'));
        expect(lrc, contains('[ar:Test Artist]'));
        expect(lrc, contains('[00:00.000]First line'));
        expect(lrc, contains('[00:05.000]Second line'));
      });
    });
  });
}
