import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mysic_flutter/core/utils/file_utils.dart';

void main() {
  group('FileUtils', () {
    test('删除存在的文件', () async {
      // 创建临时文件
      final tempDir = await Directory.systemTemp.createTemp('file_utils_test_');
      final tempFile = File('${tempDir.path}/test.txt');
      await tempFile.writeAsString('test content');

      expect(await tempFile.exists(), isTrue);

      // 删除文件
      final result = await FileUtils.deleteFile(tempFile.path);
      expect(result, isTrue);
      expect(await tempFile.exists(), isFalse);

      // 清理
      await tempDir.delete(recursive: true);
    });

    test('删除不存在的文件返回 false', () async {
      final result = await FileUtils.deleteFile('/non/existent/file.txt');
      expect(result, isFalse);
    });
  });
}
