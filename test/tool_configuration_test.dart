import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:sillytavern_app/ai/ai_client.dart';
import 'package:sillytavern_app/ai/context_assembler.dart';
import 'package:sillytavern_app/ai/conversation_summary.dart';
import 'package:sillytavern_app/ai/deepseek_tools.dart';
import 'package:sillytavern_app/application/app_controller.dart';
import 'package:sillytavern_app/data/image_content.dart';
import 'package:sillytavern_app/domain/models.dart';
import 'package:sillytavern_app/platform/pcm_audio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'fixtures/fake_store.dart';
import 'fixtures/sample_data.dart';

const _separate = DeepSeekToolConfig(useChatKey: false);

class _Ai extends AiClient {
  final keys = <String>[];
  final prompts = <List<PromptMessage>>[];
  final started = Completer<void>();
  final summaryStarted = Completer<void>();
  Completer<void>? hold, holdSummary;
  bool aborted = false, summaryAborted = false;

  @override
  Future<String> streamReply({
    required ProviderConfig config,
    required String apiKey,
    required List<PromptMessage> messages,
    required void Function(String) onUpdate,
    int? maxOutputTokens,
    Future<void>? abortTrigger,
  }) async {
    keys.add(apiKey);
    prompts.add(messages);
    abortTrigger?.then((_) => aborted = true);
    final text = '旧书店门口那只猫还在，第 ${keys.length} 次看见了。';
    onUpdate(text);
    if (!started.isCompleted) started.complete();
    if (hold != null) await hold!.future;
    return text;
  }

  @override
  Future<ConversationMemoryUpdate> summarizeConversation({
    required ProviderConfig config,
    required String apiKey,
    required String previousSummary,
    required List<ConversationMemoryFact> previousFacts,
    required String conversationExcerpt,
    Future<void>? abortTrigger,
  }) async {
    if (!summaryStarted.isCompleted) summaryStarted.complete();
    abortTrigger?.then((_) => summaryAborted = true);
    if (holdSummary != null) await holdSummary!.future;
    return const ConversationMemoryUpdate(summary: '记住一起去过旧书店', facts: []);
  }
}

class _SlowKeys extends FakeKeyStore {
  final started = Completer<void>();
  Completer<void>? readDelay, writeDelay;

  @override
  Future<String?> read({required bool persistent}) async {
    final saved = value;
    if (readDelay != null) {
      if (!started.isCompleted) started.complete();
      await readDelay!.future;
    }
    return saved;
  }

  @override
  Future<void> write(String value, {required bool persistent}) async {
    if (writeDelay != null) {
      if (!started.isCompleted) started.complete();
      await writeDelay!.future;
    }
    await super.write(value, persistent: persistent);
  }
}

class _Hanging extends http.BaseClient {
  final started = Completer<void>();
  Future<void>? aborted;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    aborted = (request as http.Abortable).abortTrigger;
    if (!started.isCompleted) started.complete();
    await aborted;
    throw http.RequestAbortedException(request.url);
  }
}

AppData _data({
  DeepSeekToolConfig tools = _separate,
  bool official = false,
  bool longHistory = false,
}) {
  final seed = buildSeedData();
  return seed.copyWith(
    settings: seed.settings.copyWith(
      tools: tools,
      provider: ProviderConfig(
        baseUrl: official
            ? 'https://api.deepseek.com'
            : 'https://chat.example/v1',
        model: 'qa-model',
      ),
    ),
    messages: [
      if (longHistory)
        for (var i = 0; i < 16; i++)
          Message(
            id: 'history-$i',
            threadId: 'thread_gu',
            senderId: i.isEven ? 'owner' : 'char_gu',
            senderName: i.isEven ? '用户' : '顾言',
            text: '之前聊到的旅行计划 $i',
            fromAi: i.isOdd,
            createdAt: DateTime(2026, 11, 1).add(Duration(minutes: i)),
          ),
    ],
  );
}

