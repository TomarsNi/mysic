// lib/features/ai_skills/core/llm_service.dart
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:mysic_flutter/features/settings/data/models/api_config.dart';

/// 大模型调用服务
/// 封装各服务商的 API 调用逻辑
class LlmService {
  /// HTTP 客户端（可注入用于测试）
  final http.Client _client;

  /// 请求超时时间
  static const Duration timeout = Duration(seconds: 30);

  LlmService({http.Client? client}) : _client = client ?? http.Client();

  /// 发送聊天请求
  Future<String> chat({
    required ApiConfig config,
    required String prompt,
    bool enableWebSearch = false,
  }) async {
    // 验证 API Key
    if (config.apiKey.isEmpty) {
      throw LlmServiceException('API Key 未配置');
    }

    final url = Uri.parse(buildUrl(config));
    final body = buildRequestBody(
      config: config,
      prompt: prompt,
      enableWebSearch: enableWebSearch,
    );

    try {
      // 调试日志
      print('[LlmService] 请求 URL: $url');
      print('[LlmService] 请求体: ${jsonEncode(body)}');
      print('[LlmService] API Key 长度: ${config.apiKey.length}');

      final response = await _client
          .post(
            url,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer ${config.apiKey}',
            },
            body: jsonEncode(body),
          )
          .timeout(timeout);

      print('[LlmService] 响应状态码: ${response.statusCode}');
      print('[LlmService] 响应体: ${response.body}');

      if (response.statusCode != 200) {
        throw LlmServiceException(
          'API 请求失败: ${response.statusCode} - ${response.body}',
          statusCode: response.statusCode,
          body: response.body,
        );
      }

      final jsonResponse = jsonDecode(response.body) as Map<String, dynamic>;
      return parseResponse(config: config, response: jsonResponse);
    } on TimeoutException {
      throw LlmServiceException('API 请求超时');
    }
  }

  /// 构建请求 URL（根据服务商）
  String buildUrl(ApiConfig config) {
    return switch (config.provider) {
      ApiProvider.aliyun =>
        'https://dashscope.aliyuncs.com/api/v1/services/aigc/text-generation/generation',
      ApiProvider.zhipu =>
        'https://open.bigmodel.cn/api/paas/v4/chat/completions',
      ApiProvider.xunfei =>
        'https://spark-api-open.xf-yun.com/v1/chat/completions',
      ApiProvider.tencent =>
        'https://api.hunyuan.cloud.tencent.com/v1/chat/completions',
      ApiProvider.openai =>
        '${config.apiUrl}/chat/completions',
    };
  }

  /// 构建请求体（根据服务商）
  Map<String, dynamic> buildRequestBody({
    required ApiConfig config,
    required String prompt,
    required bool enableWebSearch,
  }) {
    return switch (config.provider) {
      ApiProvider.aliyun => {
        'model': config.modelName,
        'input': {
          'messages': [
            {'role': 'user', 'content': prompt},
          ],
        },
        'parameters': {
          if (enableWebSearch)
            'search_options': {'enable_search': true},
        },
      },
      ApiProvider.zhipu => {
        'model': config.modelName,
        'messages': [
          {'role': 'user', 'content': prompt},
        ],
        if (enableWebSearch)
          'tools': [
            {
              'type': 'web_search',
              'web_search': {'enable': true},
            },
          ],
      },
      ApiProvider.xunfei => {
        'model': config.modelName,
        'messages': [
          {'role': 'user', 'content': prompt},
        ],
        if (enableWebSearch) 'functions': [{'name': 'web_search'}],
      },
      ApiProvider.tencent => {
        'model': config.modelName,
        'messages': [
          {'role': 'user', 'content': prompt},
        ],
        if (enableWebSearch) 'enable_search': true,
      },
      ApiProvider.openai => {
        'model': config.modelName,
        'messages': [
          {'role': 'user', 'content': prompt},
        ],
      },
    };
  }

  /// 解析响应（根据服务商）
  String parseResponse({
    required ApiConfig config,
    required Map<String, dynamic> response,
  }) {
    switch (config.provider) {
      case ApiProvider.aliyun:
        final output = response['output'] as Map<String, dynamic>?;
        if (output == null) {
          throw LlmServiceException('无法解析阿里云响应: 缺少 output 字段');
        }
        // 尝试 text 字段（部分模型）
        final text = output['text'] as String?;
        if (text != null) return text;
        // 尝试 choices 字段（兼容格式）
        final choices = output['choices'] as String?;
        if (choices != null) return choices;
        throw LlmServiceException('无法解析阿里云响应: 未找到有效内容');
      case ApiProvider.zhipu:
      case ApiProvider.xunfei:
      case ApiProvider.tencent:
      case ApiProvider.openai:
        final choices = response['choices'] as List<dynamic>?;
        if (choices == null || choices.isEmpty) {
          throw LlmServiceException('无法解析响应: 缺少 choices 字段');
        }
        final message =
            (choices.first as Map<String, dynamic>)['message'] as Map<String, dynamic>?;
        if (message == null) {
          throw LlmServiceException('无法解析响应: 缺少 message 字段');
        }
        return message['content'] as String;
    }
  }

  /// 关闭客户端
  void dispose() {
    _client.close();
  }
}

/// LLM 服务异常
class LlmServiceException implements Exception {
  final String message;
  final int? statusCode;
  final String? body;

  const LlmServiceException(this.message, {this.statusCode, this.body});

  @override
  String toString() => 'LlmServiceException: $message';
}
