import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:path_provider/path_provider.dart';
import '../../core/database/database_helper.dart';
import '../../features/player/data/models/song.dart';
import 'platform_music_scanner.dart';
import 'scan_directory_provider.dart';
import 'lyrics_cache.dart';
import 'image_cache.dart';
import 'metadata_extractor.dart';

/// 移动端平台音乐扫描器
class MobileMusicScanner extends PlatformMusicScanner {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final ScanDirectoryProvider _directoryProvider = ScanDirectoryProvider();
  final OnAudioQuery _audioQuery = OnAudioQuery();

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

  /// 检查是否是图片文件
  bool _isImageFile(String extension) {
    const imageExts = ['.jpg', '.jpeg', '.png', '.webp', '.gif'];
    return imageExts.any((ext) => extension.endsWith(ext));
  }

  /// 获取外部存储根目录
  String _getExternalStorageRoot() {
    return '/storage/emulated/0';
  }

  /// 将 SAF URI 转换为文件系统路径
  ///
  /// SAF URI 格式示例：
  /// - content://com.android.externalstorage.documents/tree/primary%3AMusic
  /// - content://com.android.externalstorage.documents/tree/primary%3ADownload%2FMyMusic
  ///
  /// 转換结果：
  /// - /storage/emulated/0/Music
  /// - /storage/emulated/0/Download/MyMusic
  ///
  /// 返回 null 表示无法转换（非 SAF URI 或不支持的格式）
  String? _convertSafUriToFilePath(String uri) {
    // 检查是否是 SAF URI
    if (!uri.startsWith('content://')) {
      return null; // 不是 SAF URI，返回 null 让调用方使用原始路径
    }

    // 解析 SAF URI
    // 格式：content://com.android.externalstorage.documents/tree/<encoded_path>
    final uriParts = uri.split('/');
    if (uriParts.length < 5) {
      debugPrint('SAF URI 格式无效: $uri');
      return null;
    }

    // 找到 "tree" 后面的路径段
    int treeIndex = uriParts.indexOf('tree');
    if (treeIndex == -1 || treeIndex + 1 >= uriParts.length) {
      debugPrint('SAF URI 缺少 tree 段: $uri');
      return null;
    }

    // 获取编码的路径段（可能是 URL 编码的）
    String encodedPath = uriParts[treeIndex + 1];

    // URL 解码
    String decodedPath;
    try {
      decodedPath = Uri.decodeComponent(encodedPath);
    } catch (e) {
      debugPrint('SAF URI 解码失败: $encodedPath, 错误: $e');
      return null;
    }

    // 解析路径段
    // 格式通常是 "primary:Music" 或 "primary:Download/MyMusic"
    // 或者在某些设备上可能是 "raw:/storage/emulated/0/Music"
    if (decodedPath.startsWith('primary:')) {
      // primary: 表示主存储
      final relativePath = decodedPath.substring('primary:'.length);
      if (relativePath.isEmpty) {
        return _getExternalStorageRoot();
      }
      return '${_getExternalStorageRoot()}/$relativePath';
    } else if (decodedPath.startsWith('raw:')) {
      // raw: 后面直接是完整路径
      return decodedPath.substring('raw:'.length);
    } else if (decodedPath.contains(':')) {
      // 其他存储类型（如 external: 表示 SD 卡），暂不支持
      debugPrint('SAF URI 不支持的存储类型: $decodedPath');
      return null;
    } else {
      // 某些情况下可能直接是相对路径
      return '${_getExternalStorageRoot()}/$decodedPath';
    }
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

  /// 获取歌曲封面并保存为文件
  ///
  /// [songId] 数据库歌曲 ID
  /// [mediaId] MediaStore 歌曲 ID
  /// 返回封面文件路径，获取失败返回 null
  Future<String?> _fetchAndSaveArtwork(int songId, int mediaId) async {
    try {
      // 使用 on_audio_query 获取封面
      final artwork = await _audioQuery.queryArtwork(
        mediaId,
        ArtworkType.AUDIO,
        quality: 100, // 原始质量
      );

      if (artwork == null || artwork.isEmpty) {
        debugPrint('歌曲无封面: songId=$songId, mediaId=$mediaId');
        return null;
      }

      // 确保目录存在
      final artDir = await _ensureAlbumArtDirectory();

      // 保存为文件
      final filePath = '$artDir/$songId.jpg';
      final file = File(filePath);
      await file.writeAsBytes(artwork);

      debugPrint('封面保存成功: $filePath (${artwork.length} bytes)');
      return filePath;
    } catch (e) {
      debugPrint('获取封面失败: songId=$songId, mediaId=$mediaId, error=$e');
      return null;
    }
  }

  /// 测试用：获取扫描根目录
  Future<List<String>> getScanRootsForTest() => _getScanRoots();

  /// 测试用：转换 SAF URI 到文件路径
  String? convertSafUriToFilePathForTest(String uri) => _convertSafUriToFilePath(uri);

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
    _lyricsCache.clear();
    _imageCache.clear();

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

      // 阶段1：文件发现（同时构建歌词缓存）
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
              progress: rootProgress + (1 / scanRoots.length) * 0.4,
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
      debugPrint('Mobile扫描完成: totalFound=$totalFound, newAdded=${result['newAdded']}, duplicates=${result['duplicates']}');

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
    debugPrint('========== scanMusicInDirectory 开始 (MediaStore) ==========');
    debugPrint('原始目录路径: $directory');

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
      // 尝试将 SAF URI 转换为文件系统路径
      String actualPath = directory;
      if (directory.startsWith('content://')) {
        debugPrint('检测到 SAF URI，尝试转换...');
        final convertedPath = _convertSafUriToFilePath(directory);
        debugPrint('转换结果: $convertedPath');
        if (convertedPath != null) {
          actualPath = convertedPath;
          debugPrint('SAF URI 转换: $directory -> $actualPath');
        } else {
          // 无法转换，返回错误
          debugPrint('SAF URI 转换失败');
          updateState(ScanState.completed);
          stopwatch.stop();
          return ScanResult(
            totalFound: 0,
            newAdded: 0,
            duplicates: 0,
            scanDuration: stopwatch.elapsed,
            errorMessage: '无法访问该目录，请选择其他目录',
          );
        }
      }

      updateState(ScanState.scanning);

      // 使用 MediaStore API 查询指定目录的歌曲
      debugPrint('使用 MediaStore 查询目录: $actualPath');

      // 检查权限
      final hasPermission = await _audioQuery.checkAndRequest();
      if (!hasPermission) {
        debugPrint('没有存储权限');
        updateState(ScanState.completed);
        stopwatch.stop();
        return ScanResult(
          totalFound: 0,
          newAdded: 0,
          duplicates: 0,
          scanDuration: stopwatch.elapsed,
          errorMessage: '没有存储权限',
        );
      }

      // 使用 querySongs 的 path 参数查询指定目录的歌曲
      List<SongModel> mediaSongs;
      try {
        // querySongs 支持 path 参数来过滤特定目录
        mediaSongs = await _audioQuery.querySongs(path: actualPath);
        debugPrint('MediaStore 查询到 ${mediaSongs.length} 首歌曲');
      } catch (e) {
        debugPrint('MediaStore querySongs 失败: $e');
        // 如果 path 参数不支持，尝试查询所有歌曲然后过滤
        try {
          debugPrint('尝试查询所有歌曲然后按路径过滤...');
          final allSongs = await _audioQuery.querySongs();
          debugPrint('查询到所有歌曲: ${allSongs.length} 首');

          // 按目录路径过滤
          mediaSongs = allSongs.where((song) {
            final songPath = song.data;
            if (songPath.isEmpty) return false;
            // 检查歌曲路径是否在目标目录下
            return songPath.startsWith(actualPath);
          }).toList();
          debugPrint('过滤后歌曲数量: ${mediaSongs.length}');
        } catch (e2) {
          debugPrint('MediaStore 查询失败: $e2');
          updateState(ScanState.completed);
          stopwatch.stop();
          return ScanResult(
            totalFound: 0,
            newAdded: 0,
            duplicates: 0,
            scanDuration: stopwatch.elapsed,
            errorMessage: '查询失败: $e2',
          );
        }
      }

      if (isCancelled) {
        updateState(ScanState.idle);
        stopwatch.stop();
        return ScanResult(
          totalFound: mediaSongs.length,
          newAdded: 0,
          duplicates: 0,
          scanDuration: stopwatch.elapsed,
          errorMessage: '扫描已取消',
        );
      }

      final totalFound = mediaSongs.length;
      updateProgress(ScanProgress(
        currentPath: '正在保存...',
        filesScanned: totalFound,
        songsFound: totalFound,
        progress: 0.95,
      ));

      updateState(ScanState.saving);

      // 保存到数据库
      final result = await _saveMediaSongsToDatabase(mediaSongs, actualPath);

      updateState(ScanState.completed);
      stopwatch.stop();
      debugPrint('Mobile目录扫描完成: directory=$directory, totalFound=$totalFound, newAdded=${result['newAdded']}');

      updateProgress(ScanProgress(
        currentPath: '完成',
        filesScanned: totalFound,
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
      debugPrint('扫描异常: $e');
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

  /// 将 MediaStore 歌曲保存到数据库
  Future<Map<String, dynamic>> _saveMediaSongsToDatabase(
    List<SongModel> mediaSongs,
    String directoryPath,
  ) async {
    final db = await _dbHelper.database;
    int newAdded = 0;
    int duplicates = 0;
    int filtered = 0;
    final newSongIds = <int>[];
    // 记录 songId 和 mediaId 的映射关系，用于后续获取封面
    final songMediaIdMap = <int, int>{};
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
      for (final mediaSong in mediaSongs) {
        if (isCancelled) break;

        final filePath = mediaSong.data;
        if (filePath.isEmpty) continue;

        // 跳过已删除的路径
        if (deletedPaths.contains(filePath)) {
          continue;
        }

        if (existingPaths.contains(filePath)) {
          duplicates++;
        } else {
          // 过滤：时长不在有效范围内（165秒 ~ 1500秒）
          final durationMs = mediaSong.duration ?? 0;
          final durationSec = durationMs ~/ 1000;
          if (durationSec > 0 && (durationSec < _minDurationSec || durationSec > _maxDurationSec)) {
            filtered++;
            debugPrint('歌曲时长不在范围内，跳过: ${mediaSong.title} ($durationSec秒)');
            continue;
          }

          // WAV 文件：使用 MetadataExtractor 从文件提取元数据
          // MediaStore 对 WAV 元数据支持很差
          String title = mediaSong.title;
          String? artist = mediaSong.artist;
          String? album = mediaSong.album;

          if (filePath.toLowerCase().endsWith('.wav')) {
            debugPrint('WAV 文件，尝试从文件提取元数据: $filePath');
            final metadata = await MetadataExtractor.extract(filePath);
            if (metadata != null) {
              // 只有当提取的元数据有效时才使用
              if (metadata.title != null && metadata.title!.isNotEmpty) {
                title = metadata.title!;
              }
              if (metadata.artist != null && metadata.artist!.isNotEmpty) {
                artist = metadata.artist;
              }
              if (metadata.album != null && metadata.album!.isNotEmpty) {
                album = metadata.album;
              }
              debugPrint('WAV 元数据提取结果: title=$title, artist=$artist, album=$album');
            }

            // 如果元数据无效（来自 MediaStore 或文件提取），从文件名提取
            if (title.isEmpty || _isInvalidMetadata(title)) {
              final fileName = filePath.split(Platform.pathSeparator).last;
              title = _cleanTitleFromFileName(fileName);
              debugPrint('从文件名提取标题: $title');
            }
          }

          // 查找同名图片（优先于 MediaStore 封面）
          String? albumArtPath;
          final fileName = filePath.split(Platform.pathSeparator).last;
          final nameWithoutExt = fileName.replaceAll(RegExp(r'\.[^.]+$'), '');
          final dir = File(filePath).parent;

          // 按优先级查找同名图片
          for (final ext in ['.jpg', '.jpeg', '.png', '.webp', '.gif']) {
            final imageFileName = '$nameWithoutExt$ext'.toLowerCase();
            final imageFile = File('${dir.path}${Platform.pathSeparator}$imageFileName');
            if (await imageFile.exists()) {
              albumArtPath = imageFile.path;
              debugPrint('找到同名图片: $albumArtPath');
              break;
            }
          }

          final songId = await txn.insert(
            DatabaseHelper.tableSongs,
            {
              'title': title.isEmpty ? 'Unknown' : title,
              'artist': artist,
              'album': album,
              'duration': durationSec,
              'file_path': filePath,
              'album_art_path': albumArtPath,
              'date_added': null,
              'created_at': nowIso,
              'updated_at': nowIso,
            },
          );
          newSongIds.add(songId);
          // 记录映射关系（仅当没有同名图片时才需要从 MediaStore 获取封面）
          if (albumArtPath == null) {
            songMediaIdMap[songId] = mediaSong.id;
          }
          newAdded++;
        }
      }
    });

    // 4. 并行获取封面（事务外执行）
    if (!isCancelled && newSongIds.isNotEmpty) {
      debugPrint('开始并行获取封面，共 ${songMediaIdMap.length} 首');
      await _fetchArtworksParallel(songMediaIdMap);
      debugPrint('封面获取完成');
    }

    debugPrint('MediaStore扫描完成: newAdded=$newAdded, duplicates=$duplicates, filtered=$filtered');
    return {'newAdded': newAdded, 'duplicates': duplicates, 'newSongIds': newSongIds};
  }

  /// 并行获取封面
  Future<void> _fetchArtworksParallel(
    Map<int, int> songMediaIdMap,
  ) async {
    final db = await _dbHelper.database;
    final batchSize = options.artworkBatchSize;
    final entries = songMediaIdMap.entries.toList();

    for (var i = 0; i < entries.length; i += batchSize) {
      if (isCancelled) break;

      final batch = entries.sublist(
        i,
        (i + batchSize < entries.length) ? i + batchSize : entries.length,
      );

      final results = await Future.wait(
        batch.map((entry) async {
          final artPath = await _fetchAndSaveArtwork(entry.key, entry.value);
          return (songId: entry.key, artPath: artPath);
        }),
      );

      // 批量更新封面路径
      final updateBatch = db.batch();
      for (final result in results) {
        if (result.artPath != null) {
          updateBatch.update(
            DatabaseHelper.tableSongs,
            {
              'album_art_path': result.artPath,
              'updated_at': DateTime.now().toIso8601String(),
            },
            where: 'id = ?',
            whereArgs: [result.songId],
          );
        }
      }
      await updateBatch.commit(noResult: true);
    }
  }

  /// 递归扫描目录（同时构建歌词缓存）
  Future<void> _scanDirectory(
    String path,
    List<File> songs,
    void Function(String path, int count) onProgress,
  ) async {
    if (isCancelled) return;

    try {
      final dir = Directory(path);
      if (!await dir.exists()) {
        debugPrint('目录不存在: $path');
        return;
      }

      // 收集当前目录的歌词文件
      final lrcNames = <String>{};
      // 收集当前目录的图片文件
      final imageFiles = <String, String>{};
      int entityCount = 0;
      int dirCount = 0;
      int fileCount = 0;

      await for (final entity in dir.list(followLinks: false)) {
        if (isCancelled) return;

        entityCount++;

        if (entity is Directory) {
          dirCount++;
          final dirName = entity.path.split(Platform.pathSeparator).last;
          if (_skipDirectories.contains(dirName)) {
            debugPrint('跳过目录: $dirName');
            continue;
          }

          try {
            await _scanDirectory(entity.path, songs, onProgress);
          } catch (e) {
            debugPrint('无法访问目录 ${entity.path}: $e');
          }
        } else if (entity is File) {
          fileCount++;
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
              // 检查文件名是否像非音乐文件
              if (_isLikelyNonMusicFile(entity.path)) {
                debugPrint('跳过非音乐文件: ${entity.path}');
                break;
              }
              // 检查文件大小
              try {
                final fileSize = await entity.length();
                if (fileSize >= options.minFileSizeBytes) {
                  songs.add(entity);
                  onProgress(entity.path, 1);
                } else {
                  debugPrint('文件太小，跳过: ${entity.path} ($fileSize bytes)');
                }
              } catch (e) {
                debugPrint('无法读取文件 ${entity.path}: $e');
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

      debugPrint('目录 $path: 共 $entityCount 个实体, $dirCount 个目录, $fileCount 个文件, 找到 ${songs.length} 首歌曲');
    } catch (e) {
      debugPrint('扫描目录失败 $path: $e');
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

  /// 检查元数据是否无效（全是问号）
  bool _isInvalidMetadata(String value) {
    if (value.isEmpty) return true;
    for (int i = 0; i < value.length; i++) {
      if (value.codeUnitAt(i) != 0x3F) {
        return false;
      }
    }
    return true;
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

      final batchResults = await Future.wait(
        batch.map((path) => _extractMetadata(path)),
      );

      // 添加歌词路径和封面路径
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
  /// 接收已提取的元数据列表，不再在事务内提取元数据
  /// 返回 Map 包含：newAdded（新增数量）、duplicates（重复数量）、newSongIds（新增歌曲ID列表）
  Future<Map<String, dynamic>> _saveSongsToDatabase(List<_AudioMetadata> metadataList) async {
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
        // 根据 autoDedupe 选项决定行为
        // 无论 autoDedupe 值如何，都跳过已存在的文件（数据库有唯一约束）
        // 但计数方式不同：autoDedupe=true 计入 duplicates，否则计入 skipped
        if (options.autoDedupe) {
          duplicates++;
        } else {
          skipped++;
        }
      } else {
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

    debugPrint('Mobile扫描完成: newAdded=$newAdded, duplicates=$duplicates, filtered=$filtered, skipped=$skipped');
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
  });

  final String filePath;
  final String? title;
  final String? artist;
  final String? album;
  final int? duration;
  String? lyricsPath;
  String? albumArtPath;
}
