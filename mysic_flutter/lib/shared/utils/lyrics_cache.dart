import 'dart:io';

/// 歌词文件缓存
/// 在文件扫描阶段预先收集所有歌词文件，避免重复扫描目录
class LyricsCache {
  /// 清理文件名的正则表达式（移除序号前缀）
  static final _cleanPattern = RegExp(r'^\d+[\s.\-_]*');

  /// 目录路径 → 该目录下歌词文件名集合（不含扩展名）
  final Map<String, Set<String>> _directoryCache = {};

  /// 添加目录的歌词文件
  void addDirectory(String dirPath, Set<String> lrcNames) {
    if (lrcNames.isNotEmpty) {
      _directoryCache[dirPath] = lrcNames;
    }
  }

  /// 查找音频文件对应的歌词文件
  /// 返回完整路径，找不到返回 null
  String? findLyricsPath(String audioFilePath) {
    if (audioFilePath.isEmpty) return null;

    final dirPath = _getParentDirectory(audioFilePath);
    final audioName = _getFileNameWithoutExtension(audioFilePath);
    final lrcNames = _directoryCache[dirPath];

    if (lrcNames == null) return null;

    // 精确匹配
    if (lrcNames.contains(audioName)) {
      return _buildPath(dirPath, '$audioName.lrc', audioFilePath);
    }

    // 宽松匹配（忽略序号前缀）
    final cleanedAudioName = _cleanFileName(audioName);
    for (final lrcName in lrcNames) {
      if (_cleanFileName(lrcName) == cleanedAudioName) {
        return _buildPath(dirPath, '$lrcName.lrc', audioFilePath);
      }
    }

    return null;
  }

  /// 构建路径（保持输入路径的分隔符风格）
  String _buildPath(String dir, String fileName, String originalPath) {
    // 统一使用原始路径的分隔符风格
    final separator = originalPath.contains('\\') ? '\\' : '/';
    // 确保 dir 不以分隔符结尾，避免双分隔符
    final normalizedDir = dir.endsWith(separator) ? dir.substring(0, dir.length - 1) : dir;
    return '$normalizedDir$separator$fileName';
  }

  /// 获取父目录路径（跨平台兼容）
  String _getParentDirectory(String path) {
    // 统一使用 / 分割，支持跨平台路径
    final parts = path.replaceAll('\\', '/').split('/');
    if (parts.length <= 1) return '';
    return parts.sublist(0, parts.length - 1).join('/');
  }

  /// 获取文件名（不含扩展名）
  String _getFileNameWithoutExtension(String path) {
    // 统一使用 / 分割，支持跨平台路径
    final fileName = path.replaceAll('\\', '/').split('/').last;
    return fileName.replaceAll(RegExp(r'\.[^.]+$'), '');
  }

  /// 清理文件名：移除序号前缀并转小写
  String _cleanFileName(String name) {
    // 移除序号前缀（如 "01 - ", "02.", "03_"）
    return name.replaceFirst(_cleanPattern, '').toLowerCase();
  }

  /// 获取缓存的目录数量
  int get cachedDirectoryCount => _directoryCache.length;

  /// 清空缓存
  void clear() {
    _directoryCache.clear();
  }
}
