import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:mysic_flutter/core/services/file_copy_service.dart';

class FakePathProviderPlatform extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  late Directory _appDir;

  Future<void> setup() async {
    _appDir = await Directory.systemTemp.createTemp('mysic_test_');
  }

  Future<void> cleanup() async {
    if (await _appDir.exists()) {
      await _appDir.delete(recursive: true);
    }
  }

  @override
  Future<String?> getApplicationSupportPath() async => _appDir.path;
}

void main() {
  late FileCopyService service;
  late FakePathProviderPlatform fakePlatform;
  late Directory testDir;

  setUpAll(() async {
    fakePlatform = FakePathProviderPlatform();
    await fakePlatform.setup();
    PathProviderPlatform.instance = fakePlatform;
    service = FileCopyService();
  });

  tearDownAll(() async {
    await fakePlatform.cleanup();
  });

  setUp(() async {
    testDir = await Directory.systemTemp.createTemp('test_files_');
  });

  tearDown(() async {
    if (await testDir.exists()) {
      await testDir.delete(recursive: true);
    }
  });

  group('copyAlbumCover', () {
    test('复制图片到应用目录并返回新路径', () async {
      final sourceFile = File(p.join(testDir.path, 'test.jpg'));
      await sourceFile.writeAsBytes([0xFF, 0xD8, 0xFF, 0xE0]);

      final result = await service.copyAlbumCover(sourceFile.path, 1);

      expect(result, isNotNull);
      expect(result, contains('album_covers'));
      expect(result, contains('1_'));
      expect(result, endsWith('.jpg'));

      final copiedFile = File(result!);
      expect(await copiedFile.exists(), isTrue);
    });

    test('支持 png 扩展名', () async {
      final sourceFile = File(p.join(testDir.path, 'cover.png'));
      await sourceFile.writeAsBytes([0x89, 0x50, 0x4E, 0x47]);

      final result = await service.copyAlbumCover(sourceFile.path, 2);

      expect(result, endsWith('.png'));
    });

    test('源文件不存在时返回 null', () async {
      final result = await service.copyAlbumCover('/nonexistent/file.jpg', 1);
      expect(result, isNull);
    });
  });

  group('copyLyrics', () {
    test('复制歌词文件到应用目录并返回新路径', () async {
      final sourceFile = File(p.join(testDir.path, 'test.lrc'));
      await sourceFile.writeAsString('[00:00.00]Test lyrics');

      final result = await service.copyLyrics(sourceFile.path, 1);

      expect(result, isNotNull);
      expect(result, contains('lyrics'));
      expect(result, contains('1_'));
      expect(result, endsWith('.lrc'));

      final copiedFile = File(result!);
      expect(await copiedFile.readAsString(), equals('[00:00.00]Test lyrics'));
    });

    test('源文件不存在时返回 null', () async {
      final result = await service.copyLyrics('/nonexistent/file.lrc', 1);
      expect(result, isNull);
    });
  });

  group('deleteFile', () {
    test('删除存在的文件', () async {
      final sourceFile = File(p.join(testDir.path, 'to_delete.lrc'));
      await sourceFile.writeAsString('test');

      final result = await service.copyLyrics(sourceFile.path, 1);
      expect(result, isNotNull);

      await service.deleteFile(result);
      expect(await File(result!).exists(), isFalse);
    });

    test('路径为 null 时不执行任何操作', () async {
      await service.deleteFile(null);
    });
  });
}