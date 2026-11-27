part of 'app_controller.dart';

extension PromptManagement on AppController {
  Future<void> savePromptConfig(PromptConfig config) async {
    final errors = RegexTransformer.validateAll(config);
    if (errors.isNotEmpty) throw FormatException(errors.first);
    final before = _snapshot.data;
    if (_snapshot.generatingThreadId != null ||
        _activeGenerationAbort != null) {
      _stopActiveGeneration();
    }
    _cancelPendingSummaries();
    await _saveManagementChange(
      before,
      before.copyWith(settings: before.settings.copyWith(prompts: config)),
    );
  }

  /// Export all regex scripts as SillyTavern-format JSON string.
  String exportRegexScripts() {
    final rules = _snapshot.data.settings.prompts.rules;
    final scripts = [
      for (final rule in rules)
        {
          'name': rule.name,
          'pattern': rule.pattern,
          'replacement': rule.replacement,
          'target': rule.target.name,
          'enabled': rule.enabled,
          'caseSensitive': rule.caseSensitive,
          'multiline': rule.multiline,
          'dotAll': rule.dotAll,
          'order': rule.order,
        },
    ];
    return jsonEncode({'scripts': scripts});
  }

  /// Import SillyTavern-format regex scripts from JSON string.
  /// Only enabled rules are added; disabled scripts are silently skipped.
  Future<void> importRegexScripts(String raw) async {
    final decoded = jsonDecode(raw.trim());
    if (decoded is! Map || !decoded.containsKey('scripts')) {
      throw FormatException('无效的脚本格式');
    }
    final rawScripts = decoded['scripts'] as List;
    final newRules = <RegexRule>[];
    for (final entry in rawScripts.whereType<Map>()) {
      final map = Map<String, dynamic>.from(entry);
      final name = (map['name'] as String?)?.trim() ?? '';
      final pattern = (map['pattern'] as String?)?.trim() ?? '';
      final replacement = (map['replacement'] as String?) ?? '';
      if (name.isEmpty || pattern.isEmpty) continue;
      final enabled = map['enabled'] as bool? ?? true;
      if (!enabled) continue;
      final targetName = (map['target'] as String?) ?? 'userInput';
      final target = RegexTarget.values.firstWhere(
        (e) => e.name == targetName,
        orElse: () => RegexTarget.userInput,
      );
      newRules.add(RegexRule(
        id: 'regex_${_uuid.v4()}',
        name: name,
        pattern: pattern,
        replacement: replacement,
        target: target,
        enabled: enabled,
        caseSensitive: map['caseSensitive'] as bool? ?? false,
        multiline: map['multiline'] as bool? ?? true,
        dotAll: map['dotAll'] as bool? ?? true,
        order: map['order'] as int? ?? 100,
      ));
    }
    if (newRules.isEmpty) throw FormatException('未找到有效的正则脚本');
    final before = _snapshot.data;
    final config = before.settings.prompts.copyWith(
      rules: [...before.settings.prompts.rules, ...newRules],
    );
    await savePromptConfig(config);
  }
}
