import 'dart:async';
import 'dart:io';
import '../../core/database/database_helper.dart';
import '../../features/player/data/models/song.dart';
import 'platform_music_scanner.dart';

/// Windows 平台音乐扫描器
class WindowsMusicScanner extends PlatformMusicScanner {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  /// 支持的音频格式
  static const Set<String> _audioExtensions = {
    '.mp3', '.flac', '.wav', '.m4a', '.aac', '.ogg', '.wma',
  };

  /// 最小文件大小 (2.5MB)
  static const int _minFileSizeBytes = 2500 * 1024;

  /// 跳过的目录名
  static const Set<String> _skipDirectories = {
    // 系统目录
    '\$RECYCLE.BIN',
    'System Volume Information',
    'Windows',
    'Program Files',
    'Program Files (x86)',
    'ProgramData',
    // 版本控制
    '.git',
    '.svn',
    // 开发相关
    'node_modules',
    // 游戏目录
    'Games',
    'Game',
    'Steam',
    'SteamLibrary',
    'Epic Games',
    'GOG Galaxy',
    'Origin',
    'Ubisoft',
    'Battle.net',
    // 应用资源目录
    'AppData',
    'Application Data',
    '.cache',
    'cache',
    'Cache',
    // 系统音效目录
    'Media',
    'Sounds',
    'Sound',
    // 临时目录
    'Temp',
    'tmp',
    // 常见非音乐资源目录名
    'assets',
    'Assets',
    'res',
    'resources',
    'Resources',
    'data',
    'Data',
  };

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
    // Windows 不需要特殊权限
    return true;
  }

  @override
  Future<bool> hasPermission() async {
    return true;
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
      updateState(ScanState.scanning);

      // 获取所有驱动器
      final drives = await _getAvailableDrives();
      if (drives.isEmpty) {
        updateState(ScanState.completed);
        stopwatch.stop();
        return ScanResult(
          totalFound: 0,
          newAdded: 0,
          duplicates: 0,
          scanDuration: stopwatch.elapsed,
        );
      }

      // 扫描所有驱动器
      final songs = <File>[];
      int filesScanned = 0;
      int progressCounter = 0; // 进度更新计数器

      for (int i = 0; i < drives.length; i++) {
        if (isCancelled) break;

        final drive = drives[i];
        final driveProgress = i / drives.length;

        await _scanDirectory(drive, songs, (path, count) {
          filesScanned += count;
          progressCounter++;

          // 每 100 个文件更新一次进度，减少 UI 开销
          if (progressCounter % 100 == 0 || songs.length % 50 == 0) {
            updateProgress(ScanProgress(
              currentPath: path,
              filesScanned: filesScanned,
              songsFound: songs.length,
              progress: driveProgress + (1 / drives.length) * 0.9,
            ));
          }
        });
      }

      if (isCancelled) {
        updateState(ScanState.idle);
        stopwatch.stop();
        return ScanResult(
          totalFound: songs.length,
          newAdded: 0,
          duplicates: 0,
          scanDuration: stopwatch.elapsed,
          errorMessage: '扫描已取消',
        );
      }

      final totalFound = songs.length;
      updateProgress(ScanProgress(
        currentPath: '正在保存...',
        filesScanned: filesScanned,
        songsFound: totalFound,
        progress: 0.95,
      ));

      updateState(ScanState.saving);

      // 保存到数据库
      final result = await _saveSongsToDatabase(songs);

      updateState(ScanState.completed);
      stopwatch.stop();
      print('Windows扫描完成: totalFound=$totalFound, newAdded=${result['newAdded']}, duplicates=${result['duplicates']}');

      updateProgress(ScanProgress(
        currentPath: '完成',
        filesScanned: filesScanned,
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

  /// 获取所有可用驱动器
  Future<List<String>> _getAvailableDrives() async {
    final drives = <String>[];
    for (final letter in ['C', 'D', 'E', 'F', 'G', 'H']) {
      final drive = '$letter:\\';
      try {
        final dir = Directory(drive);
        if (await dir.exists()) {
          drives.add(drive);
        }
      } catch (_) {
        // 忽略无法访问的驱动器
      }
    }
    return drives;
  }

  /// 递归扫描目录
  Future<void> _scanDirectory(
    String path,
    List<File> songs,
    void Function(String path, int count) onProgress,
  ) async {
    if (isCancelled) return;

    try {
      final dir = Directory(path);
      if (!await dir.exists()) return;

      await for (final entity in dir.list(followLinks: false)) {
        if (isCancelled) return;

        if (entity is Directory) {
          final dirName = entity.path.split(Platform.pathSeparator).last;
          if (_skipDirectories.contains(dirName)) continue;

          try {
            await _scanDirectory(entity.path, songs, onProgress);
          } catch (_) {
            // 忽略无权限目录
          }
        } else if (entity is File) {
          final extension = entity.path.toLowerCase();
          for (final ext in _audioExtensions) {
            if (extension.endsWith(ext)) {
              // 检查文件名是否像非音乐文件
              if (_isLikelyNonMusicFile(entity.path)) {
                break;
              }
              // 检查文件大小
              try {
                final fileSize = await entity.length();
                if (fileSize >= _minFileSizeBytes) {
                  songs.add(entity);
                  onProgress(entity.path, 1);
                }
              } catch (_) {
                // 忽略无法读取的文件
              }
              break;
            }
          }
        }
      }
    } catch (_) {
      // 忽略无权限目录
    }
  }

  /// 保存歌曲到数据库（批量操作优化）
  Future<Map<String, int>> _saveSongsToDatabase(List<File> songs) async {
    final db = await _dbHelper.database;
    int newAdded = 0;
    int duplicates = 0;
    final now = DateTime.now();
    final nowIso = now.toIso8601String();

    // 1. 一次性查询所有已存在的路径
    final allExisting = await db.query(
      DatabaseHelper.tableSongs,
      columns: ['file_path'],
    );
    final existingPaths = allExisting.map((row) => row['file_path'] as String).toSet();

    // 2. 批量插入（使用事务）
    await db.transaction((txn) async {
      for (final file in songs) {
        if (isCancelled) break;

        final filePath = file.path;

        if (existingPaths.contains(filePath)) {
          duplicates++;
        } else {
          // 从文件名提取标题
          final fileName = filePath.split(Platform.pathSeparator).last;
          final title = fileName.replaceAll(RegExp(r'\.[^.]+$'), '');

          await txn.insert(
            DatabaseHelper.tableSongs,
            {
              'title': title,
              'artist': null,
              'album': null,
              'duration': 0,
              'file_path': filePath,
              'album_art_path': null,
              'date_added': null,
              'created_at': nowIso,
              'updated_at': nowIso,
            },
          );
          newAdded++;
        }
      }
    });

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
