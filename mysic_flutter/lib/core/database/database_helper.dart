import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';

/// 数据库帮助类
/// 负责数据库的初始化、表创建和基本操作
class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  factory DatabaseHelper() => _instance;

  DatabaseHelper._internal();

  /// 数据库名称
  static const String _databaseName = 'mysic.db';

  /// 数据库版本
  static const int _databaseVersion = 1;

  /// 表名常量
  static const String tableSongs = 'songs';
  static const String tablePlaylists = 'playlists';
  static const String tablePlaylistSongs = 'playlist_songs';
  static const String tableLyrics = 'lyrics';
  static const String tablePlayHistory = 'play_history';

  /// 获取数据库实例
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  /// 初始化数据库
  Future<Database> _initDatabase() async {
    // Windows 平台需要使用 sqflite_common_ffi
    if (Platform.isWindows || Platform.isLinux) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _databaseName);

    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  /// 创建数据库表
  Future<void> _onCreate(Database db, int version) async {
    // 创建歌曲表
    await db.execute('''
      CREATE TABLE $tableSongs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        artist TEXT,
        album TEXT,
        duration INTEGER NOT NULL,
        file_path TEXT NOT NULL UNIQUE,
        album_art_path TEXT,
        date_added INTEGER,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    // 创建歌单表
    await db.execute('''
      CREATE TABLE $tablePlaylists (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        description TEXT,
        cover_path TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    // 创建歌单-歌曲关联表
    await db.execute('''
      CREATE TABLE $tablePlaylistSongs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        playlist_id INTEGER NOT NULL,
        song_id INTEGER NOT NULL,
        position INTEGER NOT NULL,
        added_at INTEGER NOT NULL,
        FOREIGN KEY (playlist_id) REFERENCES $tablePlaylists (id) ON DELETE CASCADE,
        FOREIGN KEY (song_id) REFERENCES $tableSongs (id) ON DELETE CASCADE,
        UNIQUE(playlist_id, song_id)
      )
    ''');

    // 创建歌词表
    await db.execute('''
      CREATE TABLE $tableLyrics (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        song_id INTEGER NOT NULL UNIQUE,
        lrc_content TEXT,
        is_synced INTEGER NOT NULL DEFAULT 0,
        source TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        FOREIGN KEY (song_id) REFERENCES $tableSongs (id) ON DELETE CASCADE
      )
    ''');

    // 创建播放历史表
    await db.execute('''
      CREATE TABLE $tablePlayHistory (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        song_id INTEGER NOT NULL,
        played_at INTEGER NOT NULL,
        play_duration INTEGER,
        FOREIGN KEY (song_id) REFERENCES $tableSongs (id) ON DELETE CASCADE
      )
    ''');

    // 创建索引以提高查询性能
    await db.execute('''
      CREATE INDEX idx_songs_title ON $tableSongs (title)
    ''');
    await db.execute('''
      CREATE INDEX idx_songs_artist ON $tableSongs (artist)
    ''');
    await db.execute('''
      CREATE INDEX idx_songs_album ON $tableSongs (album)
    ''');
    await db.execute('''
      CREATE INDEX idx_playlist_songs_playlist ON $tablePlaylistSongs (playlist_id)
    ''');
    await db.execute('''
      CREATE INDEX idx_play_history_song ON $tablePlayHistory (song_id)
    ''');
    await db.execute('''
      CREATE INDEX idx_play_history_time ON $tablePlayHistory (played_at)
    ''');
  }

  /// 数据库升级
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // 未来版本升级时在此添加迁移逻辑
    // 例如：
    // if (oldVersion < 2) {
    //   await db.execute('ALTER TABLE $tableSongs ADD COLUMN new_column TEXT');
    // }
  }

  /// 关闭数据库
  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }

  /// 删除数据库（用于测试或重置）
  Future<void> deleteDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _databaseName);
    await databaseFactory.deleteDatabase(path);
    _database = null;
  }

  /// 清空所有表数据（保留表结构）
  Future<void> clearAllTables() async {
    final db = await database;
    await db.delete(tablePlayHistory);
    await db.delete(tableLyrics);
    await db.delete(tablePlaylistSongs);
    await db.delete(tablePlaylists);
    await db.delete(tableSongs);
  }

  /// 获取当前时间戳（毫秒）
  static int currentTimestamp() {
    return DateTime.now().millisecondsSinceEpoch;
  }
}
