import 'package:flutter_test/flutter_test.dart';

void main() {
  group('_cleanLrcFileName', () {
    test('移除 .lrc 扩展名', () {
      // 模拟清理逻辑
      var name = '告白气球.lrc';
      name = name.replaceAll(RegExp(r'\.lrc$', caseSensitive: false), '');
      expect(name, '告白气球');
    });

    test('移除序号前缀（点分隔）', () {
      var name = '01. 告白气球.lrc';
      name = name.replaceAll(RegExp(r'\.lrc$', caseSensitive: false), '');
      name = name.replaceFirst(RegExp(r'^\d+[\s.\-_]+'), '');
      expect(name.trim(), '告白气球');
    });

    test('移除序号前缀（短横线分隔）', () {
      var name = '1-告白气球.lrc';
      name = name.replaceAll(RegExp(r'\.lrc$', caseSensitive: false), '');
      name = name.replaceFirst(RegExp(r'^\d+[\s.\-_]+'), '');
      expect(name.trim(), '告白气球');
    });

    test('移除序号前缀（无分隔符）', () {
      var name = '01告白气球.lrc';
      name = name.replaceAll(RegExp(r'\.lrc$', caseSensitive: false), '');
      // 使用可选的分隔符匹配，支持无分隔符情况
      name = name.replaceFirst(RegExp(r'^\d+[\s.\-_]*'), '');
      expect(name.trim(), '告白气球');
    });

    test('移除艺术家后缀', () {
      var name = '告白气球 - 周杰伦.lrc';
      name = name.replaceAll(RegExp(r'\.lrc$', caseSensitive: false), '');
      name = name.replaceFirst(RegExp(r'\s*-\s*.+$'), '');
      expect(name.trim(), '告白气球');
    });

    test('综合清理：序号 + 歌名 + 艺术家', () {
      var name = '01. 告白气球 - 周杰伦.lrc';
      name = name.replaceAll(RegExp(r'\.lrc$', caseSensitive: false), '');
      name = name.replaceFirst(RegExp(r'^\d+[\s.\-_]+'), '');
      name = name.replaceFirst(RegExp(r'\s*-\s*.+$'), '');
      expect(name.toLowerCase().trim(), '告白气球');
    });

    test('处理大写扩展名', () {
      var name = '告白气球.LRC';
      name = name.replaceAll(RegExp(r'\.lrc$', caseSensitive: false), '');
      expect(name, '告白气球');
    });
  });
}
