import 'dart:async';
import 'dart:convert';

import 'package:dreamtide/ai/ai_client.dart';
import 'package:dreamtide/ai/context_assembler.dart';
import 'package:dreamtide/ai/deepseek_tools.dart';
import 'package:dreamtide/application/app_controller.dart';
import 'package:dreamtide/data/local_store_base.dart';
import 'package:dreamtide/data/provider_key_store.dart';
import 'package:dreamtide/domain/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'fixtures/sample_data.dart';
import 'fixtures/fake_store.dart';

class _MemoryStore implements LocalDataStore {
  _MemoryStore(this.value);

  AppData? value;
  final savedMemo = Completer<String>();

  @override
  Future<AppData?> load() async => value;

  @override
  Future<void> clear() async => value = null;

  @override
  Future<void> save(AppData data) async {
    value = data;
    final memo = data.threads
        .where((thread) => thread.id == 'thread_gu')
        .firstOrNull
        ?.contextMemo;
    if (memo != null && memo.isNotEmpty && !savedMemo.isCompleted) {
      savedMemo.complete(memo);
    }
  }
}

class _MemoryKeyStore implements ApiKeyStore {
  @override
  Future<void> clear() async {}

  @override
  Future<String?> read({required bool persistent}) async => 'test-key';

  @override
  Future<void> write(String value, {required bool persistent}) async {}
}

