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
          {'name': '禁用规则', 'pattern': 'x', 'replacement': 'y', 'enabled': false},
        ],
      }),
    );

    final prompts = controller.state.data.settings.prompts;
    expect(prompts.systemPrefix, '新的系统提示');
    expect(prompts.postHistoryInstructions, '新的后置指令');
    expect(prompts.rules, hasLength(before + 1));
    final added = prompts.rules.last;
    expect(added.name, '移除风扇');
    expect(added.target, RegexTarget.aiOutput);
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
}
