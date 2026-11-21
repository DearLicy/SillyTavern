import 'dart:async';
import 'dart:convert';

import 'package:dreamtide/ai/ai_client.dart';
import 'package:dreamtide/ai/context_assembler.dart';
import 'package:dreamtide/ai/conversation_summary.dart';
import 'package:dreamtide/application/app_controller.dart';
import 'package:dreamtide/domain/models.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures/fake_store.dart';
import 'fixtures/sample_data.dart';

class _ProviderAi extends AiClient {
  final catalogs = <(ProviderConfig, String)>[];
  final started = Completer<void>();
  final aborted = Completer<void>();

  @override
  Future<List<ProviderModel>> fetchModels({
    required ProviderConfig config,
    required String apiKey,
  }) async {
    catalogs.add((config, apiKey));
    return const [ProviderModel(id: 'model-a', name: 'Model A')];
  }

  @override
  Future<String> streamReply({
    required ProviderConfig config,
    required String apiKey,
    required List<PromptMessage> messages,
    required void Function(String) onUpdate,
    int? maxOutputTokens,
    Future<void>? abortTrigger,
  }) async {
    onUpdate('说到一半');
    started.complete();
    await abortTrigger;
    aborted.complete();
    throw const AiClientException('cancelled');
  }
}

class _SlowKeys extends FakeKeyStore {
  Completer<void>? delay;
  final started = Completer<void>();
  @override
  Future<String?> read({required bool persistent}) async {
    final key = value;
    if (delay != null) {
      if (!started.isCompleted) started.complete();
      await delay!.future;
    }
    return key;
  }
}

class _SummaryAi extends AiClient {
  final started = Completer<void>();
  final aborted = Completer<void>();
  final release = Completer<void>();

  @override
  Future<String> streamReply({
    required ProviderConfig config,
    required String apiKey,
    required List<PromptMessage> messages,
    required void Function(String) onUpdate,
    int? maxOutputTokens,
    Future<void>? abortTrigger,
  }) async {
    const reply = '今天那家旧书店真的开门了。';
    onUpdate(reply);
    return reply;
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
    started.complete();
    await abortTrigger;
    aborted.complete();
    // Simulate a provider that delivers a result even after cancellation.
    await release.future;
    return const ConversationMemoryUpdate(summary: '不应写入的过期摘要', facts: []);
  }
}

class _DelayedWrites extends FakeKeyStore {
  final started = Completer<void>();
  final release = Completer<void>();
  @override
  Future<void> write(String value, {required bool persistent}) async {
    started.complete();
    await release.future;
    await super.write(value, persistent: persistent);
  }
}

class _DelayedAttachments extends MemoryAttachments {
  final started = Completer<void>();
  final release = Completer<void>();
  @override
  Future<void> clear() async {
    started.complete();
    await release.future;
    await super.clear();
  }
}

