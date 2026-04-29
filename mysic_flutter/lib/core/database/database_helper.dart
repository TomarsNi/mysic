import 'dart:io';
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
  static const int _databaseVersion = 8;

  /// 表名常量
  static const String tableSongs = 'songs';
  static const String tablePlaylists = 'playlists';
  static const String tablePlaylistSongs = 'playlist_songs';
  static const String tableLyrics = 'lyrics';
  static const String tablePlayHistory = 'play_history';
  static const String tableAppState = 'app_state';
  static const String tableApiConfigs = 'api_configs';
  static const String tableSettings = 'settings';

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
        album_art_base64 TEXT,
        lyrics_path TEXT,
        date_added INTEGER,
        is_deleted INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // 创建歌单表
    await db.execute('''
      CREATE TABLE $tablePlaylists (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        description TEXT,
        cover_path TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // 创建歌单-歌曲关联表
    await db.execute('''
      CREATE TABLE $tablePlaylistSongs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        playlist_id INTEGER NOT NULL,
        song_id INTEGER NOT NULL,
        position INTEGER NOT NULL,
        added_at TEXT NOT NULL,
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
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
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

    // 创建应用状态表
    await db.execute('''
      CREATE TABLE $tableAppState (
        key TEXT PRIMARY KEY,
        value TEXT
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

    // 创建 API 配置表
    await db.execute('''
      CREATE TABLE $tableApiConfigs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        provider TEXT NOT NULL UNIQUE,
        api_url TEXT,
        api_key TEXT,
        model_name TEXT,
        is_enabled INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // 创建 API 配置表索引
    await db.execute('''
      CREATE INDEX idx_api_configs_provider ON $tableApiConfigs (provider)
    ''');

    // 创建设置表
    await db.execute('''
      CREATE TABLE $tableSettings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
  }

  /// 数据库升级
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // 版本 1 -> 2: 修复时间戳字段类型
    if (oldVersion < 2) {
      // 由于 SQLite 不支持直接修改列类型，需要重建表
      // 重建 songs 表
      await db.execute('''
        CREATE TABLE songs_new (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          title TEXT NOT NULL,
          artist TEXT,
          album TEXT,
          duration INTEGER NOT NULL,
          file_path TEXT NOT NULL UNIQUE,
          album_art_path TEXT,
          date_added INTEGER,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL
        )
      ''');
      await db.execute('''
        INSERT INTO songs_new (id, title, artist, album, duration, file_path, album_art_path, date_added, created_at, updated_at)
        SELECT id, title, artist, album, duration, file_path, album_art_path, date_added,
               CASE WHEN typeof(created_at) = 'integer' THEN datetime(created_at / 1000, 'unixepoch') ELSE created_at END,
               CASE WHEN typeof(updated_at) = 'integer' THEN datetime(updated_at / 1000, 'unixepoch') ELSE updated_at END
        FROM songs
      ''');
      await db.execute('DROP TABLE songs');
      await db.execute('ALTER TABLE songs_new RENAME TO songs');

      // 重建 playlists 表
      await db.execute('''
        CREATE TABLE playlists_new (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          description TEXT,
          cover_path TEXT,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL
        )
      ''');
      await db.execute('''
        INSERT INTO playlists_new (id, name, description, cover_path, created_at, updated_at)
        SELECT id, name, description, cover_path,
               CASE WHEN typeof(created_at) = 'integer' THEN datetime(created_at / 1000, 'unixepoch') ELSE created_at END,
               CASE WHEN typeof(updated_at) = 'integer' THEN datetime(updated_at / 1000, 'unixepoch') ELSE updated_at END
        FROM playlists
      ''');
      await db.execute('DROP TABLE playlists');
      await db.execute('ALTER TABLE playlists_new RENAME TO playlists');

      // 重建 playlist_songs 表
      await db.execute('''
        CREATE TABLE playlist_songs_new (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          playlist_id INTEGER NOT NULL,
          song_id INTEGER NOT NULL,
          position INTEGER NOT NULL,
          added_at TEXT NOT NULL,
          FOREIGN KEY (playlist_id) REFERENCES playlists (id) ON DELETE CASCADE,
          FOREIGN KEY (song_id) REFERENCES songs (id) ON DELETE CASCADE,
          UNIQUE(playlist_id, song_id)
        )
      ''');
      await db.execute('''
        INSERT INTO playlist_songs_new (id, playlist_id, song_id, position, added_at)
        SELECT id, playlist_id, song_id, position,
               CASE WHEN typeof(added_at) = 'integer' THEN datetime(added_at / 1000, 'unixepoch') ELSE added_at END
        FROM playlist_songs
      ''');
      await db.execute('DROP TABLE playlist_songs');
      await db.execute('ALTER TABLE playlist_songs_new RENAME TO playlist_songs');

      // 重建 lyrics 表
      await db.execute('''
        CREATE TABLE lyrics_new (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          song_id INTEGER NOT NULL UNIQUE,
          lrc_content TEXT,
          is_synced INTEGER NOT NULL DEFAULT 0,
          source TEXT,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          FOREIGN KEY (song_id) REFERENCES songs (id) ON DELETE CASCADE
        )
      ''');
      await db.execute('''
        INSERT INTO lyrics_new (id, song_id, lrc_content, is_synced, source, created_at, updated_at)
        SELECT id, song_id, lrc_content, is_synced, source,
               CASE WHEN typeof(created_at) = 'integer' THEN datetime(created_at / 1000, 'unixepoch') ELSE created_at END,
               CASE WHEN typeof(updated_at) = 'integer' THEN datetime(updated_at / 1000, 'unixepoch') ELSE updated_at END
        FROM lyrics
      ''');
      await db.execute('DROP TABLE lyrics');
      await db.execute('ALTER TABLE lyrics_new RENAME TO lyrics');

      // 重建索引
      await db.execute('CREATE INDEX IF NOT EXISTS idx_songs_title ON songs (title)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_songs_artist ON songs (artist)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_songs_album ON songs (album)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_playlist_songs_playlist ON playlist_songs (playlist_id)');
    }

    // 版本 2 -> 3: 新增 app_state 表
    if (oldVersion < 3) {
      await db.execute('''
        CREATE TABLE $tableAppState (
          key TEXT PRIMARY KEY,
          value TEXT
        )
      ''');
    }

    // 版本 3 -> 4: 新增 is_deleted 字段
    if (oldVersion < 4) {
      await db.execute('ALTER TABLE songs ADD COLUMN is_deleted INTEGER NOT NULL DEFAULT 0');
    }

    // 版本 4 -> 5: 新增 api_configs 表
    if (oldVersion < 5) {
      await db.execute('''
        CREATE TABLE $tableApiConfigs (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          provider TEXT NOT NULL UNIQUE,
          api_url TEXT,
          api_key TEXT,
          model_name TEXT,
          is_enabled INTEGER NOT NULL DEFAULT 0
        )
      ''');
      await db.execute('''
        CREATE INDEX idx_api_configs_provider ON $tableApiConfigs (provider)
      ''');
    }

    // 版本 5 -> 6: 新增 album_art_base64 字段
    if (oldVersion < 6) {
      await db.execute(
        'ALTER TABLE songs ADD COLUMN album_art_base64 TEXT',
      );
    }

    // 版本 6 -> 7: 新增 lyrics_path 字段
    if (oldVersion < 7) {
      await db.execute(
        'ALTER TABLE $tableSongs ADD COLUMN lyrics_path TEXT',
      );
    }

    // 版本 7 -> 8: 新增 settings 表
    if (oldVersion < 8) {
      await db.execute('''
        CREATE TABLE $tableSettings (
          key TEXT PRIMARY KEY,
          value TEXT NOT NULL,
          updated_at TEXT NOT NULL
        )
      ''');
    }
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

  /// 更新或插入歌词内容
  /// 如果歌词记录存在则更新，不存在则插入
  Future<void> updateLyricsContent(int songId, String lrcContent) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();

    // 检查是否已存在记录
    final existing = await db.query(
      tableLyrics,
      where: 'song_id = ?',
      whereArgs: [songId],
    );

    if (existing.isNotEmpty) {
      // 更新现有记录
      await db.update(
        tableLyrics,
        {
          'lrc_content': lrcContent,
          'is_synced': 1,
          'source': 'manual',
          'updated_at': now,
        },
        where: 'song_id = ?',
        whereArgs: [songId],
      );
    } else {
      // 插入新记录
      await db.insert(tableLyrics, {
        'song_id': songId,
        'lrc_content': lrcContent,
        'is_synced': 1,
        'source': 'manual',
        'created_at': now,
        'updated_at': now,
      });
    }
  }

  /// 获取当前时间戳（毫秒）
  static int currentTimestamp() {
    return DateTime.now().millisecondsSinceEpoch;
  }
}
