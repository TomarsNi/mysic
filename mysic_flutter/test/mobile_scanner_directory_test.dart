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

  group('MobileMusicScanner SAF URI conversion', () {
    late MobileMusicScanner scanner;

    setUp(() {
      scanner = MobileMusicScanner();
    });

    tearDown(() async {
      await scanner.dispose();
    });

    test('converts primary:Music SAF URI to file path', () {
      // content://com.android.externalstorage.documents/tree/primary%3AMusic
      final uri = 'content://com.android.externalstorage.documents/tree/primary%3AMusic';
      final result = scanner.convertSafUriToFilePathForTest(uri);
      expect(result, equals('/storage/emulated/0/Music'));
    });

    test('converts primary:Download/MyMusic SAF URI to file path', () {
      // content://com.android.externalstorage.documents/tree/primary%3ADownload%2FMyMusic
      final uri = 'content://com.android.externalstorage.documents/tree/primary%3ADownload%2FMyMusic';
      final result = scanner.convertSafUriToFilePathForTest(uri);
      expect(result, equals('/storage/emulated/0/Download/MyMusic'));
    });

    test('converts raw: path SAF URI to file path', () {
      final uri = 'content://com.android.externalstorage.documents/tree/raw%3A%2Fstorage%2Femulated%2F0%2FMusic';
      final result = scanner.convertSafUriToFilePathForTest(uri);
      expect(result, equals('/storage/emulated/0/Music'));
    });

    test('converts primary: (root) SAF URI to storage root', () {
      final uri = 'content://com.android.externalstorage.documents/tree/primary%3A';
      final result = scanner.convertSafUriToFilePathForTest(uri);
      expect(result, equals('/storage/emulated/0'));
    });

    test('returns null for non-SAF URI', () {
      final result = scanner.convertSafUriToFilePathForTest('/storage/emulated/0/Music');
      expect(result, isNull);
    });

    test('returns null for invalid SAF URI', () {
      final result = scanner.convertSafUriToFilePathForTest('content://invalid');
      expect(result, isNull);
    });
  });

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
