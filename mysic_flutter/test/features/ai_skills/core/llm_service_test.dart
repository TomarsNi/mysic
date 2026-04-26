// test/features/ai_skills/core/llm_service_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mysic_flutter/features/ai_skills/core/llm_service.dart';
import 'package:mysic_flutter/features/settings/data/models/api_config.dart';

void main() {
  group('LlmService', () {
    late LlmService service;

    setUp(() {
      service = LlmService();
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
  });
}
