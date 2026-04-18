import 'dart:async';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sqflite/sqflite.dart';
import '../../features/player/data/models/song.dart';
import '../../core/database/database_helper.dart';

/// 扫描状态
enum ScanState {
  idle,       // 空闲
  scanning,   // 扫描中
  saving,     // 保存中
  completed,  // 完成
  error,      // 错误
}

/// 扫描结果
class ScanResult {
  final int totalFound;
  final int newAdded;
  final int duplicates;
  final Duration scanDuration;
  final String? errorMessage;

  const ScanResult({
    required this.totalFound,
    required this.newAdded,
    required this.duplicates,
    required this.scanDuration,
    this.errorMessage,
  });

  bool get isSuccess => errorMessage == null;
}

/// 音乐扫描服务
/// 使用 on_audio_query 扫描设备中的本地音乐文件
class MusicScanner {
  final OnAudioQuery _audioQuery = OnAudioQuery();
  final DatabaseHelper _dbHelper = DatabaseHelper();

  // 状态流控制器
  final _stateController = StreamController<ScanState>.broadcast();
  final _progressController = StreamController<double>.broadcast();
  final _foundController = StreamController<int>.broadcast();

  // 公开的流
  Stream<ScanState> get stateStream => _stateController.stream;
  Stream<double> get progressStream => _progressController.stream;
  Stream<int> get foundStream => _foundController.stream;

  // 当前状态
  ScanState _state = ScanState.idle;
  ScanState get state => _state;
  bool get isScanning => _state == ScanState.scanning || _state == ScanState.saving;

  /// 请求存储权限
  Future<bool> requestPermission() async {
    final status = await Permission.storage.request();
    if (status.isGranted) {
      return true;
    }

    // Android 13+ 需要请求音频权限
    final audioStatus = await Permission.audio.request();
    return audioStatus.isGranted;
  }

  /// 检查是否有权限
  Future<bool> hasPermission() async {
    final status = await Permission.storage.status;
    if (status.isGranted) {
      return true;
    }

    final audioStatus = await Permission.audio.status;
    return audioStatus.isGranted;
  }

  /// 扫描本地音乐
  /// [onProgress] 可选的进度回调
  Future<ScanResult> scanMusic({
    void Function(double progress, int found)? onProgress,
  }) async {
    if (isScanning) {
      return ScanResult(
        totalFound: 0,
        newAdded: 0,
        duplicates: 0,
        scanDuration: Duration.zero,
        errorMessage: '扫描正在进行中',
      );
    }

    final stopwatch = Stopwatch()..start();

    try {
      // 检查权限
      final hasPerm = await hasPermission();
      if (!hasPerm) {
        final granted = await requestPermission();
        if (!granted) {
          return ScanResult(
            totalFound: 0,
            newAdded: 0,
            duplicates: 0,
            scanDuration: Duration.zero,
            errorMessage: '未获得存储权限',
          );
        }
      }

      _updateState(ScanState.scanning);

      // 查询所有歌曲
      final songs = await _audioQuery.querySongs(
        sortType: SongSortType.TITLE,
        orderType: OrderType.ASC_OR_SMALLER,
        uriType: UriType.EXTERNAL,
      );

      final totalFound = songs.length;
      _foundController.add(totalFound);

      if (totalFound == 0) {
        _updateState(ScanState.completed);
        stopwatch.stop();
        return ScanResult(
          totalFound: 0,
          newAdded: 0,
          duplicates: 0,
          scanDuration: stopwatch.elapsed,
        );
      }

      _updateState(ScanState.saving);

      // 保存到数据库
      final result = await _saveSongsToDatabase(songs, totalFound, onProgress);

      _updateState(ScanState.completed);
      stopwatch.stop();

      return ScanResult(
        totalFound: totalFound,
        newAdded: result['newAdded']!,
        duplicates: result['duplicates']!,
        scanDuration: stopwatch.elapsed,
      );
    } catch (e) {
      _updateState(ScanState.error);
      stopwatch.stop();
      return ScanResult(
        totalFound: 0,
        newAdded: 0,
        duplicates: 0,
        scanDuration: stopwatch.elapsed,
        errorMessage: e.toString(),
      );
    }
  }

  /// 保存歌曲到数据库
  Future<Map<String, int>> _saveSongsToDatabase(
    List<SongModel> songs,
    int total,
    void Function(double, int)? onProgress,
  ) async {
    final db = await _dbHelper.database;
    int newAdded = 0;
    int duplicates = 0;
    final now = DateTime.now();
    final nowTimestamp = now.millisecondsSinceEpoch;

    for (int i = 0; i < songs.length; i++) {
      final songModel = songs[i];

      // 检查是否已存在（根据文件路径）
      final existing = await db.query(
        DatabaseHelper.tableSongs,
        where: 'file_path = ?',
        whereArgs: [songModel.data],
        limit: 1,
      );

      if (existing.isNotEmpty) {
        duplicates++;
      } else {
        // 插入新歌曲
        await db.insert(
          DatabaseHelper.tableSongs,
          {
            'title': songModel.title ?? '未知歌曲',
            'artist': songModel.artist,
            'album': songModel.album,
            'duration': songModel.duration ?? 0,
            'file_path': songModel.data,
            'album_art_path': null, // on_audio_query 不直接提供封面路径
            'date_added': songModel.dateAdded,
            'created_at': nowTimestamp,
            'updated_at': nowTimestamp,
          },
        );
        newAdded++;
      }

      // 更新进度
      final progress = (i + 1) / total;
      _progressController.add(progress);
      onProgress?.call(progress, i + 1);
    }

    return {'newAdded': newAdded, 'duplicates': duplicates};
  }

  /// 从数据库获取所有歌曲
  Future<List<Song>> getAllSongs() async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      DatabaseHelper.tableSongs,
      orderBy: 'title ASC',
    );

    return maps.map((map) => Song.fromMap(map)).toList();
  }

  /// 从数据库获取歌曲数量
  Future<int> getSongCount() async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM ${DatabaseHelper.tableSongs}',
    );
    if (result.isEmpty) return 0;
    return result.first['count'] as int? ?? 0;
  }

  /// 搜索歌曲
  Future<List<Song>> searchSongs(String query) async {
    if (query.isEmpty) return getAllSongs();

    final db = await _dbHelper.database;
    final maps = await db.query(
      DatabaseHelper.tableSongs,
      where: 'title LIKE ? OR artist LIKE ? OR album LIKE ?',
      whereArgs: ['%$query%', '%$query%', '%$query%'],
      orderBy: 'title ASC',
    );

    return maps.map((map) => Song.fromMap(map)).toList();
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

  /// 清空所有歌曲
  Future<void> clearAllSongs() async {
    final db = await _dbHelper.database;
    await db.delete(DatabaseHelper.tableSongs);
  }

  /// 更新状态
  void _updateState(ScanState newState) {
    if (_state != newState) {
      _state = newState;
      _stateController.add(_state);
    }
  }

  /// 重置状态
  void reset() {
    _updateState(ScanState.idle);
    _progressController.add(0);
    _foundController.add(0);
  }

  /// 释放资源
  Future<void> dispose() async {
    await _stateController.close();
    await _progressController.close();
    await _foundController.close();
  }
}
