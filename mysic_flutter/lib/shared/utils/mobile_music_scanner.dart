import 'dart:async';
import 'dart:io';
import 'package:audiotags/audiotags.dart';
import 'package:flutter/foundation.dart';
import '../../core/database/database_helper.dart';
import '../../features/player/data/models/song.dart';
import 'platform_music_scanner.dart';
import 'scan_directory_provider.dart';

/// 移动端平台音乐扫描器
class MobileMusicScanner extends PlatformMusicScanner {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final ScanDirectoryProvider _directoryProvider = ScanDirectoryProvider();

  /// 最小时长（秒）- 2分45秒 = 165秒
  static const int _minDurationSec = 165;

  /// 最大时长（秒）- 25分钟 = 1500秒
  static const int _maxDurationSec = 25 * 60;

  /// 跳过的目录名
  static const Set<String> _skipDirectories = {
    // 系统目录
    'Android', 'android', 'AndroidOS',
    'LOST.DIR', 'lost.dir',
    'System', 'system',
    'cache', 'Cache', '.cache',
    'data', 'Data',
    // 应用目录
    'DCIM', 'Pictures', 'Camera',
    'Movies', 'Videos',
    'Podcasts', 'podcasts',
    'Ringtones', 'Notifications', 'Alarms',
    // 开发相关
    '.git', '.svn', 'node_modules',
    // 临时目录
    'Temp', 'tmp',
    // 常见非音乐资源目录名
    'assets', 'Assets', 'res', 'resources', 'Resources',
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

  /// 获取外部存储根目录
  String _getExternalStorageRoot() {
    return '/storage/emulated/0';
  }

  /// 获取扫描根目录列表
  Future<List<String>> _getScanRoots() async {
    final directoryNames = await _directoryProvider.getDirectories();
    final storageRoot = _getExternalStorageRoot();

    final roots = <String>[];
    for (final dirName in directoryNames) {
      final path = '$storageRoot/$dirName';
      try {
        if (await Directory(path).exists()) {
          roots.add(path);
        }
      } catch (_) {
        // 忽略无权限目录
      }
    }
    return roots;
  }

  /// 测试用：获取扫描根目录
  Future<List<String>> getScanRootsForTest() => _getScanRoots();

  @override
  Future<bool> requestPermission() async {
    // 文件系统扫描不需要单独请求权限
    // 实际权限检查在文件系统操作时进行
    return true;
  }

  @override
  Future<bool> hasPermission() async {
    // 文件系统扫描不需要单独检查权限
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

      // 获取扫描根目录列表
      final scanRoots = await _getScanRoots();
      if (scanRoots.isEmpty) {
        updateState(ScanState.completed);
        stopwatch.stop();
        return ScanResult(
          totalFound: 0,
          newAdded: 0,
          duplicates: 0,
          scanDuration: stopwatch.elapsed,
        );
      }

      // 扫描所有配置的目录
      final songs = <File>[];
      int filesScanned = 0;
      int progressCounter = 0;

      for (int i = 0; i < scanRoots.length; i++) {
        if (isCancelled) break;

        final root = scanRoots[i];
        final rootProgress = i / scanRoots.length;

        await _scanDirectory(root, songs, (path, count) {
          filesScanned += count;
          progressCounter++;

          // 每 100 个文件更新一次进度，减少 UI 开销
          if (progressCounter % 100 == 0 || songs.length % 50 == 0) {
            updateProgress(ScanProgress(
              currentPath: path,
              filesScanned: filesScanned,
              songsFound: songs.length,
              progress: rootProgress + (1 / scanRoots.length) * 0.9,
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
      debugPrint('Mobile扫描完成: totalFound=$totalFound, newAdded=${result['newAdded']}, duplicates=${result['duplicates']}');

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
          for (final ext in options.audioExtensions) {
            if (extension.endsWith(ext)) {
              // 检查文件名是否像非音乐文件
              if (_isLikelyNonMusicFile(entity.path)) {
                break;
              }
              // 检查文件大小
              try {
                final fileSize = await entity.length();
                if (fileSize >= options.minFileSizeBytes) {
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

  /// 从文件名智能提取标题（移除序号等前缀）
  String _cleanTitleFromFileName(String fileName) {
    // 移除扩展名
    var title = fileName.replaceAll(RegExp(r'\.[^.]+$'), '');
    // 移除开头的数字序号 (01. 或 01- 或 01 或 1. 或 1- 等)
    title = title.replaceFirst(RegExp(r'^\d+[\s.\-_]+'), '');
    return title.trim();
  }

  /// 从音频文件提取元数据
  Future<_AudioMetadata> _extractMetadata(String filePath) async {
    try {
      final tag = await AudioTags.read(filePath);
      if (tag != null) {
        return _AudioMetadata(
          title: tag.title,
          artist: tag.trackArtist,
          album: tag.album,
          duration: tag.duration,
        );
      }
    } catch (e) {
      // 元数据读取失败，使用文件名
      debugPrint('读取元数据失败: $filePath, 错误: $e');
    }

    // 回退：从文件名提取
    final fileName = filePath.split(Platform.pathSeparator).last;
    return _AudioMetadata(
      title: _cleanTitleFromFileName(fileName),
      artist: null,
      album: null,
      duration: null,
    );
  }

  /// 保存歌曲到数据库（批量操作优化）
  Future<Map<String, int>> _saveSongsToDatabase(List<File> songs) async {
    final db = await _dbHelper.database;
    int newAdded = 0;
    int duplicates = 0;
    int filtered = 0;
    int skipped = 0;
    final now = DateTime.now();
    final nowIso = now.toIso8601String();

    // 1. 一次性查询所有已存在的路径
    final allExisting = await db.query(
      DatabaseHelper.tableSongs,
      columns: ['file_path'],
    );
    final existingPaths = allExisting.map((row) => row['file_path'] as String).toSet();

    // 2. 查询已删除的路径（软删除标记）
    final deletedPathsResult = await db.query(
      DatabaseHelper.tableSongs,
      columns: ['file_path'],
      where: 'is_deleted = ?',
      whereArgs: [1],
    );
    final deletedPaths = deletedPathsResult
        .map((row) => row['file_path'] as String)
        .toSet();

    // 3. 批量插入（使用事务）
    await db.transaction((txn) async {
      for (final file in songs) {
        if (isCancelled) break;

        final filePath = file.path;

        // 跳过已删除的路径
        if (deletedPaths.contains(filePath)) {
          skipped++;
          continue;
        }

        if (existingPaths.contains(filePath)) {
          // 根据 autoDedupe 选项决定行为
          // 无论 autoDedupe 值如何，都跳过已存在的文件（数据库有唯一约束）
          // 但计数方式不同：autoDedupe=true 计入 duplicates，否则计入 skipped
          if (options.autoDedupe) {
            duplicates++;
          } else {
            skipped++;
          }
        } else {
          // 提取音频元数据
          final metadata = await _extractMetadata(filePath);

          // 过滤：时长不在有效范围内（165秒 ~ 1500秒）
          if (metadata.duration != null) {
            if (metadata.duration! < _minDurationSec || metadata.duration! > _maxDurationSec) {
              filtered++;
              continue;
            }
          }

          // 确定最终标题：优先使用元数据，回退到清理后的文件名
          final fileName = filePath.split(Platform.pathSeparator).last;
          final title = metadata.title?.isNotEmpty == true
              ? metadata.title
              : _cleanTitleFromFileName(fileName);

          await txn.insert(
            DatabaseHelper.tableSongs,
            {
              'title': title,
              'artist': metadata.artist,
              'album': metadata.album,
              'duration': metadata.duration ?? 0,
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

    debugPrint('Mobile扫描完成: newAdded=$newAdded, duplicates=$duplicates, filtered=$filtered, skipped=$skipped');
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

/// 音频元数据辅助类
class _AudioMetadata {
  const _AudioMetadata({
    this.title,
    this.artist,
    this.album,
    this.duration,
  });

  final String? title;
  final String? artist;
  final String? album;
  final int? duration;
}
