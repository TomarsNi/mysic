import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:mysic_flutter/core/database/database_helper.dart';

void main() {
  // 初始化 sqflite_ffi 用于测试
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('DatabaseHelper settings table', () {
    late DatabaseHelper dbHelper;

    setUp(() async {
      dbHelper = DatabaseHelper();
      await dbHelper.deleteDatabase();
    });

    tearDown(() async {
      await dbHelper.close();
    });

    test('settings table exists after database creation', () async {
      final db = await dbHelper.database;
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='settings'",
      );
      expect(tables, isNotEmpty);
    });

    test('settings table has correct columns', () async {
      final db = await dbHelper.database;
      final columns = await db.rawQuery('PRAGMA table_info(settings)');
      final columnNames = columns.map((c) => c['name'] as String).toList();

      expect(columnNames, contains('key'));
      expect(columnNames, contains('value'));
      expect(columnNames, contains('updated_at'));
    });
  });
}
