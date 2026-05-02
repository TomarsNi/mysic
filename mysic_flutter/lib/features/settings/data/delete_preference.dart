import 'package:shared_preferences/shared_preferences.dart';

/// 删除操作偏好设置
/// 用于存储用户在删除确认弹窗中的勾选状态
class DeletePreference {
  static const _keyDeleteWithFile = 'delete_song_with_file';

  /// 获取是否同时删除文件
  /// 默认为 false（不同时删除）
  static Future<bool> getDeleteWithFile() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyDeleteWithFile) ?? false;
  }

  /// 设置是否同时删除文件
  static Future<void> setDeleteWithFile(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyDeleteWithFile, value);
  }
}