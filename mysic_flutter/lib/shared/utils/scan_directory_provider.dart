import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../../core/database/database_helper.dart';

/// 默认扫描目录列表
const List<String> kDefaultScanDirectories = [
  'Music',
  '音乐',
  'Downloads',
  '下载',
  'Download',
  'Audio',
  '音频',
  'Songs',
  '歌曲',
];

/// 扫描目录配置管理类
class ScanDirectoryProvider {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  static const String _keyScanDirectories = 'scan_directories';

  /// 获取扫描目录列表
  Future<List<String>> getDirectories() async {
    final db = await _dbHelper.database;
    final result = await db.query(
      DatabaseHelper.tableSettings,
      where: 'key = ?',
      whereArgs: [_keyScanDirectories],
    );

    if (result.isEmpty) {
      // 首次访问，初始化默认目录
      await _saveDirectories(kDefaultScanDirectories);
      return List.unmodifiable(kDefaultScanDirectories);
    }

    final value = result.first['value'] as String;
    final List<dynamic> jsonList = jsonDecode(value);
    return List.unmodifiable(jsonList.cast<String>());
  }

  /// 添加扫描目录
  Future<void> addDirectory(String directory) async {
    final trimmed = directory.trim();
    if (trimmed.isEmpty) return;

    final directories = List<String>.from(await getDirectories());
    if (!directories.contains(trimmed)) {
      directories.add(trimmed);
      await _saveDirectories(directories);
    }
  }

  /// 移除扫描目录
  Future<void> removeDirectory(String directory) async {
    final directories = List<String>.from(await getDirectories());
    directories.remove(directory);
    await _saveDirectories(directories);
  }

  /// 重置为默认目录
  Future<void> resetToDefault() async {
    await _saveDirectories(kDefaultScanDirectories);
  }

  /// 保存目录列表到数据库
  Future<void> _saveDirectories(List<String> directories) async {
    final db = await _dbHelper.database;
    final now = DateTime.now().toIso8601String();
    final value = jsonEncode(directories);

    await db.insert(
      DatabaseHelper.tableSettings,
      {
        'key': _keyScanDirectories,
        'value': value,
        'updated_at': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
