import 'dart:async';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/database/database_helper.dart';
import '../../features/player/data/models/song.dart';
import 'platform_music_scanner.dart';

/// 移动端平台音乐扫描器
class MobileMusicScanner extends PlatformMusicScanner {
  final OnAudioQuery _audioQuery = OnAudioQuery();
  final DatabaseHelper _dbHelper = DatabaseHelper();

  /// 最小时长（毫秒）- 2分45秒 = 165秒 = 165000毫秒
  static const int _minDurationMs = 165 * 1000;

  /// 最大时长（毫秒）- 25分钟 = 1500秒 = 1500000毫秒
  static const int _maxDurationMs = 25 * 60 * 1000;

  /// 非音乐文件名关键词
  static const Set<String> _nonMusicKeywords = {
    // 系统音效
    'notification', 'alert', 'alarm', 'ringtone',
    'message', 'startup', 'shutdown', 'logon', 'logoff',
    'click', 'tap', 'button', 'menu', 'cursor',
    'error', 'warning', 'critical', 'test',
    // 游戏音效
    'sfx', 'sound_fx', 'soundfx', 'fx_',
    'footstep', 'explosion', 'gunshot', 'reload',
    'hit', 'miss', 'damage', 'heal', 'death',
    'jump', 'land', 'walk', 'attack',
    'ui_', 'gui_', 'interface_',
    'ambience', 'ambient', 'environment',
    // 应用音效
    'voiceover', 'voice_over', 'vo_',
    'tts_', 'speech', 'prompt',
  };

  /// 检查文件名是否为非音乐文件
  bool _isLikelyNonMusicFile(String filePath) {
    final fileName = filePath.toLowerCase();
    for (final keyword in _nonMusicKeywords) {
      if (fileName.contains(keyword)) {
        return true;
      }
    }
    return false;
  }

  @override
  Future<bool> requestPermission() async {
    final status = await Permission.storage.request();
    if (status.isGranted) return true;

    // Android 13+ 需要请求音频权限
    final audioStatus = await Permission.audio.request();
    return audioStatus.isGranted;
  }

  @override
  Future<bool> hasPermission() async {
    final status = await Permission.storage.status;
    if (status.isGranted) return true;

    final audioStatus = await Permission.audio.status;
    return audioStatus.isGranted;
  }

  @override
  Future<ScanResult> scanMusic() async {
    if (isScanning) {
      return const ScanResult(
        totalFound: 0,
        newAdded: 0,
        duplicates: 0,
        scanDuration: Duration.zero,
        errorMessage: '扫描正在进行中',
      );
    }

    final stopwatch = Stopwatch()..start();
    resetCancel();

    try {
      // 检查权限
      final hasPerm = await hasPermission();
      if (!hasPerm) {
        final granted = await requestPermission();
        if (!granted) {
          return const ScanResult(
            totalFound: 0,
            newAdded: 0,
            duplicates: 0,
            scanDuration: Duration.zero,
            errorMessage: '未获得存储权限',
          );
        }
      }

      updateState(ScanState.scanning);

      // 查询所有歌曲
      final songs = await _audioQuery.querySongs(
        sortType: SongSortType.TITLE,
        orderType: OrderType.ASC_OR_SMALLER,
        uriType: UriType.EXTERNAL,
      );

      final totalFound = songs.length;

      updateProgress(ScanProgress(
        currentPath: '找到 $totalFound 首歌曲',
        filesScanned: totalFound,
        songsFound: totalFound,
        progress: 0.5,
      ));

      if (totalFound == 0) {
        updateState(ScanState.completed);
        stopwatch.stop();
        return ScanResult(
          totalFound: 0,
          newAdded: 0,
          duplicates: 0,
          scanDuration: stopwatch.elapsed,
        );
      }

      updateState(ScanState.saving);

      // 保存到数据库
      final result = await _saveSongsToDatabase(songs);

      updateState(ScanState.completed);
      stopwatch.stop();

      updateProgress(ScanProgress(
        currentPath: '完成',
        filesScanned: totalFound,
        songsFound: totalFound,
        progress: 1.0,
      ));

      return ScanResult(
        totalFound: totalFound,
        newAdded: result['newAdded']!,
        duplicates: result['duplicates']!,
        scanDuration: stopwatch.elapsed,
      );
    } catch (e) {
      updateState(ScanState.error);
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
  Future<Map<String, int>> _saveSongsToDatabase(List<SongModel> songs) async {
    final db = await _dbHelper.database;
    int newAdded = 0;
    int duplicates = 0;
    int filtered = 0;
    final now = DateTime.now();
    final nowIso = now.toIso8601String();

    for (int i = 0; i < songs.length; i++) {
      if (isCancelled) break;

      final songModel = songs[i];

      // 过滤：时长不在有效范围内（165秒 ~ 1500秒）
      if (songModel.duration != null) {
        if (songModel.duration! < _minDurationMs || songModel.duration! > _maxDurationMs) {
          filtered++;
          continue;
        }
      }

      // 过滤：文件名包含非音乐关键词
      if (_isLikelyNonMusicFile(songModel.data)) {
        filtered++;
        continue;
      }

      // 检查是否已存在
      final existing = await db.query(
        DatabaseHelper.tableSongs,
        where: 'file_path = ?',
        whereArgs: [songModel.data],
        limit: 1,
      );

      if (existing.isNotEmpty) {
        duplicates++;
      } else {
        await db.insert(
          DatabaseHelper.tableSongs,
          {
            'title': songModel.title ?? '未知歌曲',
            'artist': songModel.artist,
            'album': songModel.album,
            'duration': songModel.duration,
            'file_path': songModel.data,
            'album_art_path': null,
            'date_added': songModel.dateAdded,
            'created_at': nowIso,
            'updated_at': nowIso,
          },
        );
        newAdded++;
      }

      // 更新进度
      updateProgress(ScanProgress(
        currentPath: '保存中 ${i + 1}/${songs.length}',
        filesScanned: songs.length,
        songsFound: i + 1,
        progress: 0.5 + (i + 1) / songs.length * 0.5,
      ));
    }

    print('Mobile扫描完成: newAdded=$newAdded, duplicates=$duplicates, filtered=$filtered');
    return {'newAdded': newAdded, 'duplicates': duplicates};
  }

  @override
  Future<void> deleteSong(int songId) async {
    final db = await _dbHelper.database;
    await db.delete(
      DatabaseHelper.tableSongs,
      where: 'id = ?',
      whereArgs: [songId],
    );
  }

  /// 从数据库获取所有歌曲
  @override
  Future<List<Song>> getAllSongs() async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      DatabaseHelper.tableSongs,
      orderBy: 'title ASC',
    );
    return maps.map((map) => Song.fromMap(map)).toList();
  }

  /// 获取歌曲数量
  @override
  Future<int> getSongCount() async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM ${DatabaseHelper.tableSongs}',
    );
    if (result.isEmpty) return 0;
    return result.first['count'] as int? ?? 0;
  }

  /// 清空所有歌曲
  @override
  Future<void> clearAllSongs() async {
    final db = await _dbHelper.database;
    await db.delete(DatabaseHelper.tableSongs);
  }
}