Future<AppController> _setup(
  AiClient ai,
  FakeKeyStore keys, {
  bool longHistory = false,
  MemoryAttachments? attachments,
}) async {
  final initial = buildSeedData();
  final c = AppController(
    store: FakeStore(
      initial.copyWith(
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
        settings: initial.settings.copyWith(
          provider: const ProviderConfig(model: 'qa-model'),
        ),
      ),
    ),
    keyStore: keys,
    aiClient: ai,
    attachmentStore: attachments,
  );
  addTearDown(c.dispose);
  for (var i = 0; i < 40 && c.state.loading; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  expect(c.state.loading, isFalse);
  return c;
}

void main() {
  test(
    'reset blocks saves and sends until slow attachment cleanup completes',
    () async {
      final keys = FakeKeyStore()..value = 'old-provider-key';
      final attachments = _DelayedAttachments();
      final c = await _setup(_ProviderAi(), keys, attachments: attachments);
      final reset = c.resetData();
      await attachments.started.future.timeout(const Duration(seconds: 2));
      expect(keys.value, isNull);
      await expectLater(
        c.saveProvider(
          config: c.state.data.settings.provider,
          apiKey: 'new-key',
        ),
        throwsA(isA<AiClientException>()),
      );
      await c.sendMessage('thread_gu', '不应在清空期间发送');
      expect(c.state.data.messages, isEmpty);
      attachments.release.complete();
      await reset;
      expect(keys.value, isNull);
      expect(c.state.hasApiKey, isFalse);
      expect(c.state.data.characters, isEmpty);
      expect(c.state.error, isNull);
    },
  );

  test(
    'credential scope distinguishes tenant paths, origins and invalid addresses',
    () {
      const base = ProviderConfig(baseUrl: 'https://relay.example/tenant-a');
      for (final equivalent in [
        'https://relay.example/tenant-a/v1/',
        'https://relay.example:443/tenant-a/v1/chat/completions',
        'https://RELAY.example/tenant-a/v1/models',
      ]) {
        expect(
          base.sharesCredentialScopeWith(base.copyWith(baseUrl: equivalent)),
          isTrue,
        );
      }
      for (final different in [
        'https://relay.example/tenant-b',
        'http://relay.example/tenant-a',
        'https://other.example/tenant-a',
        'https://relay.example:444/tenant-a',
        'https://relay.example/tenant-a?key=bad',
        'https://user@relay.example/tenant-a',
        'not-a-url',
      ]) {
        expect(
          base.sharesCredentialScopeWith(base.copyWith(baseUrl: different)),
          isFalse,
        );
      }
    },
  );

  for (final mode in ['clear', 'reset']) {
    test('$mode cannot be undone by a delayed provider key write', () async {
      final ai = _ProviderAi();
      final keys = _DelayedWrites()..value = 'old-provider-key';
      final c = await _setup(ai, keys);
      final save = c.saveProvider(
        config: c.state.data.settings.provider.copyWith(
          baseUrl: 'https://another.example',
        ),
        apiKey: 'new-provider-key',
      );
      final check = expectLater(save, throwsA(isA<AiClientException>()));
      await keys.started.future.timeout(const Duration(seconds: 2));
      await expectLater(
        c.saveProvider(config: c.state.data.settings.provider),
        throwsA(isA<AiClientException>()),
      );
      final clearing = mode == 'clear' ? c.clearProviderKey() : c.resetData();
      await Future<void>.delayed(Duration.zero);
      keys.release.complete();
      await check;
      await clearing;
      expect(keys.value, isNull);
      expect(c.state.hasApiKey, isFalse);
      if (mode == 'reset') expect(c.state.data.characters, isEmpty);
    });
  }

  for (final portable in [false, true]) {
    for (final change in ['same', 'supplier', 'storage']) {
      test(
        'backup $portable / $change preserves only matching credentials',
        () async {
          final keys = FakeKeyStore()..value = 'old-provider-key';
          final c = await _setup(_ProviderAi(), keys);
          final original = c.state.data;
          final restored = original.copyWith(
            settings: original.settings.copyWith(
              provider: original.settings.provider.copyWith(
                baseUrl: change == 'supplier'
                    ? 'https://another.example'
                    : 'https://api.deepseek.com/v1/',
                rememberKey: change == 'storage',
              ),
            ),
          );
          final backup = portable
              ? jsonEncode({
                  'format': 'dreamtide.media.v1',
                  'data': restored.toJson(),
                  'attachments': <String, String>{},
                })
              : restored.encode();
          await c.importBackup(backup);
          expect(keys.value, change == 'same' ? 'old-provider-key' : isNull);
          expect(c.state.hasApiKey, change == 'same');
          expect(
            c.state.data.settings.provider.baseUrl,
            restored.settings.provider.baseUrl,
          );
        },
      );
    }
  }

  for (final change in ['save', 'clear']) {
    test('$change cancels quiet memory and discards late results', () async {
      final ai = _SummaryAi();
      final c = await _setup(
        ai,
        FakeKeyStore()..value = 'old-provider-key',
        longHistory: true,
      );
      await c.sendMessage('thread_gu', '后来呢');
      await ai.started.future.timeout(const Duration(seconds: 2));
      final before = c.state.data.threads
          .firstWhere((t) => t.id == 'thread_gu')
          .contextMemo;
      if (change == 'save') {
        await c.saveProvider(
          config: c.state.data.settings.provider,
          apiKey: 'new-key',
        );
      } else {
        await c.clearProviderKey();
      }
      await ai.aborted.future.timeout(const Duration(seconds: 1));
      ai.release.complete();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(
        c.state.data.threads.firstWhere((t) => t.id == 'thread_gu').contextMemo,
        before,
      );
      expect(c.state.error, isNull);
    });
  }

  test(
    'changing supplier never reuses saved key when fetching or saving',
    () async {
      final ai = _ProviderAi();
      final keys = FakeKeyStore()..value = 'old-provider-key';
      final c = await _setup(ai, keys);
      final original = c.state.data.settings.provider;
      final changed = original.copyWith(baseUrl: 'https://another.example/v1');
      await expectLater(
        c.fetchProviderModels(config: changed),
        throwsA(isA<AiClientException>()),
      );
      expect(ai.catalogs, isEmpty);
      await expectLater(
        c.saveProvider(config: changed),
        throwsA(isA<AiClientException>()),
      );
      expect(c.state.data.settings.provider.baseUrl, original.baseUrl);
      expect(keys.value, 'old-provider-key');
      await c.fetchProviderModels(config: changed, apiKey: 'new-provider-key');
      expect(ai.catalogs.single.$2, 'new-provider-key');
    },
  );

  test('equivalent base and v1 addresses retain the saved key', () async {
    final ai = _ProviderAi();
    final keys = FakeKeyStore()..value = 'old-provider-key';
    final c = await _setup(ai, keys);
    await c.fetchProviderModels(
      config: c.state.data.settings.provider.copyWith(
        baseUrl: 'https://api.deepseek.com/v1/',
      ),
    );
    expect(ai.catalogs.single.$2, 'old-provider-key');
  });

  test(
    'catalog awaiting credentials cannot resume after key clearing',
    () async {
      final ai = _ProviderAi();
      final keys = _SlowKeys()..value = 'old-provider-key';
      final c = await _setup(ai, keys);
      keys.delay = Completer<void>();
      final work = c.fetchProviderModels(
        config: c.state.data.settings.provider,
      );
      final check = expectLater(work, throwsA(isA<AiClientException>()));
      await keys.started.future;
      await c.clearProviderKey();
      keys.delay!.complete();
      await check;
      expect(ai.catalogs, isEmpty);
    },
  );

  for (final mode in ['change', 'clear']) {
    test(
      '$mode provider stops main generation and preserves interrupted speech',
      () async {
        final ai = _ProviderAi();
        final keys = FakeKeyStore()..value = 'old-provider-key';
        final c = await _setup(ai, keys);
        final work = c.sendMessage('thread_gu', '接着说');
        await ai.started.future.timeout(const Duration(seconds: 2));
        if (mode == 'clear') {
          await c.clearProviderKey();
        } else {
          await c.saveProvider(
            config: c.state.data.settings.provider.copyWith(
              baseUrl: 'https://another.example',
              model: 'model-b',
            ),
            apiKey: 'new-provider-key',
          );
        }
        await ai.aborted.future.timeout(const Duration(seconds: 1));
        await work;
        expect(c.state.generatingThreadId, isNull);
        final partial = c.state.data.messages.last;
        expect(partial.text, '说到一半');
        expect(partial.interrupted, isTrue);
        expect(partial.editedAt, isNull);
        expect(c.state.data.relationships.first.interactionCount, 0);
      },
    );
  }
}
