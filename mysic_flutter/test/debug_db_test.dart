import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite/sqflite.dart';
import 'package:mysic_flutter/core/database/database_helper.dart';
import 'package:mysic_flutter/features/playlist/data/playlist_repository.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('检查数据库内容', () async {
    final dbHelper = DatabaseHelper();
    final db = await dbHelper.database;
    
    final path = await getDatabasesPath();
    print('Database path: $path');
    print('Database file: ${db.path}');
    
    // 查询所有歌单
    final playlists = await db.query(DatabaseHelper.tablePlaylists);
    print('\n歌单列表 (${playlists.length} 个):');
    for (final p in playlists) {
      print('  id=${p['id']}, name=${p['name']}, is_system=${p['is_system']}');
    }
    
    await dbHelper.close();
  });
}
