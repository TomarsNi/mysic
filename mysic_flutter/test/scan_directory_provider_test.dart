import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:mysic_flutter/core/database/database_helper.dart';
import 'package:mysic_flutter/shared/utils/scan_directory_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('ScanDirectoryProvider', () {
    late ScanDirectoryProvider provider;
    late DatabaseHelper dbHelper;

    setUp(() async {
      dbHelper = DatabaseHelper();
      await dbHelper.deleteDatabase();
      provider = ScanDirectoryProvider();
    });

    tearDown(() async {
      await dbHelper.close();
    });

    test('getDirectories returns default directories when empty', () async {
      final directories = await provider.getDirectories();
      expect(directories, isNotEmpty);
      expect(directories, contains('Music'));
      expect(directories, contains('音乐'));
    });

    test('addDirectory adds a new directory', () async {
      await provider.addDirectory('MyMusic');
      final directories = await provider.getDirectories();
      expect(directories, contains('MyMusic'));
    });

    test('removeDirectory removes a directory', () async {
      await provider.addDirectory('TestDir');
      await provider.removeDirectory('TestDir');
      final directories = await provider.getDirectories();
      expect(directories, isNot(contains('TestDir')));
    });

    test('resetToDefault resets to default directories', () async {
      await provider.addDirectory('CustomDir');
      await provider.resetToDefault();
      final directories = await provider.getDirectories();
      expect(directories, isNot(contains('CustomDir')));
      expect(directories, contains('Music'));
    });
  });
}
