import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:mysic_flutter/core/database/database_helper.dart';
import 'package:mysic_flutter/shared/utils/scan_directory_provider.dart';
import 'package:mysic_flutter/shared/utils/mobile_music_scanner.dart';
import 'package:mysic_flutter/shared/utils/platform_music_scanner.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('MobileMusicScanner scanMusicInDirectory', () {
    test('should return error when scanning is in progress', () async {
      final scanner = MobileMusicScanner();
      scanner.updateState(ScanState.scanning);

      final result = await scanner.scanMusicInDirectory('/storage/emulated/0/Music');

      expect(result.isSuccess, isFalse);
      expect(result.errorMessage, contains('扫描正在进行中'));

      scanner.updateState(ScanState.idle);
      await scanner.dispose();
    });
  });

  group('MobileMusicScanner directory filtering', () {
    late DatabaseHelper dbHelper;

    setUp(() async {
      dbHelper = DatabaseHelper();
      await dbHelper.deleteDatabase();
    });

    tearDown(() async {
      await dbHelper.close();
    });

    test('getScanRootsForTest returns only configured directories', () async {
      final provider = ScanDirectoryProvider();
      await provider.resetToDefault();

      final scanner = MobileMusicScanner();
      final roots = await scanner.getScanRootsForTest();

      // 验证返回的根目录都在配置的目录名列表中
      final dirNames = await provider.getDirectories();
      for (final root in roots) {
        final parts = root.split('/');
        final dirName = parts.isNotEmpty ? parts.last : '';
        expect(dirNames, contains(dirName));
      }
    });
  });
}
