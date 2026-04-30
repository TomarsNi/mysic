import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 扫描选项配置管理
class ScanOptionsProvider extends ChangeNotifier {
  /// 支持的音频格式列表
  static const List<String> kDefaultFormats = [
    'mp3', 'flac', 'wav', 'm4a', 'ogg', 'aac', 'wma', 'ape'
  ];

  /// 默认最小文件大小 (KB)
  static const int kDefaultMinFileSizeKb = 100;

  /// 默认自动去重
  static const bool kDefaultAutoDedupe = true;

  List<String> _audioFormats = List.from(kDefaultFormats);
  int _minFileSizeKb = kDefaultMinFileSizeKb;
  bool _autoDedupe = kDefaultAutoDedupe;
  bool _isLoaded = false;

  /// 要扫描的音频格式
  List<String> get audioFormats => List.unmodifiable(_audioFormats);

  /// 最小文件大小 (KB)
  int get minFileSizeKb => _minFileSizeKb;

  /// 是否自动去重
  bool get autoDedupe => _autoDedupe;

  /// 是否已加载
  bool get isLoaded => _isLoaded;

  /// 从 SharedPreferences 加载配置
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();

    _audioFormats = prefs.getStringList('scan_audio_formats') ?? List.from(kDefaultFormats);
    _minFileSizeKb = prefs.getInt('scan_min_file_size_kb') ?? kDefaultMinFileSizeKb;
    _autoDedupe = prefs.getBool('scan_auto_dedupe') ?? kDefaultAutoDedupe;
    _isLoaded = true;

    notifyListeners();
  }

  /// 切换音频格式
  Future<void> toggleFormat(String format) async {
    if (_audioFormats.contains(format)) {
      _audioFormats.remove(format);
    } else {
      _audioFormats.add(format);
    }
    await _saveFormats();
    notifyListeners();
  }

  /// 设置最小文件大小
  Future<void> setMinFileSizeKb(int value) async {
    _minFileSizeKb = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('scan_min_file_size_kb', value);
    notifyListeners();
  }

  /// 设置自动去重
  Future<void> setAutoDedupe(bool value) async {
    _autoDedupe = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('scan_auto_dedupe', value);
    notifyListeners();
  }

  /// 重置为默认值
  Future<void> resetToDefaults() async {
    _audioFormats = List.from(kDefaultFormats);
    _minFileSizeKb = kDefaultMinFileSizeKb;
    _autoDedupe = kDefaultAutoDedupe;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('scan_audio_formats', _audioFormats);
    await prefs.setInt('scan_min_file_size_kb', _minFileSizeKb);
    await prefs.setBool('scan_auto_dedupe', _autoDedupe);

    notifyListeners();
  }

  /// 保存格式列表
  Future<void> _saveFormats() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('scan_audio_formats', _audioFormats);
  }
}
