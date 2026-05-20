import 'dart:io';

import 'package:mysic_flutter/core/utils/app_logger.dart';

/// 文件操作工具类
class FileUtils {
  /// 删除文件
  /// 静默处理错误，不抛出异常
  /// 返回 true 表示删除成功，false 表示文件不存在或删除失败
  static Future<bool> deleteFile(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        return true;
      }
      // 文件不存在，视为成功（幂等）
      return false;
    } catch (e) {
      // 文件删除失败不阻塞流程，仅记录日志
      AppLogger.w('FileUtils#deleteFile', '删除文件失败: $e');
      return false;
    }
  }
}
