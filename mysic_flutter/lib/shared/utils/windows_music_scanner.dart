import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../../core/database/database_helper.dart';
import '../../core/utils/app_logger.dart';
import '../../features/player/data/models/song.dart';
import 'image_cache.dart';
import 'lyrics_cache.dart';
import 'platform_music_scanner.dart';
import 'scan_directory_provider.dart';
import 'metadata_extractor.dart';

/// Windows 平台音乐扫描器
class WindowsMusicScanner extends PlatformMusicScanner {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final ScanDirectoryProvider _directoryProvider = ScanDirectoryProvider();

  /// 歌词文件缓存
  final LyricsCache _lyricsCache = LyricsCache();

  /// 图片文件缓存
  final ImageCache _imageCache = ImageCache();

  /// 封面缓存目录路径
  String? _albumArtDirectory;

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

  /// 检查是否是图片文件
  bool _isImageFile(String extension) {
    const imageExts = ['.jpg', '.jpeg', '.png', '.webp', '.gif'];
    return imageExts.any((ext) => extension.endsWith(ext));
  }

  /// 获取或创建封面缓存目录
  Future<String> _ensureAlbumArtDirectory() async {
    if (_albumArtDirectory != null) {
      return _albumArtDirectory!;
    }

    final appDir = await getApplicationDocumentsDirectory();
    final artDir = Directory('${appDir.path}/album_art');
    if (!await artDir.exists()) {
      await artDir.create(recursive: true);
    }
    _albumArtDirectory = artDir.path;
    return _albumArtDirectory!;
  }

  /// 保存封面到私有目录
  ///
  /// [songId] 歌曲ID
  /// [artworkBytes] 封面图片字节数据
  /// 返回保存的文件路径
  Future<String?> _saveArtworkToFile(int songId, Uint8List artworkBytes) async {
    try {
      if (artworkBytes.isEmpty) return null;

      final artDir = await _ensureAlbumArtDirectory();
      final filePath = '$artDir/$songId.jpg';
      final file = File(filePath);
      await file.writeAsBytes(artworkBytes);

      AppLogger.i('WindowsMusicScanner#_saveArtworkToFile', '内嵌封面保存成功: $filePath (${artworkBytes.length} bytes)');
      return filePath;
    } catch (e) {
      AppLogger.w('WindowsMusicScanner#_saveArtworkToFile', '保存封面失败: songId=$songId, error=$e');
      return null;
    }
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

    resetCancel();
    return _executeScan(() => _getScanRoots());
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
    } catch (e) {
      return ScanResult(
        totalFound: 0,
        newAdded: 0,
        duplicates: 0,
        scanDuration: stopwatch.elapsed,
        errorMessage: e.toString(),
      );
    }

