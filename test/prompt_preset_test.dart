import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sillytavern_app/application/app_controller.dart';
import 'package:sillytavern_app/domain/models.dart';

import 'fixtures/fake_store.dart';
import 'fixtures/sample_data.dart';

Future<AppController> _loadedController(FakeStore store) async {
  final controller = AppController(
    store: store,
    keyStore: FakeKeyStore(),
    toolKeyStore: FakeKeyStore(),
    attachmentStore: MemoryAttachments(),
  );
  for (var i = 0; i < 40 && controller.state.loading; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  return controller;
}

void main() {
  test('exportPromptPreset returns JSON with prompt and rules', () async {
    final store = FakeStore(buildSeedData());
    final controller = await _loadedController(store);
    addTearDown(controller.dispose);

    final json = controller.exportPromptPreset(name: '我的预设');
    final map = jsonDecode(json) as Map<String, dynamic>;
    expect(map['name'], '我的预设');
    expect(map['systemPrefix'], isA<String>());
    expect(map['postHistoryInstructions'], isA<String>());
    expect(map['rules'], isA<List>());
    expect(map['prompts'], isA<List>());
    expect(map['blocks'], isA<List>());
    expect(map['temperature'], isA<num>());
  });

  test('importPromptPreset replaces prompts and merges valid rules', () async {
    final store = FakeStore(buildSeedData());
    final controller = await _loadedController(store);
    addTearDown(controller.dispose);
    final before = controller.state.data.settings.prompts.rules.length;

    await controller.importPromptPreset(
      jsonEncode({
        'name': 'p',
        'systemPrefix': '新的系统提示',
        'postHistoryInstructions': '新的后置指令',
        'rules': [
          {
            'name': '移除风扇',
            'pattern': 'fan',
            'replacement': '风扇',
            'target': 'aiOutput',
            'enabled': true,
          },
          {
            'name': '禁用规则',
            'pattern': 'x',
            'replacement': 'y',
            'enabled': false,
          },
        ],
      }),
    );

    final prompts = controller.state.data.settings.prompts;
    expect(prompts.systemPrefix, '新的系统提示');
    expect(prompts.postHistoryInstructions, '新的后置指令');
    expect(prompts.rules, hasLength(before + 2));
    final enabled = prompts.rules[prompts.rules.length - 2];
    expect(enabled.name, '移除风扇');
    expect(enabled.enabled, isTrue);
    expect(enabled.target, RegexTarget.aiOutput);
    expect(prompts.rules.last.enabled, isFalse);
    expect(store.data, isNotNull);
  });

  test('importPromptPreset rejects invalid regex', () async {
    final store = FakeStore(buildSeedData());
    final controller = await _loadedController(store);
    addTearDown(controller.dispose);

    await expectLater(
      controller.importPromptPreset(
        jsonEncode({
          'systemPrefix': '',
          'postHistoryInstructions': '',
          'rules': [
            {'name': '坏正则', 'pattern': '([', 'replacement': ''},
          ],
        }),
      ),
      throwsA(isA<FormatException>()),
    );
  });

  test(
    'official Chat Completion preset updates prompts and sampling',
    () async {
      final seed = buildSeedData();
      final store = FakeStore(seed);
      final controller = await _loadedController(store);
      addTearDown(controller.dispose);
      final originalProvider = controller.state.data.settings.provider;
      final originalRules = controller.state.data.settings.prompts.rules;

      await controller.importPromptPreset(
        jsonEncode({
          'name': 'Official style',
          'chat_completion_source': 'openai',
          'temperature': 0.7,
          'top_p': 0.8,
          'frequency_penalty': 0.2,
          'presence_penalty': -0.1,
          'openai_max_tokens': 512,
          'stop': ['END', '---'],
          'prompts': [
            {
              'identifier': 'main',
              'name': 'Main Prompt',
              'role': 'system',
              'content': 'Write the next roleplay reply.',
            },
            {
              'identifier': 'nsfw',
              'name': 'Auxiliary Prompt',
              'content': 'Keep continuity.',
            },
            {
              'identifier': 'jailbreak',
              'name': 'Post-History Instructions',
              'content': 'Do not use assistant filler.',
            },
            {
              'identifier': 'depth_reminder',
              'name': 'Depth Reminder',
              'role': 'assistant',
              'content': 'Keep the reply short.',
              'injection_depth': 2,
              'enabled': false,
            },
            {
              'identifier': 'chatHistory',
              'name': 'Chat History',
              'marker': true,
              'content': 'must not be copied',
            },
          ],
        }),
      );

      final settings = controller.state.data.settings;
      expect(settings.prompts.systemPrefix, contains('roleplay reply'));
      expect(settings.prompts.systemPrefix, isNot(contains('Keep continuity')));
      expect(
        settings.prompts.systemPrefix,
        isNot(contains('must not be copied')),
      );
      expect(
        settings.prompts.postHistoryInstructions,
        contains('assistant filler'),
      );
      expect(settings.prompts.blocks, hasLength(2));
      expect(settings.prompts.blocks.first.name, 'Auxiliary Prompt');
      expect(settings.prompts.blocks.first.content, 'Keep continuity.');
      expect(
        settings.prompts.blocks.first.position,
        PromptInjectionPosition.beforeHistory,
      );
      expect(settings.prompts.blocks.last.role, PromptBlockRole.assistant);
      expect(
        settings.prompts.blocks.last.position,
        PromptInjectionPosition.atDepth,
      );
      expect(settings.prompts.blocks.last.depth, 2);
      expect(settings.prompts.blocks.last.enabled, isFalse);
      expect(settings.prompts.rules, originalRules);
      expect(settings.provider.baseUrl, originalProvider.baseUrl);
      expect(settings.provider.model, originalProvider.model);
      expect(settings.provider.temperature, 0.7);
      expect(settings.provider.topP, 0.8);
      expect(settings.provider.frequencyPenalty, 0.2);
      expect(settings.provider.presencePenalty, -0.1);
      expect(settings.provider.maxOutputTokens, 512);
      expect(settings.provider.stopSequences, ['END', '---']);
      expect(store.data!.settings.provider.temperature, 0.7);
    },
  );

  test('app prompt preset round trips ordered prompt blocks', () async {
    final seed = buildSeedData();
    final source = seed.copyWith(
      settings: seed.settings.copyWith(
        prompts: const PromptConfig(
          blocks: [
            PromptBlock(
              id: 'after',
              name: '角色卡后规则',
              content: '保持短句。',
              position: PromptInjectionPosition.afterCharacter,
              order: 1,
            ),
            PromptBlock(
              id: 'depth',
              name: '深度提醒',
              content: '不要复读。',
              role: PromptBlockRole.assistant,
              position: PromptInjectionPosition.atDepth,
              depth: 3,
              order: 2,
            ),
          ],
        ),
      ),
    );
    final store = FakeStore(source);
    final controller = await _loadedController(store);
    addTearDown(controller.dispose);

    final exported = controller.exportPromptPreset(name: 'roundtrip');
    await controller.importPromptPreset(exported);

    final blocks = controller.state.data.settings.prompts.blocks;
    expect(blocks, hasLength(2));
    expect(blocks.first.name, '角色卡后规则');
    expect(blocks.first.position, PromptInjectionPosition.afterCharacter);
    expect(blocks.last.role, PromptBlockRole.assistant);
    expect(blocks.last.position, PromptInjectionPosition.atDepth);
    expect(blocks.last.depth, 3);
  });
}
