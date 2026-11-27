import 'package:flutter_test/flutter_test.dart';
import 'package:sillytavern_app/ai/macro_engine.dart';
import 'package:sillytavern_app/domain/models.dart';

void main() {
  group('MacroEngine', () {
    test('getvar returns value or empty', () {
      final result = MacroEngine.expand(
        'A{{getvar::mood}}B{{getvar::missing}}C',
        {'mood': '放松'},
      );
      expect(result.text, 'A放松BC');
      expect(result.changed, isFalse);
    });

    test('setvar stores value and renders nothing', () {
      final result = MacroEngine.expand(
        'x{{setvar::place::旧城区}}y{{getvar::place}}',
        const {},
      );
      // getvar is resolved in the same expansion pass.
      expect(result.text, 'xy旧城区');
      expect(result.variables['place'], '旧城区');
      expect(result.changed, isTrue);
    });

    test('addvar appends and incvar/decvar adjust numbers', () {
      final result = MacroEngine.expand(
        '{{setvar::n::1}}{{incvar::n}}{{incvar::n}}{{decvar::n}}'
        '{{addvar::tag::a}}{{addvar::tag::b}}{{getvar::n}}-{{getvar::tag}}',
        const {},
      );
      expect(result.variables['n'], '2');
      expect(result.variables['tag'], 'ab');
      expect(result.text, '2-ab');
    });

    test('missing numbers default to zero', () {
      final result = MacroEngine.expand(
        '{{decvar::fresh}}{{getvar::fresh}}',
        const {},
      );
      expect(result.variables['fresh'], '-1');
      expect(result.text, '-1');
    });

    test('values are bounded', () {
      final longValue = List.filled(5000, 'a').join();
      final result = MacroEngine.expand(
        '{{setvar::big::$longValue}}{{getvar::big}}',
        const {},
      );
      expect(result.variables['big']!.length, MacroEngine.maxValueLength);
    });

    test('self-referencing value does not loop forever', () {
      final result = MacroEngine.expand(
        '{{setvar::loop::{{getvar::loop}}x}}{{getvar::loop}}',
        const {},
      );
      expect(result.variables['loop']!.length, lessThan(64));
    });

    test('case-insensitive operation names', () {
      final result = MacroEngine.expand(
        '{{SETVAR::a::1}}{{GetVar::a}}',
        const {},
      );
      expect(result.variables['a'], '1');
      expect(result.text, '1');
    });

    test('oversized input is returned untouched', () {
      final input = List.filled(MacroEngine.maxInputLength + 1, 'x').join();
      final result = MacroEngine.expand(input, const {});
      expect(result.text.length, input.length);
      expect(result.variables, isEmpty);
      expect(result.changed, isFalse);
    });
  });

  test('ChatThread persists macro variables through JSON', () {
    final thread = ChatThread(
      id: 't1',
      relationshipId: 'r1',
      type: ThreadType.direct,
      title: '测试',
      updatedAt: DateTime(2026, 1, 1),
      variables: const {'mood': '放松', 'count': '3'},
    );
    final decoded = ChatThread.fromJson(thread.toJson());
    expect(decoded.variables, {'mood': '放松', 'count': '3'});
  });
}