Future<AppController> _start({
  AppData? data,
  FakeKeyStore? chatKeys,
  FakeKeyStore? toolKeys,
  DeepSeekTools? tools,
  _Ai? ai,
}) async {
  final c = AppController(
    store: FakeStore(data ?? _data()),
    keyStore: chatKeys ?? (FakeKeyStore()..value = 'fake-chat-key'),
    toolKeyStore: toolKeys ?? (FakeKeyStore()..value = 'fake-tool-key'),
    aiClient: ai ?? _Ai(),
    tools: tools,
    attachmentStore: MemoryAttachments(),
  );
  addTearDown(c.dispose);
  await Future<void>.delayed(Duration.zero);
  expect(c.state.loading, isFalse);
  return c;
}

http.Response _json(Map<String, dynamic> data) => http.Response.bytes(
  utf8.encode(jsonEncode(data)),
  200,
  headers: {'content-type': 'application/json'},
);

void main() {
  test(
    'third-party chat and all official tools use distinct keys, sources survive regeneration',
    () async {
      final paths = <String>[];
      final ai = _Ai();
      final wave = pcmToWav(Uint8List(3200));
      final c = await _start(
        ai: ai,
        tools: DeepSeekTools(
          client: MockClient((r) async {
            expect(r.url.origin, 'https://api.deepseek.com');
            expect(r.headers['Authorization'], 'Bearer fake-tool-key');
            expect(
              utf8.decode(r.bodyBytes, allowMalformed: true),
              isNot(contains('fake-chat-key')),
            );
            paths.add(r.url.path);
            return switch (r.url.path) {
              '/v1/tools/search' => _json({
                'results': [
                  {
                    'title': '资料',
                    'url': 'https://example.org/',
                    'summary': '旧书店还在营业',
                  },
                ],
              }),
              '/v1/tools/ocr' => _json({
                'pages': [
                  {'index': 0, 'text': '识别到的文字', 'finish_reason': 'stop'},
                ],
              }),
              '/v1/tools/asr' => _json({'text': '语音草稿', 'duration_ms': 100}),
              '/v1/tools/tts' => http.Response.bytes(
                wave,
                200,
                headers: {'content-type': 'audio/wav'},
              ),
              _ => throw StateError('Unexpected tool'),
            };
          }),
        ),
      );
      await c.sendMessage('thread_gu', '搜索旧书店', searchWeb: true);
      expect(ai.keys, ['fake-chat-key']);
      expect(
        ai.prompts.single.map((e) => e.content).join(),
        contains('https://example.org/'),
      );
      expect(c.state.data.messages.last.sources, hasLength(1));
      await c.regenerateLastReply('thread_gu');
      expect(ai.keys, ['fake-chat-key', 'fake-chat-key']);
      expect(
        (await c.recognizeImage(
          ImageContent(MemoryAttachments.pixel, 'image/png'),
        )).text,
        '识别到的文字',
      );
      expect(await c.transcribeAudio(wave), '语音草稿');
      expect(await c.synthesizeSpeech('你好'), wave);
      expect(paths, [
        '/v1/tools/search',
        '/v1/tools/search',
        '/v1/tools/ocr',
        '/v1/tools/asr',
        '/v1/tools/tts',
      ]);
      final backup = await c.exportPortableBackup();
      expect(backup, isNot(contains('fake-chat-key')));
      expect(backup, isNot(contains('fake-tool-key')));
    },
  );

  test(
    'missing independent key never falls back to chat key and chat keeps working',
    () async {
      var requests = 0;
      final ai = _Ai();
      final c = await _start(
        ai: ai,
        toolKeys: FakeKeyStore(),
        tools: DeepSeekTools(
          client: MockClient((_) async {
            requests++;
            return _json({});
          }),
        ),
      );
      await expectLater(
        c.synthesizeSpeech('你好'),
        throwsA(isA<AiClientException>()),
      );
      expect(requests, 0);
      await c.sendMessage('thread_gu', '你好');
      expect(ai.keys.single, 'fake-chat-key');
    },
  );

  test('reuse mode only accepts an official chat provider', () async {
    var requests = 0;
    final c = await _start(
      data: _data(tools: const DeepSeekToolConfig()),
      tools: DeepSeekTools(
        client: MockClient((_) async {
          requests++;
          return _json({});
        }),
      ),
    );
    await expectLater(
      c.synthesizeSpeech('你好'),
      throwsA(isA<AiClientException>()),
    );
    await expectLater(
      c.saveToolConfig(config: const DeepSeekToolConfig()),
      throwsA(isA<AiClientException>()),
    );
    expect(requests, 0);
  });

  test(
    'reuse mode sends official chat key and discards an independent key',
    () async {
      final toolKeys = FakeKeyStore()..value = 'old-tool-key';
      final c = await _start(
        data: _data(official: true),
        toolKeys: toolKeys,
        tools: DeepSeekTools(
          client: MockClient((r) async {
            expect(r.headers['Authorization'], 'Bearer fake-chat-key');
            return _json({'text': '官方复用成功'});
          }),
        ),
      );
      await c.saveToolConfig(config: const DeepSeekToolConfig());
      expect(toolKeys.value, isNull);
      expect(c.state.hasToolApiKey, isFalse);
      expect(await c.transcribeAudio(pcmToWav(Uint8List(3200))), '官方复用成功');
    },
  );

  for (final change in ['clear', 'save', 'reset']) {
    test('$change tools aborts pending media requests', () async {
      final client = _Hanging();
      final c = await _start(tools: DeepSeekTools(client: client));
      final request = c.synthesizeSpeech('你好');
      final checked = expectLater(request, throwsA(isA<AiClientException>()));
      await client.started.future;
      if (change == 'clear') await c.clearToolKey();
      if (change == 'save') {
        await c.saveToolConfig(config: _separate, apiKey: 'new-tool-key');
      }
      if (change == 'reset') await c.resetData();
      await checked;
      await client.aborted;
    });
  }

  test('changing chat provider does not cancel independent speech', () async {
    final release = Completer<http.Response>(), started = Completer<void>();
    final c = await _start(
      tools: DeepSeekTools(
        client: MockClient((_) async {
          if (!started.isCompleted) started.complete();
          return release.future;
        }),
      ),
    );
    final request = c.transcribeAudio(pcmToWav(Uint8List(3200)));
    await started.future;
    await c.saveProvider(
      config: const ProviderConfig(
        baseUrl: 'https://other.example',
        model: 'qa',
      ),
      apiKey: 'other-chat-key',
    );
    release.complete(_json({'text': '仍然有效的草稿'}));
    expect(await request, '仍然有效的草稿');
  });

  test('clearing tool key preserves ordinary streaming reply', () async {
    final ai = _Ai()..hold = Completer<void>();
    final c = await _start(ai: ai);
    final request = c.sendMessage('thread_gu', '今天那只猫呢');
    await ai.started.future;
    await c.clearToolKey();
    expect(ai.aborted, isFalse);
    expect(c.state.generatingThreadId, 'thread_gu');
    ai.hold!.complete();
    await request;
    expect(c.state.error, isNull);
    expect(c.state.data.messages.last.interrupted, isFalse);
  });

  test(
    'clearing tools leaves quiet chat memory running and persisting',
    () async {
      final ai = _Ai()..holdSummary = Completer<void>();
      final c = await _start(ai: ai, data: _data(longHistory: true));
      await c.sendMessage('thread_gu', '后来呢');
      await ai.summaryStarted.future.timeout(const Duration(seconds: 2));
      await c.clearToolKey();
      expect(ai.summaryAborted, isFalse);
      ai.holdSummary!.complete();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(
        c.state.data.threads.firstWhere((e) => e.id == 'thread_gu').contextMemo,
        '记住一起去过旧书店',
      );
    },
  );

  test(
    'changing tools stops search without invoking main model or growing relationship',
    () async {
      final client = _Hanging();
      final ai = _Ai();
      final c = await _start(
        ai: ai,
        tools: DeepSeekTools(client: client),
      );
      final before = c.state.data.relationships.first;
      final request = c.sendMessage('thread_gu', '搜索', searchWeb: true);
      await client.started.future;
      await c.clearToolKey();
      await request;
      expect(ai.keys, isEmpty);
      expect(c.state.generatingThreadId, isNull);
      expect(c.state.data.messages.where((m) => m.fromAi), isEmpty);
      final after = c.state.data.relationships.first;
      expect(after.lastInteractionAt, before.lastInteractionAt);
    },
  );

  test(
    'cleared credentials cannot revive a tool waiting for secure storage',
    () async {
      final keys = _SlowKeys()..value = 'old-tool-key';
      var calls = 0;
      final c = await _start(
        toolKeys: keys,
        tools: DeepSeekTools(
          client: MockClient((_) async {
            calls++;
            return _json({});
          }),
        ),
      );
      keys.readDelay = Completer<void>();
      final request = c.synthesizeSpeech('你好');
      final check = expectLater(request, throwsA(isA<AiClientException>()));
      await keys.started.future;
      await c.clearToolKey();
      keys.readDelay!.complete();
      await check;
      expect(calls, 0);
    },
  );

  for (final change in ['clear', 'reset']) {
    test('late tool save cannot undo $change', () async {
      final keys = _SlowKeys()..value = 'old-tool-key';
      final c = await _start(toolKeys: keys);
      keys.writeDelay = Completer<void>();
      final save = c.saveToolConfig(config: _separate, apiKey: 'new-tool-key');
      final check = expectLater(save, throwsA(isA<AiClientException>()));
      await keys.started.future;
      final clear = change == 'clear' ? c.clearToolKey() : c.resetData();
      keys.writeDelay!.complete();
      await check;
      await clear;
      expect(keys.value, isNull);
      expect(c.state.hasToolApiKey, isFalse);
      if (change == 'reset') expect(c.state.data.characters, isEmpty);
    });
  }

  test(
    'restore with changed chat retains independent key, changed tool mode clears it, reset clears both',
    () async {
      final chat = FakeKeyStore()..value = 'fake-chat-key';
      final tools = FakeKeyStore()..value = 'fake-tool-key';
      final c = await _start(chatKeys: chat, toolKeys: tools);
      final changed = c.state.data.copyWith(
        settings: c.state.data.settings.copyWith(
          provider: const ProviderConfig(
            baseUrl: 'https://restored.example',
            model: 'qa',
          ),
        ),
      );
      await c.importBackup(changed.encode());
      expect(chat.value, isNull);
      expect(tools.value, 'fake-tool-key');
      expect(c.state.hasToolApiKey, isTrue);
      await c.importBackup(
        changed
            .copyWith(
              settings: changed.settings.copyWith(
                tools: const DeepSeekToolConfig(),
              ),
            )
            .encode(),
      );
      expect(tools.value, isNull);
      await c.saveToolConfig(config: _separate, apiKey: 'again-tool-key');
      await c.resetData();
      expect(chat.value, isNull);
      expect(tools.value, isNull);
      expect(c.state.hasToolApiKey, isFalse);
      expect(c.state.hasApiKey, isFalse);
      expect(c.state.data.settings.tools.useChatKey, isTrue);
    },
  );

  test(
    'old backups default to official-chat reuse without embedding credentials',
    () {
      final data = _data().toJson();
      (data['settings'] as Map).remove('tools');
      final restored = AppData.fromJson(data);
      expect(restored.settings.tools.useChatKey, isTrue);
      expect(restored.settings.tools.rememberKey, isFalse);
    },
  );
}
