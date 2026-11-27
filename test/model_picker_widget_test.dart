import 'package:sillytavern_app/router/app_router.dart';
import 'package:sillytavern_app/domain/models.dart';
import 'package:sillytavern_app/ui/components/dt_model_picker.dart';
import 'package:sillytavern_app/ui/screens/about_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures/sample_data.dart';
import 'widget_test.dart' as shared;

void main() {
  testWidgets('provider save feedback never pops a subsequently opened page', (
    tester,
  ) async {
    final initial = buildSeedData();
    final container = await shared.start(
      tester,
      initial.copyWith(
        settings: initial.settings.copyWith(
          ageConfirmed: true,
          provider: const ProviderConfig(
            model: 'qa-model',
            models: ['qa-model'],
          ),
        ),
      ),
    );
    addTearDown(container.dispose);
    final router = container.read(appRouterProvider);
    router.push('/provider');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('保存'));
    await tester.tap(find.text('保存'));
    await tester.pump(const Duration(milliseconds: 1));
    router.push('/about');
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.byType(AboutPage), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  for (final dark in [false, true]) {
    testWidgets(
      'large model catalog searches and selects without overflow (${dark ? 'dark' : 'light'})',
      (tester) async {
        final initial = buildSeedData();
        final data = initial.copyWith(
          settings: initial.settings.copyWith(
            ageConfirmed: true,
            themeMode: dark ? AppThemeMode.dark : AppThemeMode.light,
          ),
        );
        final container = await shared.start(tester, data);
        addTearDown(container.dispose);
        final context = tester.element(find.byType(Scaffold).first);
        String? selected;
        final work = showDtModelPicker(
          context: context,
          models: [for (var i = 0; i < 1500; i++) 'model-$i'],
          names: const {'model-1499': '最终模型'},
          selected: 'model-0',
        ).then((v) => selected = v);
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('root-bottom-bar')), findsNothing);
        expect(find.text('显示 1500 / 1500 个模型'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('model-option-model-1499')),
          findsNothing,
        );
        await tester.enterText(find.byType(EditableText).last, '最终');
        await tester.pumpAndSettle();
        expect(find.text('显示 1 / 1500 个模型'), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('model-option-model-1499')));
        await tester.pumpAndSettle();
        await work;
        expect(selected, 'model-1499');
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets(
    'search handles empty results, clear, keyboard inset and cancellation',
    (tester) async {
      final initial = buildSeedData();
      final container = await shared.start(
        tester,
        initial.copyWith(
          settings: initial.settings.copyWith(ageConfirmed: true),
        ),
      );
      addTearDown(container.dispose);
      final context = tester.element(find.byType(Scaffold).first);
      final result = showDtModelPicker(
        context: context,
        models: const ['deepseek-alpha', 'other-model'],
        names: const {},
        selected: 'deepseek-alpha',
      );
      await tester.pumpAndSettle();
      tester.view.viewInsets = const FakeViewPadding(bottom: 320);
      addTearDown(tester.view.resetViewInsets);
      await tester.enterText(find.byType(EditableText).last, 'unmatched');
      await tester.pumpAndSettle();
      expect(find.text('没有匹配的模型，换个关键词试试'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('清除模型搜索'));
      await tester.pumpAndSettle();
      expect(find.text('显示 2 / 2 个模型'), findsOneWidget);
      await tester.tap(find.byTooltip('关闭模型选择'));
      await tester.pumpAndSettle();
      expect(await result, isNull);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
