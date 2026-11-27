import '../domain/models.dart';

/// Applies bounded, local regular-expression rules to prompt input or visible
/// AI output. Rules contain regex only; arbitrary scripts are never executed.
class RegexTransformer {
  const RegexTransformer._();

  static const maxPatternLength = 2048;
  static const maxReplacementLength = 8000;
  static const maxInputLength = 400000;
  static const maxOutputLength = 400000;

  static String apply(String text, PromptConfig config, RegexTarget target) {
    if (text.isEmpty || text.length > maxInputLength) return text;
    final rules =
        config.rules
            .where((rule) => rule.enabled && rule.target == target)
            .toList()
          ..sort((a, b) => a.order.compareTo(b.order));
    var result = text;
    for (final rule in rules) {
      final expression = _compile(rule);
      if (expression == null) continue;
      try {
        result = result.replaceAllMapped(
          expression,
          (match) => _expandReplacement(rule.replacement, match),
        );
      } catch (_) {
        continue;
      }
      if (result.length > maxOutputLength) {
        result = result.substring(0, maxOutputLength);
      }
    }
    return result;
  }

  static String? validate(RegexRule rule) {
    if (rule.pattern.trim().isEmpty) return '正则表达式不能为空';
    if (rule.pattern.length > maxPatternLength) return '正则表达式过长';
    if (rule.replacement.length > maxReplacementLength) return '替换内容过长';
    try {
      RegExp(
        rule.pattern,
        caseSensitive: rule.caseSensitive,
        multiLine: rule.multiline,
        dotAll: rule.dotAll,
      );
      return null;
    } on FormatException catch (error) {
      return '正则表达式无效：${error.message}';
    }
  }

  static List<String> validateAll(PromptConfig config) => [
    for (final rule in config.rules)
      if (validate(rule) case final error?) '${rule.name}：$error',
  ];

  static RegExp? _compile(RegexRule rule) {
    if (validate(rule) != null) return null;
    try {
      return RegExp(
        rule.pattern,
        caseSensitive: rule.caseSensitive,
        multiLine: rule.multiline,
        dotAll: rule.dotAll,
      );
    } catch (_) {
      return null;
    }
  }

  static String _expandReplacement(String template, Match match) {
    final output = StringBuffer();
    for (var index = 0; index < template.length; index++) {
      final current = template[index];
      if (current != r'$' || index + 1 >= template.length) {
        output.write(current);
        continue;
      }
      final next = template[index + 1];
      if (next == r'$') {
        output.write(r'$');
        index++;
        continue;
      }
      if (next == '&') {
        output.write(match.group(0) ?? '');
        index++;
        continue;
      }
      var start = index + 1;
      var end = start;
      if (next == '{') {
        start++;
        end = start;
        while (end < template.length && template[end] != '}') {
          end++;
        }
        if (end >= template.length) {
          output.write(current);
          continue;
        }
      }
      while (end < template.length && _isDigit(template.codeUnitAt(end))) {
        end++;
      }
      if (end == start) {
        output.write(current);
        continue;
      }
      final group = int.tryParse(template.substring(start, end));
      if (group == null || group > match.groupCount) {
        output.write(current);
        continue;
      }
      output.write(match.group(group) ?? '');
      index = next == '{' ? end : end - 1;
    }
    return output.toString();
  }

  static bool _isDigit(int codeUnit) => codeUnit >= 48 && codeUnit <= 57;
}
