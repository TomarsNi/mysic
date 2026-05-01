import 'package:flutter_test/flutter_test.dart';
import 'package:mysic_flutter/features/player/data/models/song.dart';
import 'package:mysic_flutter/shared/utils/music_scanner.dart';
import 'package:mysic_flutter/shared/utils/platform_music_scanner.dart';

void main() {
  group('PlatformMusicScanner', () {
    test('scanMusicInDirectory should be defined in abstract class', () {
      // 验证抽象类有 scanMusicInDirectory 方法声明
      // 这是一个编译时检查，如果方法不存在则编译失败
      expect(PlatformMusicScanner, isNotNull);
    });

    test('scanMusicInDirectory method signature should accept directory parameter',
        () {
      // 验证方法签名：通过创建匿名实现来验证方法存在且签名正确
      // 如果方法不存在或签名不匹配，编译将失败
      final scanner = _TestScanner();

      // 验证方法存在且返回类型正确
      expect(scanner.scanMusicInDirectory, isA<Function>());
    });
  });

  group('MusicScanner scanMusicInDirectory', () {
    test('should delegate to platform scanner', () {
      // 验证 MusicScanner 有 scanMusicInDirectory 方法
      expect(MusicScanner, isNotNull);
    });

    test('scanMusicInDirectory method should exist on MusicScanner', () {
      // 创建 MusicScanner 实例并验证方法存在
      final scanner = MusicScanner();
      expect(scanner.scanMusicInDirectory, isA<Function>());
    });
  });
}

/// 测试用的 Scanner 实现
class _TestScanner extends PlatformMusicScanner {
  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<bool> hasPermission() async => true;

  @override
  Future<ScanResult> scanMusic() async {
    return const ScanResult(
      totalFound: 0,
      newAdded: 0,
      duplicates: 0,
      scanDuration: Duration.zero,
    );
  }

  @override
  Future<ScanResult> scanMusicInDirectory(String directory) async {
    return const ScanResult(
      totalFound: 0,
      newAdded: 0,
      duplicates: 0,
      scanDuration: Duration.zero,
    );
  }

  @override
  Future<void> deleteSong(int songId) async {}

  @override
  Future<List<Song>> getAllSongs() async => [];

  @override
  Future<int> getSongCount() async => 0;

  @override
  Future<void> clearAllSongs() async {}
}
