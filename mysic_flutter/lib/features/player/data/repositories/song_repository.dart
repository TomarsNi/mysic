import '../../../../core/database/database_helper.dart';
import '../models/song.dart';

/// 歌曲数据仓库
/// 负责歌曲的 CRUD 操作
class SongRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  /// 获取所有歌曲
  Future<List<Song>> getAllSongs() async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      DatabaseHelper.tableSongs,
      orderBy: 'title ASC',
    );
    return maps.map((map) => Song.fromMap(map)).toList();
  }

  /// 根据 ID 获取歌曲
  Future<Song?> getSongById(int id) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      DatabaseHelper.tableSongs,
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return Song.fromMap(maps.first);
  }

  /// 更新歌曲信息
  Future<void> updateSong(Song song) async {
    if (song.id == null) return;

    final db = await _dbHelper.database;
    await db.update(
      DatabaseHelper.tableSongs,
      song.toMap(),
      where: 'id = ?',
      whereArgs: [song.id],
    );
  }

  /// 删除歌曲
  Future<void> deleteSong(int songId) async {
    final db = await _dbHelper.database;
    await db.delete(
      DatabaseHelper.tableSongs,
      where: 'id = ?',
      whereArgs: [songId],
    );
  }

  /// 获取歌曲数量
  Future<int> getSongCount() async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM ${DatabaseHelper.tableSongs}',
    );
    if (result.isEmpty) return 0;
    return result.first['count'] as int? ?? 0;
  }
}
