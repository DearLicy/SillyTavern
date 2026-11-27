import 'dart:async';
import 'dart:convert';

import 'package:sillytavern_app/ai/ai_client.dart';
import 'package:sillytavern_app/ai/context_assembler.dart';
import 'package:sillytavern_app/domain/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const config = ProviderConfig(
  baseUrl: 'https://compatible.example/v1',
  model: 'provider-selected-model',
);
const messages = [PromptMessage('user', '你好')];
http.Response jsonResponse(Object value) => http.Response.bytes(
  utf8.encode(jsonEncode(value)),
  200,
  headers: {'content-type': 'application/json'},
);
http.Response sse(String body) => http.Response.bytes(
  utf8.encode(body),
  200,
  headers: {'content-type': 'text/event-stream'},
);
Map<String, Object> completion(String text) => {
  'choices': [
    {
      'message': {'content': text},
      'finish_reason': 'stop',
    },
  ],
};
Future<String> reply(
  AiClient ai, {
  void Function(String)? onUpdate,
  Future<void>? abort,
}) => ai.streamReply(
  config: config,
  apiKey: 'test-compatible-key',
  messages: messages,
  onUpdate: onUpdate ?? (_) {},
  abortTrigger: abort,
);

void main() {
  test('relay heartbeats and null metadata preserve visible content', () async {
    final ai = AiClient(
      client: MockClient(
        (_) async => sse(
          ': heartbeat\n\n'
          'data: {"choices":[{"delta":{"content":"","extra_fields":null,"function_call":null,"refusal":"","role":"assistant"},"finish_reason":null}],"usage":null}\n\n'
          'data: {"choices":[{"delta":{"content":"收到","extra_fields":null,"function_call":null,"refusal":""},"finish_reason":null}],"usage":null}\n\n'
          'data: {"choices":[{"delta":{"content":"","role":"assistant"},"finish_reason":"stop"}],"usage":{"completion_tokens":2}}\n\n'
          'data: [DONE]\n\n',
        ),
      ),
    );
    addTearDown(ai.close);
    final updates = <String>[];
    expect(await reply(ai, onUpdate: updates.add), '收到');
    expect(updates, ['收到']);
  });

  for (final address in [
    'https://compatible.example',
    'https://compatible.example/v1',
    'https://compatible.example/v1/chat/completions',
  ]) {
    test(
      'custom provider URL $address keeps the requested host and model',
      () async {
        final ai = AiClient(
          client: MockClient((request) async {
            expect(
              request.url.toString(),
              'https://compatible.example/v1/chat/completions',
            );
            final body = jsonDecode(request.body);
            expect(body['model'], 'provider-selected-model');
            return jsonResponse(completion('收到'));
          }),
        );
        addTearDown(ai.close);
        expect(
          await ai.streamReply(
            config: config.copyWith(baseUrl: address),
            apiKey: 'test-key',
            messages: messages,
            onUpdate: (_) {},
          ),
          '收到',
        );
      },
    );
  }

  test(
    'configured generation parameters reach OpenAI-compatible requests',
    () async {
      Map<String, dynamic>? body;
      final ai = AiClient(
        client: MockClient((request) async {
          body = jsonDecode(request.body) as Map<String, dynamic>;
          return jsonResponse(completion('参数已生效'));
        }),
      );
      addTearDown(ai.close);
      final tuned = config.copyWith(
        temperature: 0.4,
        topP: 0.75,
        frequencyPenalty: 0.3,
        presencePenalty: -0.2,
        maxOutputTokens: 321,
        stopSequences: const ['END', '---'],
      );
      expect(
        await ai.streamReply(
          config: tuned,
          apiKey: 'test-key',
          messages: messages,
          onUpdate: (_) {},
        ),
        '参数已生效',
      );
      expect(body?['temperature'], 0.4);
      expect(body?['top_p'], 0.75);
      expect(body?['frequency_penalty'], 0.3);
      expect(body?['presence_penalty'], -0.2);
      expect(body?['max_tokens'], 321);
      expect(body?['stop'], ['END', '---']);
    },
  );

  test(
    'empty stream retries once as non-streaming on the same provider',
    () async {
      final bodies = <Map<String, dynamic>>[];
      final ai = AiClient(
        client: MockClient((request) async {
          expect(
            request.url.toString(),
            'https://compatible.example/v1/chat/completions',
          );
          expect(
            request.headers['Authorization'],
            'Bearer test-compatible-key',
          );
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          bodies.add(body);
          return body['stream'] == true
              ? sse(
                  'data: {"choices":[{"delta":{},"finish_reason":"stop"}]}\n\ndata: [DONE]\n\n',
                )
              : jsonResponse(completion('第三方正常回复'));
        }),
      );
      addTearDown(ai.close);
      final updates = <String>[];
      expect(await reply(ai, onUpdate: updates.add), '第三方正常回复');
      expect(bodies.map((b) => b['stream']), [true, false]);
      expect(bodies.every((b) => !b.containsKey('max_tokens')), isTrue);
      expect(bodies.last['messages'], bodies.first['messages']);
      expect(bodies.last['model'], config.model);
      expect(updates, ['第三方正常回复']);
    },
  );

  test(
    'HTTP 200 error envelopes retain safe actual errors and never retry',
    () async {
      for (final body in [
        {
          'error': {
            'message': 'upstream busy Bearer test-compatible-key',
            'code': 'upstream_error',
          },
        },
        {
          'code': 'MODEL_UNAVAILABLE',
          'message': 'model offline test-compatible-key',
        },
        {'success': false, 'message': 'upstream unavailable'},
      ]) {
        var calls = 0;
        final ai = AiClient(
          client: MockClient((_) async {
            calls++;
            return jsonResponse(body);
          }),
        );
        try {
          await expectLater(
            reply(ai),
            throwsA(
              isA<AiClientException>().having(
                (e) => e.message,
                'safe upstream detail',
                allOf(
                  isNot(contains('空内容')),
                  isNot(contains('test-compatible-key')),
                ),
              ),
            ),
          );
          expect(calls, 1);
        } finally {
          ai.close();
        }
      }
    },
  );

  test('SSE errors are not swallowed as empty replies', () async {
    var calls = 0;
    final ai = AiClient(
      client: MockClient((_) async {
        calls++;
        return sse(
          'event: error\ndata: {"error":{"message":"模型暂时离线","code":"upstream_error"}}\n\n',
        );
      }),
    );
    addTearDown(ai.close);
    await expectLater(
      reply(ai),
      throwsA(
        isA<AiClientException>().having(
          (e) => e.message,
          'detail',
          contains('模型暂时离线'),
        ),
      ),
    );
    expect(calls, 1);
  });

  test('empty delta does not mask a full message in the same frame', () async {
    final ai = AiClient(
      client: MockClient(
        (_) async => sse(
          'data: {"choices":[{"delta":{"content":""},"message":{"content":"完整正文"}}]}\n\ndata: [DONE]\n\n',
        ),
      ),
    );
    addTearDown(ai.close);
    expect(await reply(ai), '完整正文');
  });

  test(
    'text blocks accept output_text and text.value without leaking reasoning',
    () async {
      final ai = AiClient(
        client: MockClient(
          (_) async => jsonResponse({
            'choices': [
              {
                'message': {
                  'content': [
                    {'type': 'reasoning', 'text': '隐藏推理'},
                    {
                      'type': 'text',
                      'text': {'value': '你好'},
                    },
                    {'type': 'output_text', 'text': '，收到。'},
                  ],
                },
              },
            ],
          }),
        ),
      );
      addTearDown(ai.close);
      expect(await reply(ai), '你好，收到。');
    },
  );

  test('multiline SSE, BOM, CRLF and fragmented UTF8 parse correctly', () async {
    final body =
        '\uFEFF: keepalive\r\nevent: message\r\ndata: {"choices": [\r\ndata: {"delta": {"content": "多行正文"}}]}\r\n\r\ndata: [DONE]\r\n\r\n';
    final ai = AiClient(
      client: MockClient.streaming(
        (request, bytes) async => http.StreamedResponse(
          Stream.fromIterable(utf8.encode(body).map((b) => [b])),
          200,
          headers: {'content-type': 'text/event-stream'},
        ),
      ),
    );
    addTearDown(ai.close);
    expect(await reply(ai), '多行正文');
  });

  test('final message snapshot does not duplicate streamed text', () async {
    final ai = AiClient(
      client: MockClient(
        (_) async => sse(
          'data: {"choices":[{"delta":{"content":"你好"}}]}\n\n'
          'data: {"choices":[{"message":{"content":"你好，收到。"},"finish_reason":"stop"}]}\n\n'
          'data: [DONE]\n\n',
        ),
      ),
    );
    addTearDown(ai.close);
    expect(await reply(ai), '你好，收到。');
  });

  test(
    'double empty result is bounded and reasoning is never used as speech',
    () async {
      var calls = 0;
      final ai = AiClient(
        client: MockClient((_) async {
          calls++;
          return jsonResponse({
            'choices': [
              {
                'message': {'content': '', 'reasoning_content': '内部推理'},
              },
            ],
          });
        }),
      );
      addTearDown(ai.close);
      final updates = <String>[];
      await expectLater(
        reply(ai, onUpdate: updates.add),
        throwsA(isA<AiClientException>()),
      );
      expect(calls, 2);
      expect(updates, isEmpty);
    },
  );

  test('DONE-only stream also gets one compatibility fallback', () async {
    var calls = 0;
    final ai = AiClient(
      client: MockClient((_) async {
        calls++;
        return calls == 1
            ? sse('data: [DONE]\n\n')
            : jsonResponse(completion('收到'));
      }),
    );
    addTearDown(ai.close);
    expect(await reply(ai), '收到');
    expect(calls, 2);
  });

  test(
    'cancelled empty stream does not start a paid fallback request',
    () async {
      final abort = Completer<void>();
      var calls = 0;
      final ai = AiClient(
        client: MockClient((_) async {
          calls++;
          abort.complete();
          return sse('data: {"choices":[]}\n\ndata: [DONE]\n\n');
        }),
      );
      addTearDown(ai.close);
      await expectLater(
        reply(ai, abort: abort.future),
        throwsA(isA<http.RequestAbortedException>()),
      );
      expect(calls, 1);
    },
  );

  test(
    'fallback retains the same abort trigger for actual network cancellation',
    () async {
      final client = _FallbackCancellationClient();
      final ai = AiClient(client: client);
      addTearDown(ai.close);
      final abort = Completer<void>();
      final pending = reply(ai, abort: abort.future);
      final check = expectLater(
        pending,
        throwsA(isA<http.RequestAbortedException>()),
      );
      await client.started.future.timeout(const Duration(seconds: 2));
      abort.complete();
      await check;
      expect(client.calls, 2);
    },
  );

  test(
    'usage-only frames do not erase text and DONE closes the response',
    () async {
      var cancelled = false;
      late StreamController<List<int>> stream;
      stream = StreamController<List<int>>(
        onCancel: () {
          cancelled = true;
        },
      );
      final ai = AiClient(
        client: MockClient.streaming((_, bytes) async {
          stream.add(
            utf8.encode(
              'data: {"choices":[{"delta":{"content":"收到"}}]}\n\n'
              'data: {"choices":[],"usage":{"total_tokens":5}}\n\ndata: [DONE]\n\n',
            ),
          );
          return http.StreamedResponse(
            stream.stream,
            200,
            headers: {'content-type': 'text/event-stream'},
          );
        }),
      );
      addTearDown(ai.close);
      addTearDown(() => stream.close());
      expect(await reply(ai).timeout(const Duration(seconds: 2)), '收到');
      expect(cancelled, isTrue);
    },
  );

  test('pretty JSON mislabeled as a stream is accepted', () async {
    final ai = AiClient(
      client: MockClient(
        (_) async =>
            sse(const JsonEncoder.withIndent('  ').convert(completion('完整正文'))),
      ),
    );
    addTearDown(ai.close);
    expect(await reply(ai), '完整正文');
  });

  test(
    'partial reply followed by provider error propagates, without retry',
    () async {
      var calls = 0;
      final ai = AiClient(
        client: MockClient((_) async {
          calls++;
          return sse(
            'data: {"choices":[{"delta":{"content":"说到一半"}}]}\n\n'
            'event: error\ndata: {"message":"上游中断"}\n\n',
          );
        }),
      );
      addTearDown(ai.close);
      final updates = <String>[];
      await expectLater(
        reply(ai, onUpdate: updates.add),
        throwsA(
          isA<AiClientException>().having(
            (e) => e.message,
            'detail',
            contains('上游中断'),
          ),
        ),
      );
      expect(updates, ['说到一半']);
      expect(calls, 1);
    },
  );

  test('UI callback errors are not silently discarded', () async {
    final ai = AiClient(
      client: MockClient(
        (_) async => sse(
          'data: {"choices":[{"delta":{"content":"收到"}}]}\n\ndata: [DONE]\n\n',
        ),
      ),
    );
    addTearDown(ai.close);
    await expectLater(
      reply(ai, onUpdate: (_) => throw StateError('callback')),
      throwsStateError,
    );
  });

  for (final reason in ['content_filter', 'tool_calls']) {
    test(
      'explicit $reason finish does not trigger automatic re-request',
      () async {
        var calls = 0;
        final ai = AiClient(
          client: MockClient((_) async {
            calls++;
            return jsonResponse({
              'choices': [
                {
                  'message': {'content': ''},
                  'finish_reason': reason,
                },
              ],
            });
          }),
        );
        addTearDown(ai.close);
        await expectLater(reply(ai), throwsA(isA<AiClientException>()));
        expect(calls, 1);
      },
    );
  }

  test(
    'HTTP auth failures never start fallback or expose exact supplied key',
    () async {
      var calls = 0;
      final ai = AiClient(
        client: MockClient((_) async {
          calls++;
          return http.Response(
            '{"error":{"message":"bad test-compatible-key"}}',
            401,
          );
        }),
      );
      addTearDown(ai.close);
      await expectLater(
        reply(ai),
        throwsA(
          isA<AiClientException>().having(
            (e) => e.message,
            'safe message',
            allOf(contains('401'), isNot(contains('test-compatible-key'))),
          ),
        ),
      );
      expect(calls, 1);
    },
  );
}

class _FallbackCancellationClient extends http.BaseClient {
  final started = Completer<void>();
  var calls = 0;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    calls++;
    if (calls == 1) {
      return http.StreamedResponse(
        Stream.value(utf8.encode('data: [DONE]\n\n')),
        200,
        headers: {'content-type': 'text/event-stream'},
      );
    }
    final abort = (request as http.Abortable).abortTrigger;
    expect(abort, isNotNull);
    started.complete();
    await abort;
    throw http.RequestAbortedException(request.url);
  }
}
