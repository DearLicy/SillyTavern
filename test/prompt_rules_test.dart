import 'package:sillytavern_app/ai/ai_client.dart';
import 'package:sillytavern_app/ai/context_assembler.dart';
import 'package:sillytavern_app/ai/regex_transformer.dart';
import 'package:sillytavern_app/application/app_controller.dart';
import 'package:sillytavern_app/domain/models.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures/fake_store.dart';
import 'fixtures/sample_data.dart';

class _ReplyAi extends AiClient {
  List<PromptMessage>? prompts;

  @override
  Future<String> streamReply({
    required ProviderConfig config,
    required String apiKey,
    required List<PromptMessage> messages,
    required void Function(String) onUpdate,
    int? maxOutputTokens,
    Future<void>? abortTrigger,
  }) async {
    prompts = messages;
    const reply = '*哈*';
    onUpdate(reply);
    return reply;
  }
}

void main() {
  test('rules honor target, order, flags and capture groups', () {
    const config = PromptConfig(
      rules: [
        RegexRule(
          id: 'second',
          name: 'second',
          pattern: 'bar',
          replacement: 'baz',
          order: 20,
        ),
        RegexRule(
          id: 'first',
          name: 'first',
          pattern: 'FOO',
          replacement: 'bar',
          order: 10,
        ),
        RegexRule(
          id: 'other-target',
          name: 'other',
          pattern: 'bar',
          replacement: 'wrong',
          target: RegexTarget.userInput,
        ),
        RegexRule(
          id: 'capture',
          name: 'capture',
          pattern: r'\*([^*]+)\*',
          replacement: r'[$1]',
          order: 30,
        ),
      ],
    );
    expect(
      RegexTransformer.apply('foo *笑*', config, RegexTarget.aiOutput),
      'baz [笑]',
    );
  });

  test(
    'replacement expansion supports braces, whole match and escaped dollar',
    () {
      const config = PromptConfig(
        rules: [
          RegexRule(
            id: 'groups',
            name: 'groups',
            pattern: '(x)',
            replacement: r'${1} $& $$',
          ),
        ],
      );
      expect(
        RegexTransformer.apply('x', config, RegexTarget.aiOutput),
        r'x x $',
      );
    },
  );

  test('invalid, empty and oversized rules fail closed', () {
    const invalid = RegexRule(
      id: 'invalid',
      name: 'invalid',
      pattern: '[',
      replacement: 'x',
    );
    expect(RegexTransformer.validate(invalid), contains('无效'));
    const empty = RegexRule(
      id: 'empty',
      name: 'empty',
      pattern: '',
      replacement: 'x',
    );
    expect(RegexTransformer.validate(empty), isNotNull);
    const config = PromptConfig(rules: [invalid, empty]);
    expect(
      RegexTransformer.apply('safe', config, RegexTarget.aiOutput),
      'safe',
    );
    expect(RegexTransformer.validateAll(config), hasLength(2));
    final oversized = 'x' * (RegexTransformer.maxInputLength + 1);
    expect(
      RegexTransformer.apply(oversized, config, RegexTarget.aiOutput),
      oversized,
    );
  });

  test('prompt config round trips and legacy settings default safely', () {
    const config = PromptConfig(
      systemPrefix: '{{char}} 与 {{user}} 保持短句。',
      postHistoryInstructions: '不要客服腔。',
      rules: [
        RegexRule(
          id: 'r',
          name: '去粗体',
          pattern: r'\*\*([^*]+)\*\*',
          replacement: r'$1',
          target: RegexTarget.aiOutput,
          caseSensitive: true,
          order: 5,
        ),
      ],
    );
    final restored = PromptConfig.fromJson(config.toJson());
    expect(restored.systemPrefix, contains('{{char}}'));
    expect(restored.rules.single.target, RegexTarget.aiOutput);
    expect(restored.rules.single.caseSensitive, isTrue);

    final legacySettings = AppSettings.fromJson(const {});
    expect(legacySettings.prompts.systemPrefix, '');
    expect(legacySettings.prompts.rules, isEmpty);
  });

  test(
    'controller transforms prompt input and final AI output locally',
    () async {
      final seed = buildSeedData();
      final data = seed.copyWith(
        settings: seed.settings.copyWith(
          currentPersonaId: 'persona_lin',
          provider: const ProviderConfig(model: 'qa-model'),
          prompts: const PromptConfig(
            systemPrefix: '写短句。',
            postHistoryInstructions: '不要总结。',
            rules: [
              RegexRule(
                id: 'input',
                name: 'input',
                pattern: 'RAW',
                replacement: 'CLEAN',
                target: RegexTarget.userInput,
              ),
              RegexRule(
                id: 'output',
                name: 'output',
                pattern: r'\*([^*]+)\*',
                replacement: r'[$1]',
                target: RegexTarget.aiOutput,
              ),
            ],
          ),
        ),
      );
      final ai = _ReplyAi();
      final controller = AppController(
        store: FakeStore(data),
        keyStore: FakeKeyStore()..value = 'fake-key',
        toolKeyStore: FakeKeyStore(),
        aiClient: ai,
        attachmentStore: MemoryAttachments(),
      );
      addTearDown(controller.dispose);
      for (var i = 0; i < 40 && controller.state.loading; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      await controller.sendMessage('thread_gu', 'RAW');
      final system = ai.prompts!.first.content;
      expect(system, contains('写短句。'));
      expect(system, contains('不要总结。'));
      expect(ai.prompts!.last.content, contains('CLEAN'));
      final threadMessages =
          controller.state.data.messages
              .where((m) => m.threadId == 'thread_gu')
              .toList()
            ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      expect(threadMessages.lastWhere((m) => !m.fromAi).text, 'RAW');
      expect(threadMessages.last.text, '[哈]');
    },
  );

  test(
    'invalid prompt configuration is rejected without changing state',
    () async {
      final seed = buildSeedData();
      final controller = AppController(
        store: FakeStore(seed),
        keyStore: FakeKeyStore(),
        toolKeyStore: FakeKeyStore(),
        attachmentStore: MemoryAttachments(),
      );
      addTearDown(controller.dispose);
      for (var i = 0; i < 40 && controller.state.loading; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      final before = controller.state.data.settings.prompts;
      await expectLater(
        controller.savePromptConfig(
          const PromptConfig(
            rules: [
              RegexRule(id: 'bad', name: 'bad', pattern: '[', replacement: ''),
            ],
          ),
        ),
        throwsA(isA<FormatException>()),
      );
      expect(identical(controller.state.data.settings.prompts, before), isTrue);
    },
  );
}
