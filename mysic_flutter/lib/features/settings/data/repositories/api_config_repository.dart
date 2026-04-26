import 'package:sqflite/sqflite.dart';
import '../../../../core/database/database_helper.dart';
import '../models/api_config.dart';

/// API 配置数据访问层
/// 负责 API 配置的数据库 CRUD 操作
class ApiConfigRepository {
  final DatabaseHelper _dbHelper;

  ApiConfigRepository({DatabaseHelper? dbHelper})
      : _dbHelper = dbHelper ?? DatabaseHelper();

  /// 获取所有配置，按 id 升序
  Future<List<ApiConfig>> getAll() async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      DatabaseHelper.tableApiConfigs,
      orderBy: 'id ASC',
    );
    return maps.map(ApiConfig.fromMap).toList();
  }

  /// 按服务商获取配置
  Future<ApiConfig?> getByProvider(ApiProvider provider) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      DatabaseHelper.tableApiConfigs,
      where: 'provider = ?',
      whereArgs: [provider.toValueString()],
    );
    if (maps.isEmpty) return null;
    return ApiConfig.fromMap(maps.first);
  }

  /// 获取已启用的配置
  Future<ApiConfig?> getEnabled() async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      DatabaseHelper.tableApiConfigs,
      where: 'is_enabled = ?',
      whereArgs: [1],
    );
    if (maps.isEmpty) return null;
    return ApiConfig.fromMap(maps.first);
  }

  /// 保存配置（插入或更新）
  /// - 如果 config.id != null，按 id 更新
  /// - 否则使用 INSERT OR REPLACE 确保原子性
  Future<void> save(ApiConfig config) async {
    final db = await _dbHelper.database;

    if (config.id != null) {
      // 按 id 更新
      await db.update(
        DatabaseHelper.tableApiConfigs,
        config.toMap()..remove('id'),
        where: 'id = ?',
        whereArgs: [config.id],
      );
    } else {
      // 使用 INSERT OR REPLACE 处理 upsert（provider 有 UNIQUE 约束）
      await db.insert(
        DatabaseHelper.tableApiConfigs,
        config.toMap()..remove('id'),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  /// 启用指定服务商（自动禁用其他），使用事务
  Future<void> enableOnly(ApiProvider provider) async {
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      // 先禁用所有配置
      await txn.update(
        DatabaseHelper.tableApiConfigs,
        {'is_enabled': 0},
      );
      // 再启用指定服务商
      await txn.update(
        DatabaseHelper.tableApiConfigs,
        {'is_enabled': 1},
        where: 'provider = ?',
        whereArgs: [provider.toValueString()],
      );
    });
  }

  /// 禁用所有配置
  Future<void> disableAll() async {
    final db = await _dbHelper.database;
    await db.update(
      DatabaseHelper.tableApiConfigs,
      {'is_enabled': 0},
    );
  }

  /// 删除配置
  Future<void> delete(ApiProvider provider) async {
    final db = await _dbHelper.database;
    await db.delete(
      DatabaseHelper.tableApiConfigs,
      where: 'provider = ?',
      whereArgs: [provider.toValueString()],
    );
  }
}
