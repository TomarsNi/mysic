import 'package:sqflite/sqflite.dart';
import '../../../core/database/database_helper.dart';
import '../../player/data/models/song.dart';
import '../../player/data/models/playlist.dart';

/// 歌单数据仓库
/// 负责歌单的 CRUD 操作和持久化
class PlaylistRepository {
  final DatabaseHelper _dbHelper;

  PlaylistRepository({DatabaseHelper? dbHelper})
      : _dbHelper = dbHelper ?? DatabaseHelper();

  /// 获取数据库实例
  Future<Database> get _db async => await _dbHelper.database;

  // ==================== 歌单操作 ====================

  /// 创建系统歌单
  Future<Playlist> createSystemPlaylist({
    required String name,
    String? description,
  }) async {
    final db = await _db;
    final now = DateTime.now();

    final id = await db.insert(
      DatabaseHelper.tablePlaylists,
      {
        'name': name,
        'description': description,
        'is_system': 1,
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      },
    );

    return Playlist(
      id: id,
      name: name,
      description: description,
      isSystem: true,
      createdAt: now,
      updatedAt: now,
      songs: [],
    );
  }

  /// 获取系统歌单
  Future<Playlist?> getSystemPlaylist() async {
    final db = await _db;
    final List<Map<String, dynamic>> maps = await db.query(
      DatabaseHelper.tablePlaylists,
      where: 'is_system = ?',
      whereArgs: [1],
      limit: 1,
    );

    if (maps.isEmpty) return null;

    final playlist = Playlist.fromMap(maps.first);
    final songs = await getSongsInPlaylist(playlist.id!);
    return playlist.copyWith(songs: songs);
  }

  /// 获取名为"本地音乐"的歌单（无论是否为系统歌单）
  Future<Playlist?> getLocalMusicPlaylist() async {
    final db = await _db;
    final List<Map<String, dynamic>> maps = await db.query(
      DatabaseHelper.tablePlaylists,
      where: 'name = ?',
      whereArgs: ['本地音乐'],
      limit: 1,
    );

    if (maps.isEmpty) return null;

    final playlist = Playlist.fromMap(maps.first);
    final songs = await getSongsInPlaylist(playlist.id!);
    return playlist.copyWith(songs: songs);
  }

  /// 将歌单升级为系统歌单
  Future<void> upgradeToSystemPlaylist(int playlistId) async {
    final db = await _db;
    await db.update(
      DatabaseHelper.tablePlaylists,
      {'is_system': 1},
      where: 'id = ?',
      whereArgs: [playlistId],
    );
  }

  /// 获取系统歌单 ID
  Future<int?> getSystemPlaylistId() async {
    final db = await _db;
    final result = await db.query(
      DatabaseHelper.tablePlaylists,
      columns: ['id'],
      where: 'is_system = ?',
      whereArgs: [1],
      limit: 1,
    );

    if (result.isEmpty) return null;
    return result.first['id'] as int;
  }

  /// 创建新歌单
  Future<Playlist> createPlaylist({
    required String name,
    String? description,
    String? coverPath,
  }) async {
    final db = await _db;
    final now = DateTime.now();

    final id = await db.insert(
      DatabaseHelper.tablePlaylists,
      {
        'name': name,
        'description': description,
        'cover_path': coverPath,
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      },
    );

    return Playlist(
      id: id,
      name: name,
      description: description,
      coverPath: coverPath,
      createdAt: now,
      updatedAt: now,
      songs: [],
    );
  }

  /// 获取所有歌单（不含歌曲）
  /// 系统歌单排在前面，其他歌单按更新时间降序
  Future<List<Playlist>> getAllPlaylists() async {
    final db = await _db;
    final List<Map<String, dynamic>> maps = await db.query(
      DatabaseHelper.tablePlaylists,
      orderBy: 'is_system DESC, updated_at DESC',
    );

    return maps.map((map) => Playlist.fromMap(map)).toList();
  }

