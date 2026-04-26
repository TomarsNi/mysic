import 'package:flutter/foundation.dart';

/// 大模型服务商枚举
enum ApiProvider {
  aliyun,
  zhipu,
  xunfei,
  tencent,
}

/// ApiProvider 扩展方法
extension ApiProviderExtension on ApiProvider {
  /// 显示名称
  String get displayName => switch (this) {
        ApiProvider.aliyun => '阿里云百炼',
        ApiProvider.zhipu => '智谱 AI',
        ApiProvider.xunfei => '讯飞星火',
        ApiProvider.tencent => '腾讯混元',
      };

  /// 描述
  String get description => switch (this) {
        ApiProvider.aliyun => '通义千问系列模型',
        ApiProvider.zhipu => 'GLM 系列模型',
        ApiProvider.xunfei => 'Spark 系列模型',
        ApiProvider.tencent => 'Hunyuan 系列模型',
      };

  /// 默认 API URL
  String get defaultApiUrl => switch (this) {
        ApiProvider.aliyun => 'https://dashscope.aliyuncs.com/api/v1',
        ApiProvider.zhipu => 'https://open.bigmodel.cn/api/paas/v4',
        ApiProvider.xunfei => 'https://spark-api-open.xf-yun.com/v1',
        ApiProvider.tencent => 'https://api.hunyuan.cloud.tencent.com/v1',
      };

  /// 默认模型名称
  String get defaultModelName => switch (this) {
        ApiProvider.aliyun => 'qwen-plus',
        ApiProvider.zhipu => 'glm-4',
        ApiProvider.xunfei => 'spark-4.0-ultra',
        ApiProvider.tencent => 'hunyuan-lite',
      };

  /// 从字符串解析
  static ApiProvider? fromString(String value) {
    return switch (value) {
      'aliyun' => ApiProvider.aliyun,
      'zhipu' => ApiProvider.zhipu,
      'xunfei' => ApiProvider.xunfei,
      'tencent' => ApiProvider.tencent,
      _ => null,
    };
  }

  /// 转换为字符串（用于存储）
  String toValueString() => switch (this) {
        ApiProvider.aliyun => 'aliyun',
        ApiProvider.zhipu => 'zhipu',
        ApiProvider.xunfei => 'xunfei',
        ApiProvider.tencent => 'tencent',
      };
}

/// API 配置数据模型
@immutable
class ApiConfig {
  /// 唯一标识符（数据库主键）
  final int? id;

  /// 服务商
  final ApiProvider provider;

  /// API URL
  final String apiUrl;

  /// API Key
  final String apiKey;

  /// 模型名称
  final String modelName;

  /// 是否启用
  final bool isEnabled;

  const ApiConfig({
    this.id,
    required this.provider,
    this.apiUrl = '',
    this.apiKey = '',
    this.modelName = '',
    this.isEnabled = false,
  });

  /// 检查是否已配置所有必填项
  bool get isConfigured =>
      apiUrl.isNotEmpty && apiKey.isNotEmpty && modelName.isNotEmpty;

  /// 创建指定服务商的默认配置
  factory ApiConfig.defaultFor(ApiProvider provider) {
    return ApiConfig(
      provider: provider,
      apiUrl: provider.defaultApiUrl,
      apiKey: '',
      modelName: provider.defaultModelName,
    );
  }

  /// 复制并修改部分字段
  ApiConfig copyWith({
    int? id,
    ApiProvider? provider,
    String? apiUrl,
    String? apiKey,
    String? modelName,
    bool? isEnabled,
  }) {
    return ApiConfig(
      id: id ?? this.id,
      provider: provider ?? this.provider,
      apiUrl: apiUrl ?? this.apiUrl,
      apiKey: apiKey ?? this.apiKey,
      modelName: modelName ?? this.modelName,
      isEnabled: isEnabled ?? this.isEnabled,
    );
  }

  /// 转换为 Map（用于数据库存储）
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'provider': provider.toValueString(),
      'api_url': apiUrl,
      'api_key': apiKey,
      'model_name': modelName,
      'is_enabled': isEnabled ? 1 : 0,
    };
  }

  /// 从 Map 创建（用于数据库读取）
  factory ApiConfig.fromMap(Map<String, dynamic> map) {
    final providerStr = map['provider'] as String;
    final provider = ApiProviderExtension.fromString(providerStr);

    if (provider == null) {
      throw ArgumentError('Unknown provider: $providerStr');
    }

    return ApiConfig(
      id: map['id'] as int?,
      provider: provider,
      apiUrl: map['api_url'] as String? ?? '',
      apiKey: map['api_key'] as String? ?? '',
      modelName: map['model_name'] as String? ?? '',
      isEnabled: map['is_enabled'] == 1,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is ApiConfig &&
        other.id == id &&
        other.provider == provider &&
        other.apiUrl == apiUrl &&
        other.apiKey == apiKey &&
        other.modelName == modelName &&
        other.isEnabled == isEnabled;
  }

  @override
  int get hashCode {
    return Object.hash(id, provider, apiUrl, apiKey, modelName, isEnabled);
  }
}