    return _executeScan(() async => [directory]);
  }

  /// 执行扫描的核心逻辑
  Future<ScanResult> _executeScan(
    Future<List<String>> Function() getScanRoots,
  ) async {
    final stopwatch = Stopwatch()..start();
    _lyricsCache.clear();
    _imageCache.clear();

    try {
      updateState(ScanState.scanning);

      final scanRoots = await getScanRoots();
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

      // 阶段1：文件发现（同时构建歌词缓存）
      final songs = <File>[];
      int filesScanned = 0;
      int progressCounter = 0;

      for (int i = 0; i < scanRoots.length; i++) {
        if (isCancelled) break;

        final root = scanRoots[i];
        final rootProgress = i / scanRoots.length;

        final dirSongs = await _scanDirectoryWithLyricsCache(root, (path, count) {
          filesScanned += count;
          progressCounter++;

          if (progressCounter % options.progressUpdateInterval == 0 || songs.length % 50 == 0) {
            updateProgress(ScanProgress(
              currentPath: path,
              filesScanned: filesScanned,
              songsFound: songs.length,
              progress: rootProgress + (1 / scanRoots.length) * 0.4,
            ));
          }
        });
        songs.addAll(dirSongs);
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
        progress: 0.5,
      ));

      // 阶段2：并行元数据提取
      final metadataList = await _extractMetadataParallel(songs, (processed, total) {
        if (processed % options.progressUpdateInterval == 0) {
          updateProgress(ScanProgress(
            currentPath: '正在提取元数据...',
            filesScanned: filesScanned,
            songsFound: totalFound,
            progress: 0.5 + (processed / total) * 0.4,
          ));
        }
      });

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
        progress: 0.95,
      ));

      updateState(ScanState.saving);

      // 阶段3：批量保存到数据库
      final result = await _saveSongsToDatabase(metadataList);

      updateState(ScanState.completed);
      stopwatch.stop();
      AppLogger.i('WindowsMusicScanner#_executeScan', 'Windows扫描完成: totalFound=$totalFound, newAdded=${result['newAdded']}, duplicates=${result['duplicates']}');

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
      // 收集当前目录的图片文件
      final imageFiles = <String, String>{};

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

          // 检查是否是图片文件
          if (_isImageFile(extension)) {
            final fileName = entity.path.split(Platform.pathSeparator).last;
            imageFiles[fileName.toLowerCase()] = entity.path;
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
      // 将当前目录的图片文件添加到缓存
      _imageCache.addDirectory(path, imageFiles);
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

  /// 从音频文件提取元数据
  Future<_AudioMetadata> _extractMetadata(String filePath) async {
    // 使用统一元数据提取器
    final metadata = await MetadataExtractor.extract(filePath);

    if (metadata != null) {
      return _AudioMetadata(
        filePath: filePath,
        title: metadata.title,
        artist: metadata.artist,
        album: metadata.album,
        duration: metadata.duration,
      );
    }

    // 回退：从文件名提取
    final fileName = filePath.split(Platform.pathSeparator).last;
    return _AudioMetadata(
      filePath: filePath,
      title: MetadataExtractor.cleanTitleFromFileName(fileName),
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

      // 为每个结果添加歌词路径和封面路径
      for (var j = 0; j < batchResults.length; j++) {
        final filePath = batchResults[j].filePath;
        final lyricsPath = _lyricsCache.findLyricsPath(filePath);
        batchResults[j].lyricsPath = lyricsPath;

        // 查找封面路径
        final albumArtPath = _imageCache.findImagePath(filePath);
        batchResults[j].albumArtPath = albumArtPath;
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
    // 同时记录每个插入项对应的文件路径，用于后续封面提取
    final songsToInsert = <Map<String, dynamic>>[];
    final filePathsToInsert = <String>[];

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
          'album_art_path': metadata.albumArtPath,
          'lyrics_path': metadata.lyricsPath,
          'date_added': null,
          'created_at': nowIso,
          'updated_at': nowIso,
        });
        filePathsToInsert.add(filePath);
      }
    }

    // 4. 批量插入（使用逐条插入确保 ID 顺序对应）
    if (songsToInsert.isNotEmpty) {
      await db.transaction((txn) async {
        for (int i = 0; i < songsToInsert.length; i++) {
          final songData = songsToInsert[i];
          final songId = await txn.insert(DatabaseHelper.tableSongs, songData);
          newSongIds.add(songId);
          // 现在 songId 确定对应 filePathsToInsert[i]
        }
        newAdded = newSongIds.length;
      });

      // 5. 提取内嵌封面（优先级：内嵌封面 > 同名图片文件）
      if (newSongIds.isNotEmpty) {
        await _extractAndSaveEmbeddedArtwork(newSongIds, filePathsToInsert);
      }
    }

    AppLogger.i('WindowsMusicScanner#_saveSongsToDatabase',
        'Windows扫描完成: newAdded=$newAdded, duplicates=$duplicates, filtered=$filtered, skipped=$skipped');
    return {'newAdded': newAdded, 'duplicates': duplicates, 'newSongIds': newSongIds};
  }

  /// 提取并保存内嵌封面
  ///
  /// 遍历新插入的歌曲，提取内嵌封面并保存到私有目录
  /// 如果有内嵌封面，更新数据库中的 album_art_path
  Future<void> _extractAndSaveEmbeddedArtwork(
    List<int> songIds,
    List<String> filePaths,
  ) async {
    if (songIds.length != filePaths.length) {
      AppLogger.w('WindowsMusicScanner#_extractAndSaveEmbeddedArtwork', 'songIds 和 filePaths 长度不匹配');
      return;
    }

    final db = await _dbHelper.database;
    int embeddedCount = 0;

    for (int i = 0; i < songIds.length; i++) {
      if (isCancelled) break;

      final songId = songIds[i];
      final filePath = filePaths[i];

      try {
        // 提取内嵌封面
        final artworkBytes = await MetadataExtractor.extractArtwork(filePath);
        if (artworkBytes != null && artworkBytes.isNotEmpty) {
          // 保存到私有目录
          final savedPath = await _saveArtworkToFile(songId, artworkBytes);
          if (savedPath != null) {
            // 更新数据库
            await db.update(
              DatabaseHelper.tableSongs,
              {'album_art_path': savedPath},
              where: 'id = ?',
              whereArgs: [songId],
            );
            embeddedCount++;
          }
        }
      } catch (e) {
        AppLogger.w('WindowsMusicScanner#_extractAndSaveEmbeddedArtwork', '提取内嵌封面失败: songId=$songId, filePath=$filePath, error=$e');
      }
    }

    if (embeddedCount > 0) {
      AppLogger.i('WindowsMusicScanner#_extractAndSaveEmbeddedArtwork', '内嵌封面提取完成: $embeddedCount 首歌曲');
    }
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
  });

  final String filePath;
  final String? title;
  final String? artist;
  final String? album;
  final int? duration;
  String? lyricsPath;
  String? albumArtPath;
}
