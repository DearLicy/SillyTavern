import 'package:flutter_test/flutter_test.dart';
import 'package:sillytavern_app/application/app_controller.dart';

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
  test('startWithGreeting adds one AI opening and never overwrites', () async {
    final seed = buildSeedData();
    final store = FakeStore(seed.copyWith(messages: const []));
    final controller = await _loaded(store);
    addTearDown(controller.dispose);

    await controller.startWithGreeting('thread_gu', '雨停了，要出去走走吗？');
    final first = controller.state.data.messages
        .where((m) => m.threadId == 'thread_gu')
        .toList();
    expect(first, hasLength(1));
    expect(first.single.fromAi, isTrue);
    expect(first.single.senderName, '顾言');
    expect(first.single.text, '雨停了，要出去走走吗？');

    // A second greeting must not add another opening once a transcript exists.
    await controller.startWithGreeting('thread_gu', '早餐在桌上。');
    final second = controller.state.data.messages
        .where((m) => m.threadId == 'thread_gu')
        .toList();
    expect(second, hasLength(1));
  });

  test('startWithGreeting ignores blank input', () async {
    final store = FakeStore(buildSeedData().copyWith(messages: const []));
    final controller = await _loaded(store);
    addTearDown(controller.dispose);
    await controller.startWithGreeting('thread_gu', '   ');
    expect(
      controller.state.data.messages.where((m) => m.threadId == 'thread_gu'),
      isEmpty,
    );
  });
}