void main() {
  test(
    'quiet summary is persisted after reply and injected into the next turn',
    () async {
      final initial = buildSeedData();
      final config = const ProviderConfig(
        kind: ProviderKind.openaiCompatible,
        baseUrl: 'https://memory.test/v1',
        model: 'memory-model',
      );
      final thread = initial.threads.firstWhere(
        (item) => item.id == 'thread_gu',
      );
      final start = DateTime.now().subtract(const Duration(days: 1));
      final transcript = [
        for (var index = 0; index < 16; index++)
          Message(
            id: 'history-$index',
            threadId: thread.id,
            senderId: index.isEven ? initial.owner.id : 'char_gu',
            senderName: index.isEven ? initial.owner.displayName : '顾言',
            text: '历史对话第 $index 条，约定周末去看海。',
            createdAt: start.add(Duration(minutes: index)),
            fromAi: index.isOdd,
          ),
      ];
      final data = initial.copyWith(
        settings: initial.settings.copyWith(provider: config),
        messages: transcript,
      );
      final store = _MemoryStore(data);
      final summaryRequest = Completer<void>();
      final summaryResponse = Completer<http.Response>();
      final mainRequestBodies = <Map<String, dynamic>>[];
      var mainRequests = 0;
      final client = AiClient(
        client: MockClient((request) async {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          if (body['stream'] == true) {
            mainRequests++;
            mainRequestBodies.add(body);
            final reply = mainRequests == 1 ? '我记得，我们说好周末去看海。' : '去啊，别临时又赖床。';
            return http.Response(
              'data: {"choices":[{"delta":{"content":"$reply"}}]}\n\ndata: [DONE]\n\n',
              200,
              headers: {'content-type': 'text/event-stream; charset=utf-8'},
            );
          }
          expect(body['messages'].last['content'], contains('历史对话第'));
          summaryRequest.complete();
          return summaryResponse.future;
        }),
      );
      final controller = AppController(
        store: store,
        keyStore: _MemoryKeyStore(),
        aiClient: client,
      );
      addTearDown(controller.dispose);

      for (
        var attempt = 0;
        attempt < 20 && controller.state.loading;
        attempt++
      ) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      expect(controller.state.loading, isFalse);

      await controller.sendMessage(thread.id, '你还记得我们周末的约定吗？');
      await summaryRequest.future.timeout(const Duration(seconds: 2));
      expect(controller.state.generatingThreadId, isNull);
      expect(
        controller.state.data.threads
            .firstWhere((item) => item.id == thread.id)
            .contextMemo,
        isEmpty,
      );
      summaryResponse.complete(
        http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'choices': [
                {
                  'message': {
                    'content': jsonEncode({
                      'summary': '用户与顾言约好周末一起去看海。顾言记得这是双方确认的共同计划。',
                      'facts': [
                        {
                          'type': 'promise',
                          'title': '周末看海',
                          'content': '用户与顾言约好周末一起去看海。',
                          'source_message_id': 'history-8',
                        },
                      ],
                    }),
                  },
                },
              ],
            }),
          ),
          200,
        ),
      );
      final persistedMemo = await store.savedMemo.future.timeout(
        const Duration(seconds: 2),
      );
      expect(persistedMemo, contains('周末一起去看海'));
      expect(
        controller.state.data.memories.any(
          (memory) => memory.autoGenerated && memory.title == '周末看海',
        ),
        isTrue,
      );
      expect(
        controller.state.data.threads
            .firstWhere((item) => item.id == thread.id)
            .summarizedThroughMessageId,
        'history-9',
      );
      expect(controller.state.error, isNull);

      await controller.sendMessage(thread.id, '下周我们还去吗？');
      expect(mainRequests, 2);
      final secondSystem =
          (mainRequestBodies.last['messages'] as List).firstWhere(
                (item) => item['role'] == 'system',
              )['content']
              as String;
      expect(secondSystem, contains('用户与顾言约好周末一起去看海'));

      final latestId = controller.state.data.messages
          .where((message) => message.threadId == thread.id)
          .last
          .id;
      controller.setThreadContextMemo(thread.id, '');
      final clearedThread = controller.state.data.threads.firstWhere(
        (item) => item.id == thread.id,
      );
      expect(clearedThread.contextMemo, isEmpty);
      expect(clearedThread.summarizedThroughMessageId, latestId);
    },
  );

  test(
    'a new message aborts the current stream and retains its partial turn',
    () async {
      final initial = buildSeedData();
      final config = const ProviderConfig(
        kind: ProviderKind.openaiCompatible,
        baseUrl: 'https://memory.test/v1',
        model: 'memory-model',
      );
      final data = initial.copyWith(
        settings: initial.settings.copyWith(provider: config),
      );
      final ai = _InterruptibleAi();
      final controller = AppController(
        store: _MemoryStore(data),
        keyStore: _MemoryKeyStore(),
        aiClient: ai,
        attachmentStore: MemoryAttachments()
          ..files['image-reference.jpg'] = MemoryAttachments.pixel,
      );
      addTearDown(controller.dispose);
      for (
        var attempt = 0;
        attempt < 20 && controller.state.loading;
        attempt++
      ) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      final threadId = data.threads.first.id;
      final firstTurn = controller.sendMessage(threadId, '接着说');
      await ai.firstStarted.future.timeout(const Duration(seconds: 2));

      await controller.sendMessage(threadId, '换个话题');
      await firstTurn;

      final partial = controller.state.data.messages.singleWhere(
        (message) => message.text == '我本来想说……',
      );
      expect(partial.interrupted, isTrue);
      expect(controller.state.generatingThreadId, isNull);
      expect(
        ai.requests.last.any(
          (message) =>
              message.role == 'assistant' &&
              message.content.contains('上一条回复被用户打断') &&
              message.content.contains('我本来想说……'),
        ),
        isTrue,
      );
    },
  );

  test(
    'failed turn can be retried without duplicating the user message',
    () async {
      final initial = buildSeedData();
      final data = initial.copyWith(
        settings: initial.settings.copyWith(
          provider: const ProviderConfig(
            kind: ProviderKind.openaiCompatible,
            baseUrl: 'https://memory.test/v1',
            model: 'memory-model',
          ),
        ),
      );
      final ai = _QueuedReplyAi([
        const AiClientException('模型返回了空内容'),
        '我在，刚才卡了一下。',
      ]);
      final controller = AppController(
        store: _MemoryStore(data),
        keyStore: _MemoryKeyStore(),
        aiClient: ai,
        attachmentStore: MemoryAttachments()
          ..files['image-reference.jpg'] = MemoryAttachments.pixel,
      );
      addTearDown(controller.dispose);
      for (
        var attempt = 0;
        attempt < 20 && controller.state.loading;
        attempt++
      ) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }

      final threadId = data.threads.first.id;
      final initialUsers = data.messages
          .where((message) => message.threadId == threadId && !message.fromAi)
          .length;
      final initialReplies = data.messages
          .where((message) => message.threadId == threadId && message.fromAi)
          .length;
      await controller.sendMessage(threadId, '在吗');
      expect(controller.state.error, contains('空内容'));
      expect(
        controller.state.data.messages
            .where((message) => message.threadId == threadId && !message.fromAi)
            .length,
        initialUsers + 1,
      );

      controller.clearError();
      await controller.retryLastTurn(threadId);
      final userMessages = controller.state.data.messages
          .where((message) => message.threadId == threadId && !message.fromAi)
          .toList();
      final replies = controller.state.data.messages
          .where((message) => message.threadId == threadId && message.fromAi)
          .toList();
      expect(userMessages, hasLength(initialUsers + 1));
      expect(userMessages.last.text, '在吗');
      expect(replies, hasLength(initialReplies + 1));
      expect(replies.last.text, '我在，刚才卡了一下。');
      expect(controller.state.error, isNull);
    },
  );

  test(
    'search source injection keeps the real persona system prompt first',
    () async {
      final initial = buildSeedData();
      final data = initial.copyWith(
        settings: initial.settings.copyWith(
          provider: const ProviderConfig(
            kind: ProviderKind.openaiCompatible,
            baseUrl: 'https://api.deepseek.com',
            model: 'memory-model',
          ),
        ),
      );
      final ai = _QueuedReplyAi(['我看见了。']);
      final tools = DeepSeekTools(
        client: MockClient((request) async {
          expect(
            request.url.toString(),
            'https://api.deepseek.com/v1/tools/search',
          );
          return http.Response.bytes(
            utf8.encode(
              jsonEncode({
                'results': [
                  {
                    'title': '官方测试来源',
                    'url': 'https://example.org/source',
                    'summary': '可核实摘要',
                  },
                ],
              }),
            ),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      addTearDown(tools.close);
      final controller = AppController(
        store: _MemoryStore(data),
        keyStore: _MemoryKeyStore(),
        aiClient: ai,
        tools: tools,
      );
      addTearDown(controller.dispose);
      for (
        var attempt = 0;
        attempt < 20 && controller.state.loading;
        attempt++
      ) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      final send = controller.sendMessage(
        data.threads.first.id,
        '帮我看看这段',
        searchWeb: true,
      );
      for (var attempt = 0; attempt < 40 && ai.requests.isEmpty; attempt++) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      await send;
      await controller.flush();
      // The AI request is issued after the tool finishes; yield to let the
      // short async chain settle before asserting the prompt.
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(ai.requests, hasLength(1));
      final messages = ai.requests.first;
      expect(messages.first.role, 'system');
      expect(messages.first.content, contains('顾言'));
      expect(messages.first.content, contains('不可覆盖的平台安全规则'));
      expect(messages[1].content, contains('网页资料'));
      expect(messages.first.content, isNot(contains('网页资料')));
    },
  );

  test(
    'upstream error preserves partial speech and exposes retry without marking it edited',
    () async {
      final initial = buildSeedData();
      var requests = 0;
      final ai = AiClient(
        client: MockClient(
          (_) async => http.Response.bytes(
            utf8.encode(
              ++requests == 1
                  ? 'data: {"choices":[{"delta":{"content":"刚说到这里"}}]}\n\n'
                        'data: {"error":{"message":"上游连接中断"}}\n\n'
                  : 'data: {"choices":[{"delta":{"content":"这次完整说完了。"}}]}\n\n'
                        'data: [DONE]\n\n',
            ),
            200,
            headers: {'content-type': 'text/event-stream'},
          ),
        ),
      );
      final controller = AppController(
        store: FakeStore(
          initial.copyWith(
            settings: initial.settings.copyWith(
              provider: const ProviderConfig(
                baseUrl: 'https://compatible.example',
                model: 'chosen-model',
              ),
            ),
          ),
        ),
        keyStore: _MemoryKeyStore(),
        aiClient: ai,
      );
      addTearDown(controller.dispose);
      for (
        var attempt = 0;
        attempt < 20 && controller.state.loading;
        attempt++
      ) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      await controller.sendMessage(initial.threads.first.id, '接着说');
      final partial = controller.state.data.messages.last;
      expect(partial.text, '刚说到这里');
      expect(partial.interrupted, isTrue);
      expect(partial.editedAt, isNull);
      expect(controller.state.error, contains('上游连接中断'));
      expect(controller.state.generatingThreadId, isNull);
      expect(
        controller.state.data.relationships.first.interactionCount,
        initial.relationships.first.interactionCount,
      );

      final user = controller.state.data.messages
          .where((m) => m.threadId == initial.threads.first.id && !m.fromAi)
          .last;
      await controller.retryLastTurn(initial.threads.first.id);
      await controller.flush();
      final messages = controller.state.data.messages;
      expect(messages.where((m) => m.id == user.id), hasLength(1));
      expect(messages.where((m) => m.id == partial.id), isEmpty);
      expect(messages.last.text, '这次完整说完了。');
      expect(messages.last.interrupted, isFalse);
      expect(controller.state.error, isNull);
      expect(
        controller.state.data.relationships.first.interactionCount,
        initial.relationships.first.interactionCount + 1,
      );
    },
  );

  test('regenerate replaces the latest assistant reply only', () async {
    final initial = buildSeedData();
    final data = initial.copyWith(
      settings: initial.settings.copyWith(
        provider: const ProviderConfig(
          kind: ProviderKind.openaiCompatible,
          baseUrl: 'https://memory.test/v1',
          model: 'memory-model',
        ),
      ),
    );
    final ai = _QueuedReplyAi(['旧回复', '重新想过后的新回复']);
    final controller = AppController(
      store: _MemoryStore(data),
      keyStore: _MemoryKeyStore(),
      aiClient: ai,
    );
    addTearDown(controller.dispose);
    for (var attempt = 0; attempt < 20 && controller.state.loading; attempt++) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }

    final threadId = data.threads.first.id;
    final initialUsers = data.messages
        .where((message) => message.threadId == threadId && !message.fromAi)
        .length;
    final initialReplies = data.messages
        .where((message) => message.threadId == threadId && message.fromAi)
        .length;
    await controller.sendMessage(threadId, '再说一次');
    await controller.regenerateLastReply(threadId);
    final threadMessages = controller.state.data.messages
        .where((message) => message.threadId == threadId)
        .toList();
    expect(
      threadMessages.where((message) => !message.fromAi),
      hasLength(initialUsers + 1),
    );
    expect(
      threadMessages.where((message) => !message.fromAi).last.text,
      '再说一次',
    );
    expect(
      threadMessages.where((message) => message.fromAi),
      hasLength(initialReplies + 1),
    );
    expect(
      threadMessages.where((message) => message.fromAi).last.text,
      '重新想过后的新回复',
    );
  });

  test(
    'image message persists an attachment reference and reaches the prompt',
    () async {
      final initial = buildSeedData();
      final data = initial.copyWith(
        settings: initial.settings.copyWith(
          provider: const ProviderConfig(
            kind: ProviderKind.openaiCompatible,
            baseUrl: 'https://memory.test/v1',
            model: 'vision-model',
          ),
        ),
      );
      final ai = _QueuedReplyAi(['这张图看起来很有氛围。']);
      final controller = AppController(
        store: _MemoryStore(data),
        keyStore: _MemoryKeyStore(),
        aiClient: ai,
        attachmentStore: MemoryAttachments()
          ..files['image-reference.jpg'] = MemoryAttachments.pixel,
      );
      addTearDown(controller.dispose);
      for (
        var attempt = 0;
        attempt < 20 && controller.state.loading;
        attempt++
      ) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }

      final threadId = data.threads.first.id;
      await controller.sendMessage(
        threadId,
        '像不像下雨的晚上',
        kind: MessageKind.image,
        localPath: 'image-reference.jpg',
      );
      final sent = controller.state.data.messages
          .where(
            (message) =>
                message.threadId == threadId &&
                !message.fromAi &&
                message.kind == MessageKind.image,
          )
          .last;
      expect(sent.localPath, 'image-reference.jpg');
      expect(sent.text, '像不像下雨的晚上');
      expect(ai.requests.last.last.content, contains('用户发送了一张图片'));
      expect(ai.requests.last.last.content, contains('下雨的晚上'));
    },
  );

  test(
    'completed conversations grow relationship metrics once per user turn',
    () async {
      final initial = buildSeedData();
      final relationship = initial.relationshipForThread(
        initial.threads.first,
      )!;
      final data = initial.copyWith(
        settings: initial.settings.copyWith(
          provider: const ProviderConfig(
            kind: ProviderKind.openaiCompatible,
            baseUrl: 'https://memory.test/v1',
            model: 'memory-model',
          ),
        ),
      );
      final ai = _QueuedReplyAi(['先别逞强，过来坐会儿。', '行，那今晚什么都别想，我陪你安静一会儿。']);
      final controller = AppController(
        store: _MemoryStore(data),
        keyStore: _MemoryKeyStore(),
        aiClient: ai,
        attachmentStore: MemoryAttachments()
          ..files['image-reference.jpg'] = MemoryAttachments.pixel,
      );
      addTearDown(controller.dispose);
      for (
        var attempt = 0;
        attempt < 20 && controller.state.loading;
        attempt++
      ) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }

      final threadId = data.threads.first.id;
      await controller.sendMessage(threadId, '今天工作很累，说实话有点想你。');
      final afterFirst = controller.state.data.relationships.firstWhere(
        (item) => item.id == relationship.id,
      );
      expect(afterFirst.interactionCount, relationship.interactionCount + 1);
      expect(
        afterFirst.metrics['好感']!,
        greaterThan(relationship.metrics['好感']!),
      );
      expect(
        afterFirst.metrics['信任']!,
        greaterThan(relationship.metrics['信任']!),
      );
      expect(
        afterFirst.metrics['心动']!,
        greaterThan(relationship.metrics['心动']!),
      );
      expect(afterFirst.lastMetricDelta, isNotEmpty);
      expect(afterFirst.lastMetricReason, contains('真实近况'));

      await controller.regenerateLastReply(threadId);
      final afterRegenerate = controller.state.data.relationships.firstWhere(
        (item) => item.id == relationship.id,
      );
      expect(afterRegenerate.interactionCount, afterFirst.interactionCount);
      expect(afterRegenerate.metrics, afterFirst.metrics);
      expect(afterRegenerate.lastMetricDelta, afterFirst.lastMetricDelta);
      expect(afterRegenerate.lastMetricReason, afterFirst.lastMetricReason);
      expect(ai.calls, 2);
    },
  );

  test(
    'a repeated model reply is silently rewritten before it is settled',
    () async {
      final initial = buildSeedData();
      final repeated = '你总是这样，嘴上说着不在意，其实比谁都在乎。';
      final oldReply = Message(
        id: 'old-reply',
        threadId: initial.threads.first.id,
        senderId: 'char_gu',
        senderName: '顾言',
        text: repeated,
        createdAt: DateTime.now().subtract(const Duration(minutes: 1)),
        fromAi: true,
      );
      final data = initial.copyWith(
        messages: [...initial.messages, oldReply],
        settings: initial.settings.copyWith(
          provider: const ProviderConfig(
            kind: ProviderKind.openaiCompatible,
            baseUrl: 'https://memory.test/v1',
            model: 'memory-model',
          ),
        ),
      );
      final ai = _QueuedReplyAi([repeated, '（把杯子推到你手边）行，这次不问了。先喝口水。']);
      final controller = AppController(
        store: _MemoryStore(data),
        keyStore: _MemoryKeyStore(),
        aiClient: ai,
        attachmentStore: MemoryAttachments()
          ..files['image-reference.jpg'] = MemoryAttachments.pixel,
      );
      addTearDown(controller.dispose);
      for (
        var attempt = 0;
        attempt < 20 && controller.state.loading;
        attempt++
      ) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }

      await controller.sendMessage(initial.threads.first.id, '我又没说什么。');
      expect(ai.calls, 2);
      expect(
        ai.requests.last.any(
          (message) =>
              message.role == 'system' && message.content.contains('内部重写要求'),
        ),
        isTrue,
      );
      final replies = controller.state.data.messages
          .where(
            (message) =>
                message.threadId == initial.threads.first.id && message.fromAi,
          )
          .toList();
      expect(
        replies.where((message) => message.text == repeated),
        hasLength(1),
      );
      expect(replies.last.text, contains('不问了'));
    },
  );
}

