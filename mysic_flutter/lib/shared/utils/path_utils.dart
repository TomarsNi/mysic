/// 路径工具类
class PathUtils {
  /// 检查文件是否属于指定目录（精确路径前缀匹配）
  /// 使用路径规范化，确保精确匹配
  static bool isPathInDirectory(String filePath, String directoryPath) {
    // 规范化路径（统一使用正斜杠）
    final normalizedFile = filePath.replaceAll('\\', '/').toLowerCase();
    final normalizedDir = directoryPath.replaceAll('\\', '/').toLowerCase();

    // 确保目录路径以分隔符结尾，避免部分匹配
    // 例如避免 "G:\music\成名曲" 匹配 "G:\music\成名"
    final dirWithSeparator = normalizedDir.endsWith('/')
        ? normalizedDir
        : '$normalizedDir/';

    return normalizedFile.startsWith(dirWithSeparator);
  }
}
