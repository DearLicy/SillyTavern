part of 'app_controller.dart';

extension PromptManagement on AppController {
  List<RegexRule> _mergePresetRules(
    Object? rawRules,
    List<RegexRule> existing,
  ) {
    final merged = <RegexRule>[...existing];
    if (rawRules is! List) return merged;
    for (final entry in rawRules.whereType<Map>()) {
      final item = Map<String, dynamic>.from(entry);
      final name = (item['name'] as String?)?.trim() ?? '';
      final pattern = (item['pattern'] as String?)?.trim() ?? '';
      if (name.isEmpty || pattern.isEmpty) continue;
      merged.add(
        RegexRule(
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
          order: item['order'] is num ? (item['order'] as num).toInt() : 100,
        ),
      );
    }
    return merged;
  }

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
      newRules.add(
        RegexRule(
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
        ),
      );
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
    final provider = _snapshot.data.settings.provider;
    return jsonEncode({
      'name': name,
      'chat_completion_source': 'custom',
      'temperature': provider.temperature,
      'frequency_penalty': provider.frequencyPenalty,
      'presence_penalty': provider.presencePenalty,
      'top_p': provider.topP,
      if (provider.maxOutputTokens != null)
        'openai_max_tokens': provider.maxOutputTokens,
      'prompts': [
        {
          'identifier': 'main',
          'name': 'Main Prompt',
          'role': 'system',
          'content': prompts.systemPrefix,
          'system_prompt': true,
          'marker': false,
        },
        {
          'identifier': 'jailbreak',
          'name': 'Post-History Instructions',
          'role': 'system',
          'content': prompts.postHistoryInstructions,
          'system_prompt': true,
          'marker': false,
        },
      ],
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
    final existing = _snapshot.data.settings.prompts;
    if (const ChatCompletionPresetCodec().matches(map)) {
      final mergedRules = _mergePresetRules(map['rules'], existing.rules);
      final imported = const ChatCompletionPresetCodec().decode(
        map,
        existingRules: mergedRules,
      );
      final errors = RegexTransformer.validateAll(imported.prompts);
      if (errors.isNotEmpty) throw FormatException(errors.first);
      final before = _snapshot.data;
      if (_snapshot.generatingThreadId != null ||
          _activeGenerationAbort != null) {
        _stopActiveGeneration();
      }
      _cancelPendingSummaries();
      final provider = before.settings.provider.copyWith(
        temperature: imported.temperature,
        topP: imported.topP,
        frequencyPenalty: imported.frequencyPenalty,
        presencePenalty: imported.presencePenalty,
        maxOutputTokens: imported.maxOutputTokens,
        stopSequences: imported.stopSequences.isEmpty
            ? null
            : imported.stopSequences,
      );
      await _saveManagementChange(
        before,
        before.copyWith(
          settings: before.settings.copyWith(
            prompts: imported.prompts,
            provider: provider,
          ),
        ),
      );
      return;
    }
    final systemPrefix = map['systemPrefix'] is String
        ? map['systemPrefix'] as String
        : '';
    final postHistory = map['postHistoryInstructions'] is String
        ? map['postHistoryInstructions'] as String
        : '';
    final mergedRules = _mergePresetRules(map['rules'], existing.rules);
    final config = PromptConfig(
      systemPrefix: systemPrefix,
      postHistoryInstructions: postHistory,
      rules: mergedRules,
    );
    await savePromptConfig(config);
  }
}
