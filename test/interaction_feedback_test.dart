import 'package:sillytavern_app/ui/components/dt_controls.dart';
import 'package:sillytavern_app/ui/components/dt_motion.dart';
import 'package:sillytavern_app/ui/theme/dt_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('press feedback fades content without scaling it', (
    tester,
  ) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: DtTheme.light(),
        home: Scaffold(
          body: Center(
            child: DtPressable(
              onTap: () => tapped = true,
              child: const SizedBox(
                key: ValueKey('press-content'),
                width: 120,
                height: 52,
              ),
            ),
          ),
        ),
      ),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('press-content'))),
    );
    await tester.pump(const Duration(milliseconds: 10));
    await tester.pump();

    final pressed = tester.widget<AnimatedOpacity>(
      find.descendant(
        of: find.byType(DtPressable),
        matching: find.byType(AnimatedOpacity),
      ),
    );
    expect(pressed.opacity, 0.68);
    expect(
      find.descendant(
        of: find.byType(DtPressable),
        matching: find.byType(AnimatedScale),
      ),
      findsNothing,
    );

    await gesture.up();
    await tester.pump(const Duration(milliseconds: 10));
    await tester.pump();
    final released = tester.widget<AnimatedOpacity>(
      find.descendant(
        of: find.byType(DtPressable),
        matching: find.byType(AnimatedOpacity),
      ),
    );
    expect(released.opacity, 1);
    expect(tapped, isTrue);
  });

  testWidgets('button exposes loading and success variants', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: DtTheme.light(),
        home: Scaffold(
          body: DtButton(
            label: '保存',
            loadingText: '正在保存…',
            successText: '已保存',
            status: DtButtonStatus.loading,
            onPressed: () {},
          ),
        ),
      ),
    );
    expect(find.text('正在保存…'), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        theme: DtTheme.light(),
        home: Scaffold(
          body: DtButton(
            label: '保存',
            loadingText: '正在保存…',
            successText: '已保存',
            status: DtButtonStatus.success,
            onPressed: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('已保存'), findsOneWidget);
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
  });
}
