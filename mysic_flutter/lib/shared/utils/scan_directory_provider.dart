import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../../core/database/database_helper.dart';
import 'scan_directory_config.dart';

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
  static const String _keyScanDirectoryConfigs = 'scan_directory_configs';

  /// 获取扫描目录列表（旧格式，保持兼容）
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

  /// 获取目录配置列表（新格式）
  Future<List<ScanDirectoryConfig>> getConfigs() async {
    final db = await _dbHelper.database;
    final result = await db.query(
      DatabaseHelper.tableSettings,
      where: 'key = ?',
      whereArgs: [_keyScanDirectoryConfigs],
    );

    if (result.isEmpty) {
      return [];
    }

    final value = result.first['value'] as String;
    final List<dynamic> jsonList = jsonDecode(value);
    return jsonList
        .map((json) => ScanDirectoryConfig.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// 添加扫描目录（旧格式，保持兼容）
  Future<void> addDirectory(String directory) async {
    final trimmed = directory.trim();
    if (trimmed.isEmpty) return;

    final directories = List<String>.from(await getDirectories());
    if (!directories.contains(trimmed)) {
      directories.add(trimmed);
      await _saveDirectories(directories);
    }
  }

  /// 添加目录并关联歌单（新格式）
  Future<void> addDirectoryWithPlaylist(
    String directory, {
    int? playlistId,
    String? playlistName,
  }) async {
    final trimmed = directory.trim();
    if (trimmed.isEmpty) return;

    final configs = List<ScanDirectoryConfig>.from(await getConfigs());
    final existingIndex = configs.indexWhere((c) => c.directory == trimmed);

    if (existingIndex >= 0) {
      // 已存在，更新歌单关联
      configs[existingIndex] = configs[existingIndex].copyWith(
        playlistId: playlistId,
        playlistName: playlistName,
      );
    } else {
      // 新增
      configs.add(ScanDirectoryConfig(
        directory: trimmed,
        playlistId: playlistId,
        playlistName: playlistName,
      ));
    }

    await _saveConfigs(configs);
  }

  /// 更新目录的歌单关联
  Future<void> updateDirectoryPlaylist(
    String directory,
    int playlistId,
    String playlistName,
  ) async {
    final configs = List<ScanDirectoryConfig>.from(await getConfigs());
    final index = configs.indexWhere((c) => c.directory == directory);

    if (index >= 0) {
      configs[index] = configs[index].copyWith(
        playlistId: playlistId,
        playlistName: playlistName,
      );
      await _saveConfigs(configs);
    }
  }

  /// 根据目录名获取配置
  Future<ScanDirectoryConfig?> getConfigByDirectory(String directory) async {
    final configs = await getConfigs();
    for (final config in configs) {
      if (config.directory == directory) {
        return config;
      }
    }
    return null;
  }

  /// 移除扫描目录（旧格式，保持兼容）
  Future<void> removeDirectory(String directory) async {
    final directories = List<String>.from(await getDirectories());
    directories.remove(directory);
    await _saveDirectories(directories);
  }

  /// 移除目录配置（新格式）
  Future<void> removeConfig(String directory) async {
    final configs = List<ScanDirectoryConfig>.from(await getConfigs());
    configs.removeWhere((c) => c.directory == directory);
    await _saveConfigs(configs);
  }

  /// 重置为默认目录（旧格式，保持兼容）
  Future<void> resetToDefault() async {
    await _saveDirectories(kDefaultScanDirectories);
  }

  /// 检测并迁移旧格式数据到新格式
  /// 返回迁移后的配置列表
  Future<List<ScanDirectoryConfig>> migrateIfNeeded() async {
    // 检查是否已有新格式数据
    final existingConfigs = await getConfigs();
    if (existingConfigs.isNotEmpty) {
      // 已经是新格式，无需迁移
      return existingConfigs;
    }

    // 获取旧格式数据并迁移
    final directories = await getDirectories();
    final newConfigs = directories
        .map((dir) => ScanDirectoryConfig(directory: dir))
        .toList();

    await _saveConfigs(newConfigs);
    return newConfigs;
  }

  /// 保存目录列表到数据库（旧格式）
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

  /// 保存目录配置列表到数据库（新格式）
  Future<void> _saveConfigs(List<ScanDirectoryConfig> configs) async {
    final db = await _dbHelper.database;
    final now = DateTime.now().toIso8601String();
    final value = jsonEncode(configs.map((c) => c.toJson()).toList());

    await db.insert(
      DatabaseHelper.tableSettings,
      {
        'key': _keyScanDirectoryConfigs,
        'value': value,
        'updated_at': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
