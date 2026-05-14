/// 图片文件缓存
/// 在文件扫描阶段预先收集所有图片文件，支持按音频文件名查找同名图片
class ImageCache {
  /// 支持的图片格式（按优先级排序）
  static const _extensions = ['.jpg', '.jpeg', '.png', '.webp', '.gif'];

  /// 目录路径 → {小写文件名（含扩展名） → 图片完整路径}
  final Map<String, Map<String, String>> _cache = {};

  /// 添加目录下的图片到缓存
  void addDirectory(String directory, Map<String, String> images) {
    if (images.isNotEmpty) {
      // 统一路径分隔符，确保缓存键一致
      final normalizedDir = directory.replaceAll('\\', '/');
      _cache[normalizedDir] = images;
    }
  }

  /// 查找音频文件对应的图片路径
  /// 返回优先级最高的匹配图片路径，无匹配返回 null
  String? findImagePath(String audioFilePath) {
    if (audioFilePath.isEmpty) return null;

    final dirPath = _getParentDirectory(audioFilePath);
    final audioName = _getFileNameWithoutExtension(audioFilePath);
    final images = _cache[dirPath];

    if (images == null) return null;

    // 按优先级查找同名图片
    for (final ext in _extensions) {
      final key = '$audioName$ext'.toLowerCase();
      if (images.containsKey(key)) {
        return images[key];
      }
    }

    return null;
  }

  /// 获取父目录路径（跨平台兼容）
  String _getParentDirectory(String path) {
    final parts = path.replaceAll('\\', '/').split('/');
    if (parts.length <= 1) return '';
    return parts.sublist(0, parts.length - 1).join('/');
  }

  /// 获取文件名（不含扩展名）
  String _getFileNameWithoutExtension(String path) {
    final fileName = path.replaceAll('\\', '/').split('/').last;
    return fileName.replaceAll(RegExp(r'\.[^.]+$'), '');
  }

  /// 获取缓存的目录数量
  int get cachedDirectoryCount => _cache.length;

  /// 清空缓存
  void clear() {
    _cache.clear();
  }
}
