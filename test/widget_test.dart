import 'dart:convert';
import 'dart:typed_data';

import 'package:sillytavern_app/app.dart';
import 'package:sillytavern_app/application/app_controller.dart';
import 'package:sillytavern_app/data/attachment_store.dart';
import 'package:sillytavern_app/data/initial_data.dart';
import 'package:sillytavern_app/domain/models.dart';
import 'package:sillytavern_app/router/app_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'fixtures/fake_store.dart';
import 'fixtures/sample_data.dart';

Future<ProviderContainer> start(
  WidgetTester tester,
  AppData data, {
  List<Override> overrides = const [],
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final container = ProviderContainer(
    overrides: [
      ...overrides,
      appControllerProvider.overrideWith(
        (ref) => AppController(
          store: FakeStore(data),
          keyStore: FakeKeyStore(),
          toolKeyStore: FakeKeyStore(),
          attachmentStore: ref.watch(attachmentStoreProvider),
        ),
      ),
    ],
  );

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const SillyTavernApp(),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

class _FakeAttachmentStore implements AttachmentStore {
  static final _pixel = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
  );

  @override
  Future<void> delete(String reference) async {}

  @override
  Future<void> clear() async {}

  @override
  Future<Uint8List?> readImage(String reference) async => _pixel;

  @override
  Future<String> saveImage({
    required String id,
    required Uint8List bytes,
    required String mimeType,
  }) async => id;
}

void main() {
  testWidgets('image messages render from the attachment store', (
    tester,
  ) async {
    final fixture = buildSeedData();
    final image = Message(
      id: 'image-message',
      threadId: 'thread_gu',
      senderId: 'owner',
      senderName: fixture.owner.displayName,
      text: '像不像下雨的晚上',
      createdAt: DateTime.now(),
      kind: MessageKind.image,
      localPath: 'image-reference',
    );
    final container = await start(
      tester,
      fixture.copyWith(
        messages: [image],
        settings: fixture.settings.copyWith(ageConfirmed: true),
      ),
      overrides: [
        attachmentStoreProvider.overrideWithValue(_FakeAttachmentStore()),
      ],
    );
    container.read(appRouterProvider).push('/chat/thread_gu');
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('message-image')), findsOneWidget);
    expect(find.text('像不像下雨的晚上'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    container.dispose();
  });

  testWidgets('character page shows SillyTavern card fields', (tester) async {
    final fixture = buildSeedData();
    final character = fixture.characters.first.copyWith(
      scenario: '雨夜里的公寓。',
      exampleDialogue: '{{user}}: 在吗？\n{{char}}: 在。',
      postHistoryInstructions: '不要总结对话。',
    );
    final container = await start(
      tester,
      fixture.copyWith(
        characters: [character, ...fixture.characters.skip(1)],
        settings: fixture.settings.copyWith(ageConfirmed: true),
      ),
    );
    container.read(appRouterProvider).push('/character/char_gu');
    await tester.pumpAndSettle();

    expect(find.text('场景'), findsOneWidget);
    expect(find.text('雨夜里的公寓。'), findsOneWidget);
    expect(find.text('对话示例'), findsOneWidget);
    expect(find.text('角色后置指令'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    container.dispose();
  });

  testWidgets(
    'first adult confirmation opens a clean SillyTavern home without tabs',
    (tester) async {
      final container = await start(tester, buildEmptyData());
      await tester.tap(find.text('我已成年，进入应用'));
      await tester.pumpAndSettle();
      expect(find.text('SillyTavern'), findsWidgets);
      expect(find.text('还没有找到对话'), findsOneWidget);
      expect(find.text('顾言'), findsNothing);
      expect(find.byKey(const ValueKey('root-bottom-bar')), findsNothing);
      container.read(appRouterProvider).go('/characters');
      await tester.pumpAndSettle();
      expect(find.text('角色'), findsWidgets);
      expect(find.text('顾言'), findsNothing);
      container.read(appRouterProvider).go('/');
      await tester.pumpAndSettle();
      expect(find.text('SillyTavern'), findsWidgets);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      container.dispose();
    },
  );

  testWidgets(
    'AI narration stays outside bubbles and chat has no bottom navigation',
    (tester) async {
      final fixture = buildSeedData();
      final message = Message(
        id: 'action',
        threadId: 'thread_gu',
        senderId: 'char_gu',
        senderName: '顾言',
        text: '（轻轻抬手）你好。 (望向窗外)',
        createdAt: DateTime.now(),
        fromAi: true,
      );
      final container = await start(
        tester,
        fixture.copyWith(
          messages: [message],
          settings: fixture.settings.copyWith(ageConfirmed: true),
        ),
      );
      container.read(appRouterProvider).push('/chat/thread_gu');
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('root-bottom-bar')), findsNothing);
      expect(find.byKey(const ValueKey('message-narration')), findsNWidgets(2));
      expect(find.byKey(const ValueKey('message-speech')), findsOneWidget);
      expect(find.text('你好。'), findsOneWidget);
      expect(find.text('轻轻抬手'), findsOneWidget);
      expect(find.textContaining('（轻轻抬手）'), findsNothing);
      await tester.enterText(find.byType(EditableText), '保留我的草稿');
      await tester.pump();
      await tester.tap(find.byTooltip('发送'));
      await tester.pumpAndSettle();
      expect(find.text('保留我的草稿'), findsOneWidget);
      expect(find.text('请先配置 API Key、拉取并选择模型'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      container.dispose();
    },
  );

  testWidgets('new character is independent from an optional user persona', (
    tester,
  ) async {
    final empty = buildEmptyData();
    final container = await start(
      tester,
      empty.copyWith(settings: empty.settings.copyWith(ageConfirmed: true)),
    );
    container.read(appRouterProvider).push('/character/new');
    await tester.pumpAndSettle();
    expect(find.text('创建角色'), findsWidgets);
    expect(find.text('角色名'), findsOneWidget);
    expect(find.byKey(const ValueKey('root-bottom-bar')), findsNothing);
    container.read(appRouterProvider).go('/provider');
    await tester.pumpAndSettle();
    expect(find.text('https://api.deepseek.com'), findsWidgets);
    expect(find.text('拉取模型'), findsOneWidget);
    expect(find.text('拉取后点击选择，无需手填'), findsOneWidget);
    expect(find.text('生成参数'), findsOneWidget);
    expect(find.text('最大输出 Token'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    container.dispose();
  });

  testWidgets(
    'world books and character cards are reachable full-screen pages',
    (tester) async {
      final fixture = buildSeedData();
      final container = await start(
        tester,
        fixture.copyWith(
          settings: fixture.settings.copyWith(ageConfirmed: true),
        ),
      );
      container.read(appRouterProvider).go('/world-books');
      await tester.pumpAndSettle();
      expect(find.text('世界书'), findsWidgets);
      expect(find.text('还没有世界书'), findsOneWidget);
      expect(find.byKey(const ValueKey('root-bottom-bar')), findsNothing);

      container.read(appRouterProvider).go('/character-cards');
      await tester.pumpAndSettle();
      expect(find.text('角色卡'), findsWidgets);
      expect(find.text('从剪贴板导入 JSON'), findsOneWidget);
      expect(find.text('选择 PNG 角色卡'), findsOneWidget);
      expect(find.byKey(const ValueKey('root-bottom-bar')), findsNothing);

      container.read(appRouterProvider).go('/prompts');
      await tester.pumpAndSettle();
      expect(find.text('提示词与正则'), findsWidgets);
      expect(find.text('全局系统提示词'), findsOneWidget);
      expect(find.text('保存提示词规则'), findsOneWidget);
      expect(find.byKey(const ValueKey('root-bottom-bar')), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      container.dispose();
    },
  );
}
