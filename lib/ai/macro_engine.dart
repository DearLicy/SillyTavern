/// Bounded, deterministic macro expansion for chat-scoped variables.
///
/// Supported SillyTavern-compatible forms:
///   {{getvar::name}}          -> inserts the stored value (or empty)
///   {{setvar::name::value}}   -> stores value, renders nothing
///   {{addvar::name::value}}   -> appends value, renders nothing
///   {{incvar::name}}          -> numeric +1, renders nothing
///   {{decvar::name}}          -> numeric -1, renders nothing
///
/// This is plain text substitution. No scripts, reflection or remote calls are
/// executed, values cannot escape the per-thread variable map, and every input
/// and variable size is bounded.
class MacroResult {
  const MacroResult({
    required this.text,
    required this.variables,
    required this.changed,
  });

  final String text;
  final Map<String, String> variables;
  final bool changed;
}

class MacroEngine {
  const MacroEngine._();

  static const maxInputLength = 200000;
  static const maxVariables = 100;
  static const maxNameLength = 64;
  static const maxValueLength = 4000;

  static final RegExp _pattern = RegExp(
    r'\{\{\s*(getvar|setvar|addvar|incvar|decvar)\s*::\s*([^{}]*?)\s*\}\}',
    caseSensitive: false,
  );

  static MacroResult expand(String input, Map<String, String> initial) {
    final source = input;
    final variables = <String, String>{...initial};
    if (source.isEmpty || source.length > maxInputLength) {
      return MacroResult(text: source, variables: variables, changed: false);
    }

    var text = source;
    for (var pass = 0; pass < 4; pass++) {
      final before = text;
      text = text.replaceAllMapped(_pattern, (match) {
        final operation = (match.group(1) ?? '').toLowerCase();
        final body = match.group(2) ?? '';
        final parts = body.split('::');
        final name = parts.first.trim();
        if (name.isEmpty || name.length > maxNameLength) return '';
        final value = parts.length > 1 ? parts.sublist(1).join('::') : '';

        if (operation == 'getvar') {
          return variables[name] ?? '';
        }
        if (variables.length >= maxVariables && !variables.containsKey(name)) {
          return '';
        }
        if (operation == 'setvar') {
          variables[name] = _bounded(value);
        } else if (operation == 'addvar') {
          variables[name] = _bounded((variables[name] ?? '') + value);
        } else if (operation == 'incvar') {
          variables[name] = '${_asInt(variables[name]) + 1}';
        } else if (operation == 'decvar') {
          variables[name] = '${_asInt(variables[name]) - 1}';
        }
        return '';
      });
      if (text == before) break;
    }

    final changed = variables.length != initial.length ||
        variables.entries.any((entry) => initial[entry.key] != entry.value);
    return MacroResult(text: text, variables: variables, changed: changed);
  }

  static String _bounded(String value) =>
      value.length <= maxValueLength ? value : value.substring(0, maxValueLength);

  static int _asInt(String? value) => int.tryParse((value ?? '').trim()) ?? 0;
}
