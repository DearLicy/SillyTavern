import 'package:flutter_test/flutter_test.dart';
import 'package:sillytavern_app/application/app_controller.dart';
import 'package:sillytavern_app/ai/context_assembler.dart';
import 'package:sillytavern_app/domain/models.dart';

import 'fixtures/fake_store.dart';
import 'fixtures/sample_data.dart';

Future<AppController> _loaded(FakeStore store) async {
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
  test('createGroupChat builds a reusable multi-character thread', () async {
    final seed = buildSeedData();
    final store = FakeStore(
      seed.copyWith(
        settings: seed.settings.copyWith(currentPersonaId: 'persona_lin'),
      ),
    );
    final controller = await _loaded(store);
    addTearDown(controller.dispose);

    final thread = await controller.createGroupChat(
      characterIds: const ['char_gu', 'char_shen'],
    );
    expect(thread.type, ThreadType.group);
    expect(thread.participantIds, ['char_gu', 'char_shen']);
    expect(thread.relationshipId, 'rel_gu');
    expect(thread.title, contains('顾言'));
    expect(controller.state.data.threads.any((t) => t.id == thread.id), isTrue);

    final again = await controller.createGroupChat(
      characterIds: const ['char_shen', 'char_gu'],
    );
    expect(again.id, thread.id);
    expect(
      controller.state.data.threads.where((t) => t.type == ThreadType.group),
      hasLength(1),
    );
  });

  test('createGroupChat requires at least two characters', () async {
    final controller = await _loaded(FakeStore(buildSeedData()));
    addTearDown(controller.dispose);
    await expectLater(
      controller.createGroupChat(characterIds: const ['char_gu']),
      throwsA(isA<StateError>()),
    );
  });

  test('group context includes every participant and speaker rule', () {
    final seed = buildSeedData();
    final thread = ChatThread(
      id: 'group_1',
      relationshipId: 'rel_gu',
      type: ThreadType.group,
      title: '顾言、沈砚 · 群聊',
      updatedAt: DateTime(2026, 1, 1),
      participantIds: const ['char_gu', 'char_shen'],
    );
    final bundle = const ContextAssembler().assemble(
      data: seed,
      thread: thread,
      userInput: '你们在吗？',
    );
    final system = bundle.messages.first.content;
    expect(system, contains('群聊 · 多角色场景'));
    expect(system, contains('顾言'));
    expect(system, contains('沈砚'));
    expect(system, contains('【角色名】'));
  });
}