class _QueuedReplyAi extends AiClient {
  _QueuedReplyAi(this.outcomes);

  final List<Object> outcomes;
  final List<List<PromptMessage>> requests = [];
  var calls = 0;

  @override
  Future<String> streamReply({
    required ProviderConfig config,
    required String apiKey,
    required List<PromptMessage> messages,
    required void Function(String) onUpdate,
    int? maxOutputTokens,
    Future<void>? abortTrigger,
  }) async {
    requests.add(messages);
    final outcome = outcomes[calls++];
    if (outcome is Exception) throw outcome;
    final reply = outcome as String;
    onUpdate(reply);
    return reply;
  }
}

class _InterruptibleAi extends AiClient {
  final firstStarted = Completer<void>();
  final requests = <List<PromptMessage>>[];

  @override
  Future<String> streamReply({
    required ProviderConfig config,
    required String apiKey,
    required List<PromptMessage> messages,
    required void Function(String) onUpdate,
    int? maxOutputTokens,
    Future<void>? abortTrigger,
  }) async {
    requests.add(messages);
    if (requests.length == 1) {
      onUpdate('我本来想说……');
      firstStarted.complete();
      await abortTrigger;
      throw http.RequestAbortedException(Uri.parse('https://memory.test'));
    }
    return '行，那改天吧。';
  }
}
