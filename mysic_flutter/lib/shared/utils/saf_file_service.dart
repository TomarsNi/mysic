import 'package:flutter/services.dart';
import 'package:mysic_flutter/core/utils/app_logger.dart';

/// SAF (Storage Access Framework) 文件读取服务
/// 用于在 Android 上读取需要 SAF 授权的文件
class SafFileService {
  static const MethodChannel _channel = MethodChannel('com.nbb.mysic_flutter/saf_file');

  /// 检查是否是 SAF URI
  static bool isSafUri(String path) {
    return path.startsWith('content://');
  }

  /// 打开 SAF 目录选择器，让用户授权目录访问
  ///
  /// 返回授权的目录 URI，用户取消返回 null
  static Future<String?> pickDirectory() async {
    try {
      final result = await _channel.invokeMethod<String>('pickDirectory');
      if (result == null) {
        AppLogger.i('SafFileService#pickDirectory', '用户取消目录选择');
        return null;
      }
      AppLogger.i('SafFileService#pickDirectory', '用户选择目录: $result');
      return result;
    } catch (e) {
      AppLogger.e('SafFileService#pickDirectory', 'SAF 目录选择失败', e);
      return null;
    }
  }

  /// 通过 SAF URI 读取文件内容
  ///
  /// [safUri] SAF 格式的文件 URI，如 content://com.android.externalstorage.documents/tree/primary%3AMusic/document/primary%3AMusic%2Fsong.jpg
  /// 返回文件字节数据，失败返回 null
  static Future<Uint8List?> readFileFromSafUri(String safUri) async {
    if (!isSafUri(safUri)) {
      AppLogger.w('SafFileService#readFileFromSafUri', '不是 SAF URI: $safUri');
      return null;
    }

    try {
      final result = await _channel.invokeMethod<Uint8List>('readFile', {'uri': safUri});
      return result;
    } on PlatformException catch (e) {
      AppLogger.e('SafFileService#readFileFromSafUri', 'SAF 读取文件失败: ${e.message}', e);
      return null;
    }
  }

  /// 通过 SAF 树 URI 和相对路径读取文件
  ///
  /// [treeUri] SAF 树 URI（目录授权）
  /// [relativePath] 相对于目录的文件路径
  /// 返回文件字节数据，失败返回 null
  static Future<Uint8List?> readFileFromTreeUri(String treeUri, String relativePath) async {
    if (!isSafUri(treeUri)) {
      AppLogger.w('SafFileService#readFileFromTreeUri', '不是 SAF 树 URI: $treeUri');
      return null;
    }

    try {
      final result = await _channel.invokeMethod<Uint8List>('readFileFromTree', {
        'treeUri': treeUri,
        'relativePath': relativePath,
      });
      return result;
    } on PlatformException catch (e) {
      AppLogger.e('SafFileService#readFileFromTreeUri', 'SAF 从树读取文件失败: ${e.message}', e);
      return null;
    }
  }

  /// 构建图片文件的 SAF URI
  ///
  /// [treeUri] SAF 树 URI（目录授权）
  /// [imageFileName] 图片文件名（含扩展名）
  /// 返回构建的 SAF URI
  static String buildImageSafUri(String treeUri, String imageFileName) {
    // SAF URI 格式: content://.../tree/primary%3AMusic/document/primary%3AMusic%2Fimage.jpg
    // 需要将文件名追加到 tree URI 后面
    if (!treeUri.contains('/tree/')) {
      return treeUri;
    }

    // 获取 tree 后面的路径部分
    final treeIndex = treeUri.indexOf('/tree/');
    final encodedPath = treeUri.substring(treeIndex + 6); // '/tree/' 长度为 6

    // 构建文档 URI
    final documentPath = '$encodedPath%2F${Uri.encodeComponent(imageFileName)}';
    final documentUri = treeUri.replaceFirst('/tree/', '/document/');
    return '$documentUri/$documentPath';
  }

  /// 持久化 SAF URI 权限
  ///
  /// [uri] SAF URI
  /// 返回是否成功
  static Future<bool> persistUriPermission(String uri) async {
    if (!isSafUri(uri)) {
      return false;
    }

    try {
      final result = await _channel.invokeMethod<bool>('persistUriPermission', {'uri': uri});
      return result ?? false;
    } on PlatformException catch (e) {
      AppLogger.e('SafFileService#persistUriPermission', '持久化 SAF 权限失败: ${e.message}', e);
      return false;
    }
  }

  /// 释放 SAF URI 权限
  ///
  /// [uri] SAF URI
  static Future<void> releaseUriPermission(String uri) async {
    if (!isSafUri(uri)) {
      return;
    }

    try {
      await _channel.invokeMethod('releaseUriPermission', {'uri': uri});
    } on PlatformException catch (e) {
      AppLogger.e('SafFileService#releaseUriPermission', '释放 SAF 权限失败: ${e.message}', e);
    }
  }

  /// 检查是否有指定目录的 SAF 权限
  ///
  /// [uri] SAF URI
  static Future<bool> hasUriPermission(String uri) async {
    if (!isSafUri(uri)) {
      return false;
    }

    try {
      final result = await _channel.invokeMethod<bool>('hasUriPermission', {'uri': uri});
      return result ?? false;
    } on PlatformException catch (e) {
      AppLogger.e('SafFileService#hasUriPermission', '检查 SAF 权限失败: ${e.message}', e);
      return false;
    }
  }
}
