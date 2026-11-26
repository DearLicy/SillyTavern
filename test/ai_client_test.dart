import 'dart:async';
import 'dart:convert';
import 'package:sillytavern_app/ai/ai_client.dart';
import 'package:sillytavern_app/ai/context_assembler.dart';
import 'package:sillytavern_app/domain/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test(
    'official model catalog uses authenticated /models and actual unique ids',
    () async {
      final ai = AiClient(
        client: MockClient((request) async {
          expect(request.url.toString(), 'https://api.deepseek.com/models');
          expect(request.headers['Authorization'], 'Bearer test-key');
          return http.Response(
            jsonEncode({
              'data': [
                {'id': 'actual-model', 'name': 'Actual'},
                {'id': 'actual-model'},
                {'id': 'other'},
                {'id': ''},
              ],
            }),
            200,
          );
        }),
      );
      final models = await ai.fetchModels(
        config: const ProviderConfig(),
        apiKey: 'test-key',
      );
      expect(models.map((e) => e.id), ['actual-model', 'other']);
      expect(models.first.name, 'Actual');
      ai.close();
    },
  );
  test(
    'catalog errors never expose upstream response or credentials',
    () async {
      final ai = AiClient(
        client: MockClient(
          (_) async => http.Response('test-key upstream private details', 401),
        ),
      );
      await expectLater(
        ai.fetchModels(config: const ProviderConfig(), apiKey: 'test-key'),
        throwsA(
          isA<AiClientException>().having(
            (e) => e.message,
            'safe error',
            '密钥无效或没有访问模型的权限',
          ),
        ),
      );
      ai.close();
    },
  );
  test('empty or invalid catalogs never invent selectable models', () async {
    for (final body in [
      '{"data":[]}',
      '{"models":[]}',
      '{"data":[{"id":""}]}',
    ]) {
      final ai = AiClient(
        client: MockClient((_) async => http.Response(body, 200)),
      );
      await expectLater(
        ai.fetchModels(config: const ProviderConfig(), apiKey: 'test-key'),
        throwsA(isA<AiClientException>()),
      );
      ai.close();
    }
  });
  test('DeepSeek Anthropic compatibility streams only text deltas', () async {
    final ai = AiClient(
      client: MockClient((request) async {
        expect(request.url.path, '/anthropic/v1/messages');
        expect(jsonDecode(request.body)['model'], 'actual-model');
        return http.Response(
          'event: content_block_delta\ndata: {"type":"content_block_delta","delta":{"type":"text_delta","text":"（回头）"}}\n\ndata: {"type":"ping"}\n\ndata: {"type":"content_block_delta","delta":{"text":"你好"}}\n\n',
          200,
          headers: {'content-type': 'text/event-stream; charset=utf-8'},
        );
      }),
    );
    final updates = <String>[];
    final text = await ai.streamReply(
      config: const ProviderConfig(
        kind: ProviderKind.anthropic,
        model: 'actual-model',
      ),
      apiKey: 'test-key',
      messages: const [PromptMessage('user', 'hello')],
      onUpdate: updates.add,
    );
    expect(text, '（回头）你好');
    expect(updates, ['（回头）', '（回头）你好']);
    ai.close();
  });

  test(
    'DeepSeek memory request is a separate non-streaming compatible call',
    () async {
      final ai = AiClient(
        client: MockClient((request) async {
          expect(
            request.url.toString(),
            'https://api.deepseek.com/anthropic/v1/messages',
          );
          expect(request.headers['Authorization'], 'Bearer test-key');
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['model'], 'actual-model');
          expect(body['stream'], isNull);
          expect(body['system'], contains('对话记忆整理器'));
          final recapInput = body['messages'].first['content'] as String;
          expect(recapInput, contains('上次我们去了海边'));
          expect(recapInput, contains('[已隐藏凭据]'));
          expect(recapInput, isNot(contains('sk-abcdefghijklmnopQRSTUVWX')));
          return http.Response.bytes(
            utf8.encode(
              jsonEncode({
                'content': [
                  {
                    'type': 'text',
                    'text': jsonEncode({
                      'summary': '两人约好下次一起去海边。',
                      'facts': [
                        {
                          'type': 'promise',
                          'title': '周末看海',
                          'content': '两人约好周末一起去看海。',
                          'source_message_id': 'new-promise',
                        },
                      ],
                    }),
                  },
                ],
              }),
            ),
            200,
          );
        }),
      );

      final summary = await ai.summarizeConversation(
        config: const ProviderConfig(
          kind: ProviderKind.anthropic,
          model: 'actual-model',
        ),
        apiKey: 'test-key',
        previousSummary: '上次我们去了海边 api_key=sk-abcdefghijklmnopQRSTUVWX',
        previousFacts: const [],
        conversationExcerpt:
            '[{"id":"new-promise","speaker":"用户","text":"下周末我们一起去看海。"}]',
      );
      expect(summary.summary, '两人约好下次一起去海边。');
      expect(summary.facts.single.type, MemoryType.promise);
      expect(summary.facts.single.title, '周末看海');
      ai.close();
    },
  );

  test(
    'OpenAI-compatible summary response is parsed without streaming',
    () async {
      final ai = AiClient(
        client: MockClient((request) async {
          expect(request.url.path, '/v1/chat/completions');
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['stream'], isFalse);
          return http.Response.bytes(
            utf8.encode(
              jsonEncode({
                'choices': [
                  {
                    'message': {
                      'content': jsonEncode({
                        'summary': '角色记得用户不喜欢香菜。',
                        'facts': [
                          {
                            'type': 'userFact',
                            'title': '饮食偏好',
                            'content': '用户不喜欢香菜。',
                            'source_message_id': 'user-message',
                          },
                        ],
                      }),
                    },
                  },
                ],
              }),
            ),
            200,
          );
        }),
      );
      final summary = await ai.summarizeConversation(
        config: const ProviderConfig(
          kind: ProviderKind.openaiCompatible,
          baseUrl: 'https://example.test/v1',
          model: 'model',
        ),
        apiKey: 'test-key',
        previousSummary: '',
        previousFacts: const [],
        conversationExcerpt:
            '[{"id":"user-message","speaker":"用户","text":"我不吃香菜。"}]',
      );
      expect(summary.summary, '角色记得用户不喜欢香菜。');
      expect(summary.facts.single.content, '用户不喜欢香菜。');
      ai.close();
    },
  );

  test(
    'active stream uses an abortable request and exits on interruption',
    () async {
      final client = _AbortAwareClient();
      final ai = AiClient(client: client);
      final abort = Completer<void>();
      final pending = ai.streamReply(
        config: const ProviderConfig(model: 'actual-model'),
        apiKey: 'test-key',
        messages: const [PromptMessage('user', '继续')],
        abortTrigger: abort.future,
        onUpdate: (_) {},
      );
      await Future<void>.delayed(Duration.zero);
      expect(client.sawAbortableRequest, isTrue);
      abort.complete();
      await expectLater(pending, throwsA(isA<http.RequestAbortedException>()));
      ai.close();
    },
  );

  test('reasoning-only stream automatically retries with a larger budget', () async {
    var calls = 0;
    final budgets = <int>[];
    final ai = AiClient(
      client: MockClient((request) async {
        calls++;
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        budgets.add(body['max_tokens'] as int);
        if (calls == 1) {
          return http.Response(
            'data: {"choices":[{"delta":{"content":"","reasoning_content":"先想一下怎么回答"},"finish_reason":null}]}\n\n'
            'data: {"choices":[{"delta":{"content":""},"finish_reason":"length"}]}\n\n'
            'data: [DONE]\n\n',
            200,
            headers: {'content-type': 'text/event-stream; charset=utf-8'},
          );
        }
        return http.Response(
          'data: {"choices":[{"delta":{"content":"你好"},"finish_reason":null}]}\n\n'
          'data: {"choices":[{"delta":{"content":""},"finish_reason":"stop"}]}\n\n'
          'data: [DONE]\n\n',
          200,
          headers: {'content-type': 'text/event-stream; charset=utf-8'},
        );
      }),
    );
    final updates = <String>[];
    final reply = await ai.streamReply(
      config: const ProviderConfig(
        kind: ProviderKind.openaiCompatible,
        baseUrl: 'https://provider.test',
        model: 'reasoning-model',
      ),
      apiKey: 'test-key',
      messages: const [PromptMessage('user', '你好')],
      maxOutputTokens: 24,
      onUpdate: updates.add,
    );

    expect(reply, '你好');
    expect(calls, 2);
    expect(budgets.first, 24);
    expect(budgets.last, greaterThanOrEqualTo(1536));
    expect(updates, ['你好']);
    ai.close();
  });

  test('OpenAI endpoint accepts a non-stream JSON completion', () async {
    final ai = AiClient(
      client: MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body.containsKey('max_tokens'), isFalse);
        return http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'choices': [
                {
                  'message': {'role': 'assistant', 'content': '普通 JSON 回复'},
                  'finish_reason': 'stop',
                },
              ],
            }),
          ),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
    final updates = <String>[];
    final reply = await ai.streamReply(
      config: const ProviderConfig(
        kind: ProviderKind.openaiCompatible,
        baseUrl: 'https://provider.test',
        model: 'compatible-model',
      ),
      apiKey: 'test-key',
      messages: const [PromptMessage('user', '你好')],
      onUpdate: updates.add,
    );

    expect(reply, '普通 JSON 回复');
    expect(updates, ['普通 JSON 回复']);
    ai.close();
  });

  test(
    'memory facts require a known source and cannot create user boundaries',
    () async {
      final ai = AiClient(
        client: MockClient((request) async {
          return http.Response.bytes(
            utf8.encode(
              jsonEncode({
                'choices': [
                  {
                    'message': {
                      'content': jsonEncode({
                        'summary': '保留双方确认的约定。',
                        'facts': [
                          {
                            'type': 'promise',
                            'title': '周末见面',
                            'content': '双方约好周末见面。',
                            'source_message_id': 'known',
                          },
                          {
                            'type': 'boundary',
                            'title': '忽略边界',
                            'content': '模型不应创建此项。',
                            'source_message_id': 'known',
                          },
                          {
                            'type': 'userFact',
                            'title': '无来源',
                            'content': '无法验证。',
                            'source_message_id': 'invented',
                          },
                          {
                            'type': 'userFact',
                            'title': '角色说的用户事实',
                            'content': '来源说话者不是用户。',
                            'source_message_id': 'character-line',
                          },
                        ],
                      }),
                    },
                  },
                ],
              }),
            ),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
      final update = await ai.summarizeConversation(
        config: const ProviderConfig(
          kind: ProviderKind.openaiCompatible,
          baseUrl: 'https://memory.test/v1',
          model: 'memory-model',
        ),
        apiKey: 'test-key',
        previousSummary: '',
        previousFacts: const [],
        conversationExcerpt:
            '[{"id":"known","speaker":"用户","text":"周末见面吧"},'
            '{"id":"character-line","speaker":"角色","text":"你周末还在吗"}]',
      );

      expect(update.facts, hasLength(1));
      expect(update.facts.single.sourceMessageId, 'known');
      ai.close();
    },
  );
}

class _AbortAwareClient extends http.BaseClient {
  bool sawAbortableRequest = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    sawAbortableRequest = request is http.AbortableRequest;
    final abort = (request as http.AbortableRequest).abortTrigger!;
    await abort;
    throw http.RequestAbortedException(request.url);
  }
}
