import 'package:flutter/foundation.dart';
import '../../data/models/api_config.dart';
import '../../data/repositories/api_config_repository.dart';

/// API 配置状态管理
/// 负责管理所有服务商的 API 配置状态
class ApiConfigProvider extends ChangeNotifier {
  final ApiConfigRepository _repository;

  ApiConfigProvider({ApiConfigRepository? repository})
      : _repository = repository ?? ApiConfigRepository();

  /// 所有配置列表
  List<ApiConfig> _configs = [];

  /// 只读访问配置列表
  List<ApiConfig> get configs => List.unmodifiable(_configs);

  /// 当前启用的配置
  ApiConfig? _enabledConfig;

  /// 只读访问启用的配置
  ApiConfig? get enabledConfig => _enabledConfig;

  /// 是否已加载
  bool _isLoaded = false;

  /// 只读访问加载状态
  bool get isLoaded => _isLoaded;

  /// 加载所有配置和已启用的配置
  Future<void> load() async {
    _configs = await _repository.getAll();
    _enabledConfig = await _repository.getEnabled();
    _isLoaded = true;
    notifyListeners();
  }

  /// 确保所有服务商都有默认配置
  Future<void> ensureDefaultConfigs() async {
    final existingProviders = _configs.map((c) => c.provider).toSet();
    final allProviders = ApiProvider.values;

    for (final provider in allProviders) {
      if (!existingProviders.contains(provider)) {
        final defaultConfig = ApiConfig.defaultFor(provider);
        await _repository.save(defaultConfig);
      }
    }

    // 重新加载配置
    await load();
  }

  /// 获取指定服务商的配置
  ApiConfig? getConfig(ApiProvider provider) {
    try {
      return _configs.firstWhere((c) => c.provider == provider);
    } catch (_) {
      return null;
    }
  }

  /// 保存配置
  Future<void> save(ApiConfig config) async {
    await _repository.save(config);
    await load();
  }

  /// 切换启用状态
  /// 返回是否成功：
  /// - 如果配置不完整返回 false
  /// - 如果已启用则禁用
  /// - 如果未启用且配置完整则启用
  Future<bool> toggleEnable(ApiProvider provider) async {
    final config = getConfig(provider);

    // 配置不存在，无法切换
    if (config == null) return false;

    // 配置不完整，无法启用
    if (!config.isConfigured) return false;

    // 已启用 -> 禁用
    if (config.isEnabled) {
      await _repository.disableAll();
      await load();
      return true;
    }

    // 未启用 -> 启用
    await _repository.enableOnly(provider);
    await load();
    return true;
  }

  /// 更新配置字段
  Future<void> updateConfig(
    ApiProvider provider, {
    String? apiUrl,
    String? apiKey,
    String? modelName,
  }) async {
    final config = getConfig(provider) ?? ApiConfig.defaultFor(provider);
    final updatedConfig = config.copyWith(
      apiUrl: apiUrl,
      apiKey: apiKey,
      modelName: modelName,
    );
    await _repository.save(updatedConfig);
    await load();
  }
}
