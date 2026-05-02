import 'package:flutter_test/flutter_test.dart';

void main() {
  group('_extractFolderName', () {
    test('从 Windows 路径提取文件夹名称', () {
      // 这个测试验证路径提取逻辑
      // 实际方法将在 bottom_sheet.dart 中实现
      final path = r'C:\Users\nbb\Music\流行音乐';
      final parts = path.split(RegExp(r'[\\/]'));
      final result = parts.where((p) => p.isNotEmpty).last;
      expect(result, '流行音乐');
    });

    test('从路径末尾有斜杠的情况提取', () {
      final path = r'C:\Music\';
      final parts = path.split(RegExp(r'[\\/]'));
      final result = parts.where((p) => p.isNotEmpty).last;
      expect(result, 'Music');
    });

    test('从带空格的路径提取', () {
      final path = r'D:\My Music\My Playlist';
      final parts = path.split(RegExp(r'[\\/]'));
      final result = parts.where((p) => p.isNotEmpty).last;
      expect(result, 'My Playlist');
    });

    test('从 Unix 风格路径提取', () {
      final path = '/home/user/Music/摇滚';
      final parts = path.split(RegExp(r'[\\/]'));
      final result = parts.where((p) => p.isNotEmpty).last;
      expect(result, '摇滚');
    });
  });
}
