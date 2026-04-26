// test/features/ai_skills/core/llm_service_test.dart
import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mysic_flutter/features/ai_skills/core/llm_service.dart';
import 'package:mysic_flutter/features/settings/data/models/api_config.dart';

/// 用于测试的 Mock HTTP 客户端
class MockHttpClient extends http.BaseClient {
  /// 设置要返回的响应
  http.Response? response;

  /// 设置是否抛出超时异常
  bool shouldTimeout = false;

  /// 记录最后请求的 URL
  Uri? lastRequestUrl;

  /// 记录最后请求的 headers
  Map<String, String>? lastRequestHeaders;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    lastRequestUrl = request.url;
    lastRequestHeaders = request.headers;

    if (shouldTimeout) {
      throw TimeoutException('Request timed out');
    }

    if (response == null) {
      throw StateError('No response configured for mock client');
    }

    return http.StreamedResponse(
      Stream.value(utf8.encode(response!.body)),
      response!.statusCode,
      headers: {'content-type': 'application/json'},
    );
  }
}

void main() {
  group('LlmService', () {
    late LlmService service;
    late MockHttpClient mockClient;

    setUp(() {
      mockClient = MockHttpClient();
      service = LlmService(client: mockClient);
    });

    tearDown(() {
      service.dispose();
    });

    group('buildUrl', () {
      test('returns correct URL for aliyun', () {
        final config = ApiConfig.defaultFor(ApiProvider.aliyun);
        final url = service.buildUrl(config);
        expect(
          url,
          'https://dashscope.aliyuncs.com/api/v1/services/aigc/text-generation/generation',
        );
      });

      test('returns correct URL for zhipu', () {
        final config = ApiConfig.defaultFor(ApiProvider.zhipu);
        final url = service.buildUrl(config);
        expect(url, 'https://open.bigmodel.cn/api/paas/v4/chat/completions');
      });

      test('returns correct URL for xunfei', () {
        final config = ApiConfig.defaultFor(ApiProvider.xunfei);
        final url = service.buildUrl(config);
        expect(url, 'https://spark-api-open.xf-yun.com/v1/chat/completions');
      });

      test('returns correct URL for tencent', () {
        final config = ApiConfig.defaultFor(ApiProvider.tencent);
        final url = service.buildUrl(config);
        expect(
          url,
          'https://api.hunyuan.cloud.tencent.com/v1/chat/completions',
        );
      });
    });

    group('buildRequestBody', () {
      test('builds correct request for aliyun with web search', () {
        final config = ApiConfig.defaultFor(ApiProvider.aliyun).copyWith(
          modelName: 'qwen-plus',
        );
        final body = service.buildRequestBody(
          config: config,
          prompt: '测试提示',
          enableWebSearch: true,
        );

        expect(body['model'], 'qwen-plus');
        expect(body['input'], isA<Map>());
        expect((body['input'] as Map)['messages'], isA<List>());
        expect(body['parameters'], isA<Map>());
        expect((body['parameters'] as Map)['search_options'], isA<Map>());
      });

      test('builds correct request for aliyun without web search', () {
        final config = ApiConfig.defaultFor(ApiProvider.aliyun).copyWith(
          modelName: 'qwen-plus',
        );
        final body = service.buildRequestBody(
          config: config,
          prompt: '测试提示',
          enableWebSearch: false,
        );

        expect(body['model'], 'qwen-plus');
        expect(body['input'], isA<Map>());
        expect((body['input'] as Map)['messages'], isA<List>());
        // parameters should exist but be empty (no search_options)
        expect(body['parameters'], isA<Map>());
        expect((body['parameters'] as Map)['search_options'], isNull);
      });

      test('builds correct request for zhipu with web search', () {
        final config = ApiConfig.defaultFor(ApiProvider.zhipu).copyWith(
          modelName: 'glm-4',
        );
        final body = service.buildRequestBody(
          config: config,
          prompt: '测试提示',
          enableWebSearch: true,
        );

        expect(body['model'], 'glm-4');
        expect(body['messages'], isA<List>());
        expect(body['tools'], isA<List>());
      });

      test('builds correct request for zhipu without web search', () {
        final config = ApiConfig.defaultFor(ApiProvider.zhipu).copyWith(
          modelName: 'glm-4',
        );
        final body = service.buildRequestBody(
          config: config,
          prompt: '测试提示',
          enableWebSearch: false,
        );

        expect(body['model'], 'glm-4');
        expect(body['messages'], isA<List>());
        expect(body['tools'], isNull);
      });

      test('builds correct request for xunfei with web search', () {
        final config = ApiConfig.defaultFor(ApiProvider.xunfei).copyWith(
          modelName: 'spark-4.0-ultra',
        );
        final body = service.buildRequestBody(
          config: config,
          prompt: '测试提示',
          enableWebSearch: true,
        );

        expect(body['model'], 'spark-4.0-ultra');
        expect(body['messages'], isA<List>());
        expect(body['functions'], isA<List>());
      });

      test('builds correct request for tencent with web search', () {
        final config = ApiConfig.defaultFor(ApiProvider.tencent).copyWith(
          modelName: 'hunyuan-lite',
        );
        final body = service.buildRequestBody(
          config: config,
          prompt: '测试提示',
          enableWebSearch: true,
        );

        expect(body['model'], 'hunyuan-lite');
        expect(body['messages'], isA<List>());
        expect(body['enable_search'], true);
      });

      test('builds correct request for tencent without web search', () {
        final config = ApiConfig.defaultFor(ApiProvider.tencent).copyWith(
          modelName: 'hunyuan-lite',
        );
        final body = service.buildRequestBody(
          config: config,
          prompt: '测试提示',
          enableWebSearch: false,
        );

        expect(body['model'], 'hunyuan-lite');
        expect(body['messages'], isA<List>());
        expect(body['enable_search'], isNull);
      });
    });

    group('parseResponse', () {
      test('parses aliyun response with text field', () {
        final config = ApiConfig.defaultFor(ApiProvider.aliyun);
        final response = {
          'output': {'text': '这是回复内容'},
        };
        final result = service.parseResponse(config: config, response: response);
        expect(result, '这是回复内容');
      });

      test('parses aliyun response with choices field', () {
        final config = ApiConfig.defaultFor(ApiProvider.aliyun);
        final response = {
          'output': {'choices': '这是choices回复'},
        };
        final result = service.parseResponse(config: config, response: response);
        expect(result, '这是choices回复');
      });

      test('parses zhipu response', () {
        final config = ApiConfig.defaultFor(ApiProvider.zhipu);
        final response = {
          'choices': [
            {'message': {'content': '智谱回复内容'}},
          ],
        };
        final result = service.parseResponse(config: config, response: response);
        expect(result, '智谱回复内容');
      });

      test('parses xunfei response', () {
        final config = ApiConfig.defaultFor(ApiProvider.xunfei);
        final response = {
          'choices': [
            {'message': {'content': '讯飞回复内容'}},
          ],
        };
        final result = service.parseResponse(config: config, response: response);
        expect(result, '讯飞回复内容');
      });

      test('parses tencent response', () {
        final config = ApiConfig.defaultFor(ApiProvider.tencent);
        final response = {
          'choices': [
            {'message': {'content': '腾讯回复内容'}},
          ],
        };
        final result = service.parseResponse(config: config, response: response);
        expect(result, '腾讯回复内容');
      });
    });

    group('chat error handling', () {
      test('throws LlmServiceException when API key is empty', () async {
        final config = ApiConfig.defaultFor(ApiProvider.zhipu);
        // defaultFor creates config with empty apiKey

        expect(
          () => service.chat(config: config, prompt: '测试'),
          throwsA(isA<LlmServiceException>().having(
            (e) => e.message,
            'message',
            'API Key 未配置',
          )),
        );
      });

      test('throws LlmServiceException on HTTP error response', () async {
        final config = ApiConfig.defaultFor(ApiProvider.zhipu).copyWith(
          apiKey: 'test-api-key',
        );
        mockClient.response = http.Response('{"error": "Unauthorized"}', 401);

        expect(
          () => service.chat(config: config, prompt: '测试'),
          throwsA(isA<LlmServiceException>()
              .having((e) => e.message, 'message', contains('API 请求失败'))
              .having((e) => e.statusCode, 'statusCode', 401)
              .having((e) => e.body, 'body', '{"error": "Unauthorized"}')),
        );
      });

      test('throws LlmServiceException on HTTP 500 error', () async {
        final config = ApiConfig.defaultFor(ApiProvider.aliyun).copyWith(
          apiKey: 'test-api-key',
        );
        mockClient.response = http.Response('Internal Server Error', 500);

        expect(
          () => service.chat(config: config, prompt: '测试'),
          throwsA(isA<LlmServiceException>()
              .having((e) => e.message, 'message', contains('API 请求失败'))
              .having((e) => e.statusCode, 'statusCode', 500)),
        );
      });

      test('throws LlmServiceException on timeout', () async {
        final config = ApiConfig.defaultFor(ApiProvider.zhipu).copyWith(
          apiKey: 'test-api-key',
        );
        mockClient.shouldTimeout = true;

        expect(
          () => service.chat(config: config, prompt: '测试'),
          throwsA(isA<LlmServiceException>().having(
            (e) => e.message,
            'message',
            'API 请求超时',
          )),
        );
      });

      test('sends correct Authorization header', () async {
        final config = ApiConfig.defaultFor(ApiProvider.zhipu).copyWith(
          apiKey: 'my-secret-key',
        );
        mockClient.response = http.Response(
          '{"choices": [{"message": {"content": "response"}}]}',
          200,
        );

        await service.chat(config: config, prompt: 'test');

        expect(mockClient.lastRequestHeaders?['Authorization'], 'Bearer my-secret-key');
        expect(mockClient.lastRequestHeaders?['Content-Type'], 'application/json');
      });
    });
  });
}
