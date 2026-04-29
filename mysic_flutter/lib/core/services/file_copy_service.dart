import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// 文件复制服务
/// 负责将用户选择的文件复制到应用目录
class FileCopyService {
  static final FileCopyService _instance = FileCopyService._internal();
  factory FileCopyService() => _instance;
  FileCopyService._internal();

  /// 支持的图片扩展名
  static const List<String> _supportedImageExtensions = ['jpg', 'jpeg', 'png', 'webp'];

  /// 复制专辑封面图片到应用目录
  Future<String?> copyAlbumCover(String sourcePath, int songId) async {
    try {
      final sourceFile = File(sourcePath);
      if (!await sourceFile.exists()) {
        return null;
      }

      final extension = p.extension(sourcePath).toLowerCase();
      final extWithoutDot = extension.isEmpty ? 'jpg' : extension.substring(1);

      if (!_supportedImageExtensions.contains(extWithoutDot)) {
        return null;
      }

      final appDir = await getApplicationSupportDirectory();
      final coversDir = Directory(p.join(appDir.path, 'album_covers'));
      if (!await coversDir.exists()) {
        await coversDir.create(recursive: true);
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final targetPath = p.join(coversDir.path, '${songId}_$timestamp.$extWithoutDot');

      await sourceFile.copy(targetPath);

      return targetPath;
    } catch (e) {
      return null;
    }
  }

  /// 复制歌词文件到应用目录
  Future<String?> copyLyrics(String sourcePath, int songId) async {
    try {
      final sourceFile = File(sourcePath);
      if (!await sourceFile.exists()) {
        return null;
      }

      final extension = p.extension(sourcePath).toLowerCase();
      if (extension != '.lrc') {
        return null;
      }

      final appDir = await getApplicationSupportDirectory();
      final lyricsDir = Directory(p.join(appDir.path, 'lyrics'));
      if (!await lyricsDir.exists()) {
        await lyricsDir.create(recursive: true);
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final targetPath = p.join(lyricsDir.path, '${songId}_$timestamp.lrc');

      await sourceFile.copy(targetPath);

      return targetPath;
    } catch (e) {
      return null;
    }
  }

  /// 删除文件
  Future<void> deleteFile(String? path) async {
    if (path == null || path.isEmpty) return;

    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      // 忽略删除失败
    }
  }
}