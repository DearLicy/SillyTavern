import 'package:sillytavern_app/application/app_controller.dart';
import 'package:sillytavern_app/data/initial_data.dart';
import 'package:sillytavern_app/router/app_router.dart';
import 'package:sillytavern_app/ui/components/dt_controls.dart';
import 'package:sillytavern_app/ui/components/dt_edit_sheet.dart';
import 'package:sillytavern_app/ui/components/dt_input.dart';
import 'package:sillytavern_app/ui/theme/dt_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures/sample_data.dart';
import 'widget_test.dart' as fixture;

void main() {
  testWidgets(
    'a deep link survives loading instead of opening the messages root',
    (tester) async {
      tester.binding.platformDispatcher.defaultRouteNameTestValue =
          '/chat-history/thread_gu';
      addTearDown(
        tester.binding.platformDispatcher.clearDefaultRouteNameTestValue,
      );
      final data = buildSeedData();
      final container = await fixture.start(
        tester,
        data.copyWith(settings: data.settings.copyWith(ageConfirmed: true)),
      );
      expect(find.text('聊天记录'), findsOneWidget);
      expect(find.text('搜索消息与角色'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      container.dispose();
    },
  );

  testWidgets(
    'entry gate sheet works and confirmation preserves the pending deep link',
    (tester) async {
      tester.binding.platformDispatcher.defaultRouteNameTestValue =
          '/chat-history/thread_gu';
      addTearDown(
        tester.binding.platformDispatcher.clearDefaultRouteNameTestValue,
      );
      final data = buildSeedData();
      final container = await fixture.start(
        tester,
        data.copyWith(settings: data.settings.copyWith(ageConfirmed: false)),
      );
      await tester.tap(find.text('我未满 18 岁'));
      await tester.pumpAndSettle();
      expect(find.text('无法继续'), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
      await tester.tap(find.text('返回'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('我已成年，进入梦境'));
      await tester.pumpAndSettle();
      expect(find.text('聊天记录'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      container.dispose();
    },
  );

  testWidgets('fresh entry never adds demo records after visiting gate sheet', (
    tester,
  ) async {
    final container = await fixture.start(tester, buildEmptyData());
    await tester.tap(find.text('我未满 18 岁'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('返回'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('我已成年，进入梦境'));
    await tester.pumpAndSettle();
    expect(container.read(appControllerProvider).data.characters, isEmpty);
    expect(container.read(appControllerProvider).data.messages, isEmpty);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    container.dispose();
  });

  testWidgets(
    'chat long press edits locally, marks correction and exposes deletion',
    (tester) async {
      final data = buildSeedData();
      final container = await fixture.start(
        tester,
        data.copyWith(settings: data.settings.copyWith(ageConfirmed: true)),
      );
      final router = container.read(appRouterProvider);
      router.push('/chat/thread_gu');
      await tester.pumpAndSettle();
      final user = data.messages.firstWhere(
        (m) => m.threadId == 'thread_gu' && !m.fromAi,
      );
      await tester.longPress(find.text(user.text));
      await tester.pumpAndSettle();
      expect(find.text('编辑消息'), findsOneWidget);
      expect(find.text('删除消息'), findsOneWidget);
      await tester.tap(find.text('编辑消息'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(EditableText).last, '我想把刚才那句话说清楚。');
      await tester.tap(find.text('保存修改'));
      await tester.pumpAndSettle();
      expect(find.text('我想把刚才那句话说清楚。'), findsOneWidget);
      expect(find.text('已编辑'), findsOneWidget);
      expect(
        container
            .read(appControllerProvider)
            .data
            .messages
            .firstWhere((m) => m.id == user.id)
            .editedAt,
        isNotNull,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      container.dispose();
    },
  );

  testWidgets(
    'clear history confirmation can cancel and restart really clears scores and records',
    (tester) async {
      final data = buildSeedData();
      final container = await fixture.start(
        tester,
        data.copyWith(settings: data.settings.copyWith(ageConfirmed: true)),
      );
      container.read(appRouterProvider).push('/chat-data/thread_gu');
      await tester.pumpAndSettle();
      expect(find.text('重新开始这段关系'), findsOneWidget);
      await tester.tap(find.text('清空聊天记录'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(
        container.read(appControllerProvider).data.messages.length,
        data.messages.length,
      );
      await tester.tap(find.text('重新开始这段关系'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('确认重新开始'));
      await tester.pumpAndSettle();
      final result = container.read(appControllerProvider).data;
      expect(result.messages.where((m) => m.threadId == 'thread_gu'), isEmpty);
      expect(result.relationships.first.metrics['好感'], 12);
      expect(find.textContaining('0 条消息'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      container.dispose();
    },
  );

  testWidgets(
    'single thread clear is available from the message list action sheet',
    (tester) async {
      final data = buildSeedData();
      final container = await fixture.start(
        tester,
        data.copyWith(settings: data.settings.copyWith(ageConfirmed: true)),
      );
      final thread = data.threads.firstWhere(
        (item) => item.id == 'thread_shen',
      );
      final tile = find.text(thread.title);
      await tester.longPress(tile);
      await tester.pumpAndSettle();
      expect(find.text('清空单人物聊天记录'), findsOneWidget);
      await tester.tap(find.text('清空单人物聊天记录'));
      await tester.pumpAndSettle();
      expect(find.textContaining('清空与${thread.title}的聊天'), findsOneWidget);
      await tester.tap(find.text('清空聊天记录'));
      await tester.pumpAndSettle();
      final result = container.read(appControllerProvider).data;
      expect(result.messages.where((m) => m.threadId == thread.id), isEmpty);
      expect(
        result.relationships
            .firstWhere((r) => r.id == 'rel_shen')
            .metrics['好感'],
        61,
      );
      expect(result.characters.any((c) => c.id == 'char_shen'), isTrue);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      container.dispose();
    },
  );

  testWidgets('history search, select results and batch delete work together', (
    tester,
  ) async {
    final data = buildSeedData();
    final container = await fixture.start(
      tester,
      data.copyWith(settings: data.settings.copyWith(ageConfirmed: true)),
    );
    container.read(appRouterProvider).push('/chat-history/thread_gu');
    await tester.pumpAndSettle();
    final message = data.messages.firstWhere(
      (m) => m.threadId == 'thread_gu' && !m.fromAi,
    );
    await tester.enterText(find.byType(EditableText).first, message.text);
    await tester.pumpAndSettle();
    await tester.tap(find.text('多选'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('全选结果'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除（1）'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除选中消息'));
    await tester.pumpAndSettle();
    expect(
      container
          .read(appControllerProvider)
          .data
          .messages
          .any((m) => m.id == message.id),
      isFalse,
    );
    expect(find.text('没有找到匹配的消息'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    container.dispose();
  });

  for (final dark in [false, true]) {
    testWidgets(
      'editor validates blank input, displays save failure and retries in ${dark ? 'dark' : 'light'} mode',
      (tester) async {
        var shouldFail = true;
        var saved = '';
        await tester.pumpWidget(
          MaterialApp(
            theme: dark ? DtTheme.dark() : DtTheme.light(),
            home: Builder(
              builder: (context) => Scaffold(
                body: DtButton(
                  label: '打开编辑',
                  onPressed: () {
                    showDtEditSheet(
                      context: context,
                      title: '编辑消息',
                      description: '测试保存与重试',
                      initialText: '原文',
                      actionLabel: '保存修改',
                      onSubmit: (text) async {
                        if (shouldFail) throw StateError('存储暂不可用');
                        saved = text;
                      },
                    );
                  },
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('打开编辑'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(EditableText).last, '');
        await tester.pumpAndSettle();
        final save = tester.widget<DtButton>(
          find.widgetWithText(DtButton, '保存修改'),
        );
        expect(save.onPressed, isNull);
        await tester.enterText(find.byType(EditableText).last, '更正内容');
        await tester.pumpAndSettle();
        await tester.tap(find.text('保存修改'));
        await tester.pumpAndSettle();
        expect(find.text('存储暂不可用'), findsOneWidget);
        shouldFail = false;
        await tester.tap(find.text('保存修改'));
        await tester.pumpAndSettle();
        expect(saved, '更正内容');
        expect(find.byType(DtTextField), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'moment overflow supports real edit and preserves existing comments',
    (tester) async {
      final data = buildSeedData();
      final container = await fixture.start(
        tester,
        data.copyWith(settings: data.settings.copyWith(ageConfirmed: true)),
      );
      container.read(appRouterProvider).go('/moments');
      await tester.pumpAndSettle();
      final own = data.moments.firstWhere((m) => !m.fromAi);
      // Avoid depending on how many feed cards the small viewport initially lays out.
      await tester.scrollUntilVisible(
        find.text(own.content),
        180,
        scrollable: find.byType(Scrollable).last,
      );
      final card = find
          .ancestor(
            of: find.text(own.content),
            matching: find.byType(DtSurface),
          )
          .first;
      await tester.tap(
        find.descendant(of: card, matching: find.byTooltip('动态操作')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('编辑动态'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(EditableText).last, '今天换一种写法。');
      await tester.tap(find.text('保存修改'));
      await tester.pumpAndSettle();
      final changed = container
          .read(appControllerProvider)
          .data
          .moments
          .firstWhere((m) => m.id == own.id);
      expect(changed.content, '今天换一种写法。');
      expect(changed.comments, own.comments);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      container.dispose();
    },
  );
}