  /// 获取所有歌单（含歌曲）
  Future<List<Playlist>> getAllPlaylistsWithSongs() async {
    final playlists = await getAllPlaylists();
    final result = <Playlist>[];

    for (final playlist in playlists) {
      final songs = await getSongsInPlaylist(playlist.id!);
      result.add(playlist.copyWith(songs: songs));
    }

    return result;
  }

  /// 根据 ID 获取歌单
  Future<Playlist?> getPlaylistById(int id) async {
    final db = await _db;
    final List<Map<String, dynamic>> maps = await db.query(
      DatabaseHelper.tablePlaylists,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (maps.isEmpty) return null;

    final playlist = Playlist.fromMap(maps.first);
    final songs = await getSongsInPlaylist(id);
    return playlist.copyWith(songs: songs);
  }

  /// 更新歌单信息
  Future<bool> updatePlaylist(Playlist playlist) async {
    if (playlist.id == null) return false;

    final db = await _db;
    final count = await db.update(
      DatabaseHelper.tablePlaylists,
      playlist.toMap(),
      where: 'id = ?',
      whereArgs: [playlist.id],
    );

    return count > 0;
  }

  /// 更新歌单名称
  Future<bool> updatePlaylistName(int playlistId, String newName) async {
    final db = await _db;
    final count = await db.update(
      DatabaseHelper.tablePlaylists,
      {
        'name': newName,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [playlistId],
    );

    return count > 0;
  }

  /// 删除歌单
  /// 系统歌单不可删除
  Future<bool> deletePlaylist(int playlistId) async {
    final db = await _db;

    // 检查是否为系统歌单（仅查询 is_system 列，避免加载歌曲）
    final result = await db.query(
      DatabaseHelper.tablePlaylists,
      columns: ['is_system'],
      where: 'id = ?',
      whereArgs: [playlistId],
      limit: 1,
    );
    if (result.isNotEmpty && result.first['is_system'] == 1) {
      return false; // 系统歌单不可删除
    }

    // 先删除歌单中的歌曲关联
    await db.delete(
      DatabaseHelper.tablePlaylistSongs,
      where: 'playlist_id = ?',
      whereArgs: [playlistId],
    );

    // 再删除歌单
    final count = await db.delete(
      DatabaseHelper.tablePlaylists,
      where: 'id = ?',
      whereArgs: [playlistId],
    );

    return count > 0;
  }

  /// 搜索歌单
  Future<List<Playlist>> searchPlaylists(String query) async {
    final db = await _db;
    final List<Map<String, dynamic>> maps = await db.query(
      DatabaseHelper.tablePlaylists,
      where: 'name LIKE ? OR description LIKE ?',
      whereArgs: ['%$query%', '%$query%'],
      orderBy: 'updated_at DESC',
    );

    return maps.map((map) => Playlist.fromMap(map)).toList();
  }

  // ==================== 歌单歌曲操作 ====================

  /// 添加歌曲到歌单
  Future<bool> addSongToPlaylist(int playlistId, Song song) async {
    // 确保歌曲已保存到数据库
    final savedSong = await saveSong(song);
    if (savedSong.id == null) return false;

    final db = await _db;

    // 检查歌曲是否已在歌单中
    final existing = await db.query(
      DatabaseHelper.tablePlaylistSongs,
      where: 'playlist_id = ? AND song_id = ?',
      whereArgs: [playlistId, savedSong.id],
      limit: 1,
    );

    if (existing.isNotEmpty) return false; // 已存在

    // 获取当前最大位置
    final maxPosition = await _getMaxPosition(playlistId);

    // 添加关联
    await db.insert(
      DatabaseHelper.tablePlaylistSongs,
      {
        'playlist_id': playlistId,
        'song_id': savedSong.id,
        'position': maxPosition + 1,
        'added_at': DateTime.now().toIso8601String(),
      },
    );

    // 更新歌单的 updated_at
    await _updatePlaylistTimestamp(playlistId);

    return true;
  }

  /// 批量添加歌曲到歌单
  Future<int> addSongsToPlaylist(int playlistId, List<Song> songs) async {
    int addedCount = 0;
    for (final song in songs) {
      final success = await addSongToPlaylist(playlistId, song);
      if (success) addedCount++;
    }
    return addedCount;
  }

  /// 从歌单移除歌曲
  Future<bool> removeSongFromPlaylist(int playlistId, int songId) async {
    final db = await _db;

    final count = await db.delete(
      DatabaseHelper.tablePlaylistSongs,
      where: 'playlist_id = ? AND song_id = ?',
      whereArgs: [playlistId, songId],
    );

    if (count > 0) {
      // 更新歌单的 updated_at
      await _updatePlaylistTimestamp(playlistId);
      // 重新排序位置
      await _reorderPlaylistPositions(playlistId);
    }

    return count > 0;
  }

  /// 获取歌单中的歌曲
  Future<List<Song>> getSongsInPlaylist(int playlistId) async {
    final db = await _db;

    // 查询歌单中的歌曲 ID 和位置
    final playlistSongs = await db.query(
      DatabaseHelper.tablePlaylistSongs,
      where: 'playlist_id = ?',
      whereArgs: [playlistId],
      orderBy: 'position ASC',
    );

    if (playlistSongs.isEmpty) return [];

    // 获取歌曲详情
    final songs = <Song>[];
    for (final ps in playlistSongs) {
      final songId = ps['song_id'] as int;
      final song = await getSongById(songId);
      if (song != null) {
        songs.add(song);
      }
    }

    return songs;
  }

  /// 移动歌曲位置
  Future<bool> moveSongPosition(
    int playlistId,
    int songId,
    int newPosition,
  ) async {
    final db = await _db;

    // 获取当前位置
    final current = await db.query(
      DatabaseHelper.tablePlaylistSongs,
      where: 'playlist_id = ? AND song_id = ?',
      whereArgs: [playlistId, songId],
      limit: 1,
    );

    if (current.isEmpty) return false;

    final currentPosition = current.first['position'] as int;

    // 更新其他歌曲的位置
    if (newPosition < currentPosition) {
      // 向前移动
      await db.rawUpdate('''
        UPDATE ${DatabaseHelper.tablePlaylistSongs}
        SET position = position + 1
        WHERE playlist_id = ? AND position >= ? AND position < ?
      ''', [playlistId, newPosition, currentPosition]);
    } else {
      // 向后移动
      await db.rawUpdate('''
        UPDATE ${DatabaseHelper.tablePlaylistSongs}
        SET position = position - 1
        WHERE playlist_id = ? AND position > ? AND position <= ?
      ''', [playlistId, currentPosition, newPosition]);
    }

    // 更新目标歌曲位置
    await db.update(
      DatabaseHelper.tablePlaylistSongs,
      {'position': newPosition},
      where: 'playlist_id = ? AND song_id = ?',
      whereArgs: [playlistId, songId],
    );

    return true;
  }

  // ==================== 歌曲操作 ====================

  /// 保存歌曲到数据库
  Future<Song> saveSong(Song song) async {
    // 先检查是否已存在
    final existing = await getSongByPath(song.filePath);
    if (existing != null) return existing;

    final db = await _db;
    final now = DateTime.now();

    final songToSave = song.copyWith(
      createdAt: song.createdAt,
      updatedAt: now,
    );

    final id = await db.insert(
      DatabaseHelper.tableSongs,
      songToSave.toMap(),
    );

    return songToSave.copyWith(id: id);
  }

  /// 批量保存歌曲
  Future<List<Song>> saveSongs(List<Song> songs) async {
    final result = <Song>[];
    for (final song in songs) {
      result.add(await saveSong(song));
    }
    return result;
  }

  /// 根据 ID 获取歌曲
  Future<Song?> getSongById(int id) async {
    final db = await _db;
    final List<Map<String, dynamic>> maps = await db.query(
      DatabaseHelper.tableSongs,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (maps.isEmpty) return null;
    return Song.fromMap(maps.first);
  }

  /// 根据文件路径获取歌曲
  Future<Song?> getSongByPath(String filePath) async {
    final db = await _db;
    final List<Map<String, dynamic>> maps = await db.query(
      DatabaseHelper.tableSongs,
      where: 'file_path = ?',
      whereArgs: [filePath],
      limit: 1,
    );

    if (maps.isEmpty) return null;
    return Song.fromMap(maps.first);
  }

  /// 获取所有歌曲
  Future<List<Song>> getAllSongs() async {
    final db = await _db;
    final List<Map<String, dynamic>> maps = await db.query(
      DatabaseHelper.tableSongs,
      orderBy: 'title ASC',
    );

    return maps.map((map) => Song.fromMap(map)).toList();
  }

  /// 搜索歌曲
  Future<List<Song>> searchSongs(String query) async {
    final db = await _db;
    final List<Map<String, dynamic>> maps = await db.query(
      DatabaseHelper.tableSongs,
      where: 'title LIKE ? OR artist LIKE ? OR album LIKE ?',
      whereArgs: ['%$query%', '%$query%', '%$query%'],
      orderBy: 'title ASC',
    );

    return maps.map((map) => Song.fromMap(map)).toList();
  }

  /// 删除歌曲
  Future<bool> deleteSong(int songId) async {
    final db = await _db;

    // 先删除歌单关联
    await db.delete(
      DatabaseHelper.tablePlaylistSongs,
      where: 'song_id = ?',
      whereArgs: [songId],
    );

    // 删除歌词
    await db.delete(
      DatabaseHelper.tableLyrics,
      where: 'song_id = ?',
      whereArgs: [songId],
    );

    // 删除播放历史
    await db.delete(
      DatabaseHelper.tablePlayHistory,
      where: 'song_id = ?',
      whereArgs: [songId],
    );

    // 删除排除记录
    await db.delete(
      DatabaseHelper.tableExcludedSongs,
      where: 'song_id = ?',
      whereArgs: [songId],
    );

    // 删除歌曲
    final count = await db.delete(
      DatabaseHelper.tableSongs,
      where: 'id = ?',
      whereArgs: [songId],
    );

    return count > 0;
  }

  /// 获取歌曲总数
  Future<int> getSongCount() async {
    final db = await _db;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM ${DatabaseHelper.tableSongs}',
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// 检查歌曲是否在歌单中
  Future<bool> isSongInPlaylist(int playlistId, int songId) async {
    final db = await _db;
    final result = await db.query(
      DatabaseHelper.tablePlaylistSongs,
      where: 'playlist_id = ? AND song_id = ?',
      whereArgs: [playlistId, songId],
      limit: 1,
    );
    return result.isNotEmpty;
  }

  /// 从所有歌单中移除指定歌曲
  Future<int> removeFromAllPlaylists(int songId) async {
    final db = await _db;

    // 获取包含该歌曲的所有歌单 ID
    final playlistSongs = await db.query(
      DatabaseHelper.tablePlaylistSongs,
      columns: ['playlist_id'],
      where: 'song_id = ?',
      whereArgs: [songId],
    );

    final playlistIds =
        playlistSongs.map((ps) => ps['playlist_id'] as int).toSet();

    // 删除所有关联
    final count = await db.delete(
      DatabaseHelper.tablePlaylistSongs,
      where: 'song_id = ?',
      whereArgs: [songId],
    );

    // 更新相关歌单的时间戳并重新排序位置
    for (final playlistId in playlistIds) {
      await _updatePlaylistTimestamp(playlistId);
      await _reorderPlaylistPositions(playlistId);
    }

    return count;
  }

  // ==================== 辅助方法 ====================

  /// 获取歌单最大位置
  Future<int> _getMaxPosition(int playlistId) async {
    final db = await _db;
    final result = await db.rawQuery(
      'SELECT MAX(position) as max_pos FROM ${DatabaseHelper.tablePlaylistSongs} WHERE playlist_id = ?',
      [playlistId],
    );
    return (result.first['max_pos'] as int?) ?? -1;
  }

  /// 更新歌单时间戳
  Future<void> _updatePlaylistTimestamp(int playlistId) async {
    final db = await _db;
    await db.update(
      DatabaseHelper.tablePlaylists,
      {'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [playlistId],
    );
  }

  /// 重新排序歌单位置
  Future<void> _reorderPlaylistPositions(int playlistId) async {
    final db = await _db;

    // 获取所有歌曲按当前位置排序
    final songs = await db.query(
      DatabaseHelper.tablePlaylistSongs,
      where: 'playlist_id = ?',
      whereArgs: [playlistId],
      orderBy: 'position ASC',
    );

    // 重新分配位置
    for (var i = 0; i < songs.length; i++) {
      await db.update(
        DatabaseHelper.tablePlaylistSongs,
        {'position': i},
        where: 'id = ?',
        whereArgs: [songs[i]['id']],
      );
    }
  }

  // ==================== 播放历史操作 ====================

  /// 记录播放历史
  Future<void> recordPlayHistory(int songId, {int? playDuration}) async {
    final db = await _db;
    await db.insert(
      DatabaseHelper.tablePlayHistory,
      {
        'song_id': songId,
        'played_at': DateTime.now().toIso8601String(),
        'play_duration': playDuration,
      },
    );
  }

  /// 获取播放历史
  Future<List<Song>> getPlayHistory({int limit = 50}) async {
    final db = await _db;

    final history = await db.query(
      DatabaseHelper.tablePlayHistory,
      orderBy: 'played_at DESC',
      limit: limit,
    );

    final songs = <Song>[];
    for (final h in history) {
      final song = await getSongById(h['song_id'] as int);
      if (song != null) {
        songs.add(song);
      }
    }

    return songs;
  }

  /// 清空播放历史
  Future<void> clearPlayHistory() async {
    final db = await _db;
    await db.delete(DatabaseHelper.tablePlayHistory);
  }

  // ==================== 统计信息 ====================

  /// 获取歌单数量
  Future<int> getPlaylistCount() async {
    final db = await _db;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM ${DatabaseHelper.tablePlaylists}',
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// 获取歌单歌曲数量
  Future<int> getPlaylistSongCount(int playlistId) async {
    final db = await _db;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM ${DatabaseHelper.tablePlaylistSongs} WHERE playlist_id = ?',
      [playlistId],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  // ==================== 应用状态操作 ====================

  /// 获取应用状态
  Future<String?> getAppState(String key) async {
    final db = await _db;
    final result = await db.query(
      DatabaseHelper.tableAppState,
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (result.isEmpty) return null;
    return result.first['value'] as String?;
  }

  /// 设置应用状态
  Future<void> setAppState(String key, String value) async {
    final db = await _db;
    await db.insert(
      DatabaseHelper.tableAppState,
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // ==================== 排除歌曲操作 ====================

  /// 获取排除歌曲 ID 列表
  Future<Set<int>> getExcludedSongIds() async {
    final db = await _db;
    final result = await db.query(
      DatabaseHelper.tableExcludedSongs,
      columns: ['song_id'],
    );

    return result.map((row) => row['song_id'] as int).toSet();
  }

  /// 添加歌曲到排除列表
  Future<void> excludeSong(int songId) async {
    final db = await _db;
    await db.insert(
      DatabaseHelper.tableExcludedSongs,
      {
        'song_id': songId,
        'excluded_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  /// 从排除列表移除歌曲
  Future<void> restoreSong(int songId) async {
    final db = await _db;
    await db.delete(
      DatabaseHelper.tableExcludedSongs,
      where: 'song_id = ?',
      whereArgs: [songId],
    );
  }

  /// 检查歌曲是否被排除
  Future<bool> isSongExcluded(int songId) async {
    final db = await _db;
    final result = await db.query(
      DatabaseHelper.tableExcludedSongs,
      where: 'song_id = ?',
      whereArgs: [songId],
      limit: 1,
    );
    return result.isNotEmpty;
  }
}
