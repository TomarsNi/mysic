import 'dart:async';
import 'dart:io';
import 'package:audiotags/audiotags.dart';
import 'package:flutter/foundation.dart';
import '../../core/database/database_helper.dart';
import '../../features/player/data/models/song.dart';
import 'lyrics_cache.dart';
import 'platform_music_scanner.dart';
import 'scan_directory_provider.dart';

/// Windows 平台音乐扫描器
class WindowsMusicScanner extends PlatformMusicScanner {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final ScanDirectoryProvider _directoryProvider = ScanDirectoryProvider();

  /// 歌词文件缓存
  final LyricsCache _lyricsCache = LyricsCache();

  /// 最小时长（秒）- 2分45秒 = 165秒
  static const int _minDurationSec = 165;

  /// 最大时长（秒）- 25分钟 = 1500秒
  static const int _maxDurationSec = 25 * 60;

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
      int progressCounter = 0; // 进度更新计数器

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
        currentPath: '正在提取元数据...',
        filesScanned: filesScanned,
        songsFound: totalFound,
        progress: 0.95,
      ));

      updateState(ScanState.saving);

      // 提取元数据并查找歌词文件
      final metadataList = <_AudioMetadata>[];
      for (final file in songs) {
        if (isCancelled) break;

        final metadata = await _extractMetadata(file.path);
        // 查找歌词文件
        metadata.lyricsPath = await _findLyricsFile(file.path);
        metadataList.add(metadata);
      }

      if (isCancelled) {
        updateState(ScanState.idle);
        stopwatch.stop();
        return ScanResult(
          totalFound: totalFound,
          newAdded: 0,
          duplicates: 0,
          scanDuration: stopwatch.elapsed,
          errorMessage: '扫描已取消',
        );
      }

      updateProgress(ScanProgress(
        currentPath: '正在保存...',
        filesScanned: filesScanned,
        songsFound: totalFound,
        progress: 0.98,
      ));

      // 批量保存到数据库
      final result = await _saveSongsToDatabase(metadataList);

      updateState(ScanState.completed);
      stopwatch.stop();
      debugPrint('Windows扫描完成: totalFound=$totalFound, newAdded=${result['newAdded']}, duplicates=${result['duplicates']}');

      updateProgress(ScanProgress(
        currentPath: '完成',
        filesScanned: filesScanned,
        songsFound: totalFound,
        progress: 1.0,
      ));

      return ScanResult(
        totalFound: totalFound,
        newAdded: result['newAdded']! as int,
        duplicates: result['duplicates']! as int,
        scanDuration: stopwatch.elapsed,
        newSongIds: result['newSongIds']! as List<int>,
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

  @override
  Future<ScanResult> scanMusicInDirectory(String directory) async {
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
      // 检查目录是否存在
      final dir = Directory(directory);
      if (!await dir.exists()) {
        updateState(ScanState.completed);
        stopwatch.stop();
        return ScanResult(
          totalFound: 0,
          newAdded: 0,
          duplicates: 0,
          scanDuration: stopwatch.elapsed,
        );
      }

      updateState(ScanState.scanning);

      // 扫描指定目录
      final songs = <File>[];
      int filesScanned = 0;
      int progressCounter = 0;

      await _scanDirectory(directory, songs, (path, count) {
        filesScanned += count;
        progressCounter++;

        if (progressCounter % 100 == 0 || songs.length % 50 == 0) {
          updateProgress(ScanProgress(
            currentPath: path,
            filesScanned: filesScanned,
            songsFound: songs.length,
            progress: progressCounter / (progressCounter + 100),
          ));
        }
      });

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
        currentPath: '正在提取元数据...',
        filesScanned: filesScanned,
        songsFound: totalFound,
        progress: 0.95,
      ));

      updateState(ScanState.saving);

      // 提取元数据并查找歌词文件
      final metadataList = <_AudioMetadata>[];
      for (final file in songs) {
        if (isCancelled) break;

        final metadata = await _extractMetadata(file.path);
        // 查找歌词文件
        metadata.lyricsPath = await _findLyricsFile(file.path);
        metadataList.add(metadata);
      }

      if (isCancelled) {
        updateState(ScanState.idle);
        stopwatch.stop();
        return ScanResult(
          totalFound: totalFound,
          newAdded: 0,
          duplicates: 0,
          scanDuration: stopwatch.elapsed,
          errorMessage: '扫描已取消',
        );
      }

      updateProgress(ScanProgress(
        currentPath: '正在保存...',
        filesScanned: filesScanned,
        songsFound: totalFound,
        progress: 0.98,
      ));

      // 批量保存到数据库
      final result = await _saveSongsToDatabase(metadataList);

      updateState(ScanState.completed);
      stopwatch.stop();
      debugPrint('Windows目录扫描完成: directory=$directory, totalFound=$totalFound, newAdded=${result['newAdded']}');

      updateProgress(ScanProgress(
        currentPath: '完成',
        filesScanned: filesScanned,
        songsFound: totalFound,
        progress: 1.0,
      ));

      return ScanResult(
        totalFound: totalFound,
        newAdded: result['newAdded']! as int,
        duplicates: result['duplicates']! as int,
        scanDuration: stopwatch.elapsed,
        newSongIds: result['newSongIds']! as List<int>,
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

  /// 获取扫描根目录列表
  Future<List<String>> _getScanRoots() async {
    final configs = await _directoryProvider.getConfigs();
    final roots = <String>[];

    for (final config in configs) {
      // 检查是否是完整路径（包含驱动器字母）
      if (config.directory.contains(':\\') || config.directory.contains(':/')) {
        // 完整路径，直接检查是否存在
        try {
          if (await Directory(config.directory).exists()) {
            roots.add(config.directory);
          }
        } catch (_) {
          // 忽略无权限目录
        }
      } else {
        // 旧格式（仅目录名），在所有驱动器中查找
        final drives = await _getAvailableDrives();
        for (final drive in drives) {
          final path = '$drive${config.directory}';
          try {
            if (await Directory(path).exists()) {
              roots.add(path);
            }
          } catch (_) {
            // 忽略无权限目录
          }
        }
      }
    }

    return roots;
  }

  /// 测试用：获取扫描根目录
  Future<List<String>> getScanRootsForTest() => _getScanRoots();

  /// 递归扫描目录
  /// 返回音频文件列表，同时填充歌词缓存
  Future<List<File>> _scanDirectoryWithLyricsCache(
    String path,
    void Function(String path, int count) onProgress,
  ) async {
    final songs = <File>[];

    await _scanDirectoryRecursive(path, songs, onProgress);

    return songs;
  }

  /// 递归扫描目录（内部实现）
  Future<void> _scanDirectoryRecursive(
    String path,
    List<File> songs,
    void Function(String path, int count) onProgress,
  ) async {
    if (isCancelled) return;

    try {
      final dir = Directory(path);
      if (!await dir.exists()) return;

      // 收集当前目录的歌词文件
      final lrcNames = <String>{};

      await for (final entity in dir.list(followLinks: false)) {
        if (isCancelled) return;

        if (entity is Directory) {
          final dirName = entity.path.split(Platform.pathSeparator).last;
          if (_skipDirectories.contains(dirName)) continue;

          try {
            await _scanDirectoryRecursive(entity.path, songs, onProgress);
          } catch (_) {
            // 忽略无权限目录
          }
        } else if (entity is File) {
          final extension = entity.path.toLowerCase();

          // 检查是否是歌词文件
          if (extension.endsWith('.lrc')) {
            final fileName = entity.path.split(Platform.pathSeparator).last;
            final nameWithoutExt = fileName.replaceAll(
              RegExp(r'\.lrc$', caseSensitive: false),
              '',
            );
            lrcNames.add(nameWithoutExt);
            continue;
          }

          // 检查是否是音频文件
          for (final ext in options.audioExtensions) {
            if (extension.endsWith(ext)) {
              if (_isLikelyNonMusicFile(entity.path)) {
                break;
              }
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

      // 将当前目录的歌词文件添加到缓存
      _lyricsCache.addDirectory(path, lrcNames);
    } catch (_) {
      // 忽略无权限目录
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
    // 使用 * 表示分隔符可选，支持 "01歌名" 格式
    title = title.replaceFirst(RegExp(r'^\d+[\s.\-_]*'), '');
    // 移除开头常见的艺术家前缀格式 (艺术家 - 歌名)
    // 注意：这个可能不准确，所以只在元数据缺失时使用
    return title.trim();
  }

  /// 清理歌词文件名（移除扩展名、序号前缀和艺术家后缀）
  /// 用于宽松匹配歌词文件
  String _cleanLrcFileName(String lrcFileName) {
    // 移除 .lrc 扩展名（大小写不敏感）
    var name = lrcFileName.replaceAll(RegExp(r'\.lrc$', caseSensitive: false), '');
    // 移除开头的数字序号和分隔符
    name = name.replaceFirst(RegExp(r'^\d+[\s.\-_]*'), '');
    // 移除可能的艺术家后缀（如 " - 周杰伦"）
    name = name.replaceFirst(RegExp(r'\s*-\s*.+$'), '');
    return name.toLowerCase().trim();
  }

  /// 查找音频文件对应的歌词文件
  /// 支持同名匹配和宽松匹配（忽略序号前缀）
  Future<String?> _findLyricsFile(String audioFilePath) async {
    final audioFile = File(audioFilePath);
    final dirPath = audioFile.parent.path;
    final audioFileName = audioFilePath.split(Platform.pathSeparator).last;

    // 提取音频文件名（不含扩展名）
    final audioName = audioFileName.replaceAll(RegExp(r'\.[^.]+$'), '');

    try {
      final dir = Directory(dirPath);
      if (!await dir.exists()) return null;

      // 优先：同名匹配
      final sameNameLrc = '$dirPath${Platform.pathSeparator}$audioName.lrc';
      if (await File(sameNameLrc).exists()) {
        return sameNameLrc;
      }

      // 次选：宽松匹配
      // 清理音频文件名用于比较（移除序号前缀）
      final cleanedAudioName = _cleanTitleFromFileName(audioFileName).toLowerCase();

      await for (final entity in dir.list(followLinks: false)) {
        if (entity is File) {
          final lrcName = entity.path.split(Platform.pathSeparator).last;
          if (lrcName.toLowerCase().endsWith('.lrc')) {
            // 清理歌词文件名的序号前缀
            final cleanedLrcName = _cleanLrcFileName(lrcName);
            if (cleanedLrcName == cleanedAudioName) {
              return entity.path;
            }
          }
        }
      }
    } catch (_) {
      // 忽略无法访问的目录
    }

    return null;
  }

  /// 从音频文件提取元数据
  Future<_AudioMetadata> _extractMetadata(String filePath) async {
    try {
      final tag = await AudioTags.read(filePath);
      if (tag != null) {
        return _AudioMetadata(
          filePath: filePath,
          title: tag.title,
          artist: tag.trackArtist,
          album: tag.album,
          duration: tag.duration,
        );
      }
    } catch (e) {
      // 元数据读取失败，使用文件名
      // ignore: avoid_print
      print('读取元数据失败: $filePath, 错误: $e');
    }

    // 回退：从文件名提取
    final fileName = filePath.split(Platform.pathSeparator).last;
    return _AudioMetadata(
      filePath: filePath,
      title: _cleanTitleFromFileName(fileName),
      artist: null,
      album: null,
      duration: null,
    );
  }

  /// 并行提取元数据
  Future<List<_AudioMetadata>> _extractMetadataParallel(
    List<File> files,
    void Function(int processed, int total) onProgress,
  ) async {
    final batchSize = options.metadataBatchSize;
    final results = <_AudioMetadata>[];
    final filePaths = files.map((f) => f.path).toList();

    for (var i = 0; i < filePaths.length; i += batchSize) {
      if (isCancelled) break;

      final batch = filePaths.sublist(
        i,
        (i + batchSize < filePaths.length) ? i + batchSize : filePaths.length,
      );

      // 并行处理当前批次
      final batchResults = await Future.wait(
        batch.map((path) => _extractMetadata(path)),
      );

      // 为每个结果添加歌词路径
      for (var j = 0; j < batchResults.length; j++) {
        final lyricsPath = _lyricsCache.findLyricsPath(batch[j]);
        batchResults[j].lyricsPath = lyricsPath;
      }

      results.addAll(batchResults);
      onProgress(results.length, filePaths.length);
    }

    return results;
  }

  /// 保存歌曲到数据库（批量操作优化）
  Future<Map<String, dynamic>> _saveSongsToDatabase(
    List<_AudioMetadata> metadataList,
  ) async {
    final db = await _dbHelper.database;
    int newAdded = 0;
    int duplicates = 0;
    int filtered = 0;
    int skipped = 0;
    final newSongIds = <int>[];
    final now = DateTime.now();
    final nowIso = now.toIso8601String();

    // 1. 一次性查询所有已存在的路径
    final allExisting = await db.query(
      DatabaseHelper.tableSongs,
      columns: ['file_path'],
    );
    final existingPaths =
        allExisting.map((row) => row['file_path'] as String).toSet();

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

    // 3. 过滤并准备批量插入数据
    final songsToInsert = <Map<String, dynamic>>[];

    for (final metadata in metadataList) {
      if (isCancelled) break;

      final filePath = metadata.filePath;

      // 跳过已删除的路径
      if (deletedPaths.contains(filePath)) {
        skipped++;
        continue;
      }

      if (existingPaths.contains(filePath)) {
        if (options.autoDedupe) {
          duplicates++;
        } else {
          skipped++;
        }
      } else {
        // 过滤：时长不在有效范围内
        if (metadata.duration != null) {
          if (metadata.duration! < _minDurationSec ||
              metadata.duration! > _maxDurationSec) {
            filtered++;
            continue;
          }
        }

        // 确定最终标题
        final fileName = filePath.split(Platform.pathSeparator).last;
        final title = metadata.title?.isNotEmpty == true
            ? metadata.title
            : _cleanTitleFromFileName(fileName);

        songsToInsert.add({
          'title': title,
          'artist': metadata.artist,
          'album': metadata.album,
          'duration': metadata.duration ?? 0,
          'file_path': filePath,
          'album_art_path': null,
          'lyrics_path': metadata.lyricsPath,
          'date_added': null,
          'created_at': nowIso,
          'updated_at': nowIso,
        });
      }
    }

    // 4. 批量插入
    if (songsToInsert.isNotEmpty) {
      await db.transaction((txn) async {
        final batch = txn.batch();
        for (final songData in songsToInsert) {
          batch.insert(DatabaseHelper.tableSongs, songData);
        }
        final results = await batch.commit(noResult: false);
        newSongIds.addAll(results.cast<int>());
        newAdded = newSongIds.length;
      });
    }

    debugPrint(
        'Windows扫描完成: newAdded=$newAdded, duplicates=$duplicates, filtered=$filtered, skipped=$skipped');
    return {'newAdded': newAdded, 'duplicates': duplicates, 'newSongIds': newSongIds};
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

  /// 根据 ID 列表获取歌曲
  @override
  Future<List<Song>> getSongsByIds(List<int> ids) async {
    if (ids.isEmpty) return [];
    final db = await _dbHelper.database;
    final maps = await db.query(
      DatabaseHelper.tableSongs,
      where: 'id IN (${ids.join(',')})',
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
  _AudioMetadata({
    required this.filePath,
    this.title,
    this.artist,
    this.album,
    this.duration,
    this.lyricsPath,
  });

  final String filePath;
  final String? title;
  final String? artist;
  final String? album;
  final int? duration;
  String? lyricsPath;
}
