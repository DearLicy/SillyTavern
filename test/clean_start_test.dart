import 'dart:async';
import 'package:sillytavern_app/ai/ai_client.dart';
import 'package:sillytavern_app/ai/context_assembler.dart';
import 'package:sillytavern_app/domain/models.dart';
import 'package:sillytavern_app/application/app_controller.dart';
import 'package:sillytavern_app/data/initial_data.dart';
import 'package:flutter_test/flutter_test.dart';
import 'fixtures/fake_store.dart';
import 'fixtures/sample_data.dart';

void main() {
  test(
    'fresh state contains no contacts, personas, conversations, memories or moments',
    () {
      final data = buildEmptyData();
      expect(
        [
          data.personas,
          data.characters,
          data.relationships,
          data.threads,
          data.messages,
          data.memories,
          data.moments,
        ].every((e) => e.isEmpty),
        isTrue,
      );
      expect(data.settings.provider.baseUrl, 'https://api.deepseek.com');
      expect(data.settings.provider.kind, ProviderKind.openaiCompatible);
      expect(const ProviderConfig().kind, ProviderKind.openaiCompatible);
      expect(ProviderConfig.fromJson({}).kind, ProviderKind.openaiCompatible);
      expect(data.settings.provider.model, isEmpty);
      expect(data.settings.provider.models, isEmpty);
      expect(data.settings.provider.rememberKey, isFalse);
    },
  );
  test(
    'no API configuration means no fabricated reply and no accepted draft',
    () async {
      final source = buildSeedData();
      final controller = AppController(
        store: FakeStore(source),
        keyStore: FakeKeyStore(),
        toolKeyStore: FakeKeyStore(),
      );
      await Future<void>.delayed(Duration.zero);
      var accepted = false;
      await controller.sendMessage(
        source.threads.first.id,
        'hello',
        onAccepted: () => accepted = true,
      );
      expect(accepted, isFalse);
      expect(controller.state.data.messages.length, source.messages.length);
      expect(controller.state.error, contains('拉取并选择模型'));
      controller.dispose();
    },
  );
  test(
    'safety word is recorded locally and pauses the relationship without a key',
    () async {
      final source = buildSeedData();
      final relationship = source.relationships.first;
      final controller = AppController(
        store: FakeStore(source),
        keyStore: FakeKeyStore(),
        toolKeyStore: FakeKeyStore(),
      );
      await Future<void>.delayed(Duration.zero);
      await controller.sendMessage(
        source.threadForRelationship(relationship.id)!.id,
        relationship.consent.safeWord,
      );
      final updated = controller.state.data.relationships.firstWhere(
        (item) => item.id == relationship.id,
      );
      expect(updated.consent.paused, isTrue);
      expect(
        controller.state.data.messages.any(
          (message) => message.text == relationship.consent.safeWord,
        ),
        isTrue,
      );
      expect(controller.state.generatingThreadId, isNull);
      controller.dispose();
    },
  );
  test(
    'publishing creates only user supplied content and no simulated reactions',
    () async {
      final controller = AppController(
        store: FakeStore(),
        keyStore: FakeKeyStore(),
        toolKeyStore: FakeKeyStore(),
      );
      await Future<void>.delayed(Duration.zero);
      controller.publishMoment('自己的记录');
      final moment = controller.state.data.moments.single;
      expect(moment.content, '自己的记录');
      expect(moment.comments, isEmpty);
      expect(moment.likedBy, isEmpty);
      controller.dispose();
    },
  );
  test(
    'reset clears local content and keys rather than restoring a sample',
    () async {
      final keyStore = FakeKeyStore()..value = 'fake';
      final controller = AppController(
        store: FakeStore(buildSeedData()),
        keyStore: keyStore,
        toolKeyStore: FakeKeyStore(),
      );
      await Future<void>.delayed(Duration.zero);
      await controller.resetData();
      expect(controller.state.data.characters, isEmpty);
      expect(controller.state.data.messages, isEmpty);
      expect(controller.state.data.moments, isEmpty);
      expect(keyStore.value, isNull);
      controller.dispose();
    },
  );
  test('reset invalidates a model reply already in flight', () async {
    final ai = DeferredAi();
    final fixture = buildSeedData();
    final controller = AppController(
      store: FakeStore(
        fixture.copyWith(
          settings: fixture.settings.copyWith(
            provider: const ProviderConfig(model: 'qa-model'),
          ),
        ),
      ),
      keyStore: FakeKeyStore()..value = 'fake',
      toolKeyStore: FakeKeyStore(),
      aiClient: ai,
    );
    await Future<void>.delayed(Duration.zero);
    final pending = controller.sendMessage(
      controller.state.data.threads.first.id,
      'hello',
    );
    await Future<void>.delayed(Duration.zero);
    expect(controller.state.generatingThreadId, isNotNull);
    await controller.resetData();
    ai.reply.complete('A late response');
    await pending;
    expect(controller.state.data.messages, isEmpty);
    expect(controller.state.data.characters, isEmpty);
    controller.dispose();
  });
}

class DeferredAi extends AiClient {
  final reply = Completer<String>();
  @override
  Future<String> streamReply({
    required ProviderConfig config,
    required String apiKey,
    required List<PromptMessage> messages,
    required void Function(String) onUpdate,
    int? maxOutputTokens,
    Future<void>? abortTrigger,
  }) async => reply.future;
}
