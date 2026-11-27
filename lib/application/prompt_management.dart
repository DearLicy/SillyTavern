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

  /// Export the current prompt configuration as a shareable preset JSON.
  String exportPromptPreset({String name = 'SillyTavern APP 预设'}) {
    final prompts = _snapshot.data.settings.prompts;
    return jsonEncode({
      'name': name,
      'systemPrefix': prompts.systemPrefix,
      'postHistoryInstructions': prompts.postHistoryInstructions,
      'rules': [
        for (final rule in prompts.rules)
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
      ],
    });
  }

  /// Import a prompt preset. Replaces the system prompt and post-history
  /// instructions; merges any preset rules after existing rules.
  Future<void> importPromptPreset(String raw) async {
    final decoded = jsonDecode(raw.trim());
    if (decoded is! Map) throw FormatException('预设必须是 JSON 对象');
    final map = Map<String, dynamic>.from(decoded);
    final systemPrefix = map['systemPrefix'] is String
        ? map['systemPrefix'] as String
        : '';
    final postHistory = map['postHistoryInstructions'] is String
        ? map['postHistoryInstructions'] as String
        : '';
    final existing = _snapshot.data.settings.prompts;
    final mergedRules = <RegexRule>[...existing.rules];
    final rawRules = map['rules'];
    if (rawRules is List) {
      for (final entry in rawRules.whereType<Map>()) {
        final item = Map<String, dynamic>.from(entry);
        final name = (item['name'] as String?)?.trim() ?? '';
        final pattern = (item['pattern'] as String?)?.trim() ?? '';
        if (name.isEmpty || pattern.isEmpty) continue;
        mergedRules.add(RegexRule(
          id: 'regex_${_uuid.v4()}',
          name: name,
          pattern: pattern,
          replacement: item['replacement'] is String
              ? item['replacement'] as String
              : '',
          target: RegexTarget.values.firstWhere(
            (e) => e.name == item['target'],
            orElse: () => RegexTarget.aiOutput,
          ),
          enabled: item['enabled'] as bool? ?? true,
          caseSensitive: item['caseSensitive'] as bool? ?? false,
          multiline: item['multiline'] as bool? ?? true,
          dotAll: item['dotAll'] as bool? ?? true,
          order: item['order'] as int? ?? 100,
        ));
      }
    }
    final config = PromptConfig(
      systemPrefix: systemPrefix,
      postHistoryInstructions: postHistory,
      rules: mergedRules,
    );
    await savePromptConfig(config);
  }
}
