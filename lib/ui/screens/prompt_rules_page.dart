import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:uuid/uuid.dart';

import '../../ai/regex_transformer.dart';
import '../../application/app_controller.dart';
import '../../domain/models.dart';
import '../components/dt_controls.dart';
import '../components/dt_detail_page.dart';
import '../components/dt_input.dart';
import '../theme/dt_theme.dart';

class PromptRulesPage extends ConsumerStatefulWidget {
  const PromptRulesPage({super.key});

  @override
  ConsumerState<PromptRulesPage> createState() => _PromptRulesPageState();
}

class _PromptRulesPageState extends ConsumerState<PromptRulesPage> {
  late final TextEditingController _systemPrompt;
  late final TextEditingController _postHistory;
  late List<RegexRule> _rules;
  DtButtonStatus _status = DtButtonStatus.idle;
  String? _error;

  @override
  void initState() {
    super.initState();
    final prompts = ref.read(appControllerProvider).data.settings.prompts;
    _systemPrompt = TextEditingController(text: prompts.systemPrefix);
    _postHistory = TextEditingController(text: prompts.postHistoryInstructions);
    _rules = [...prompts.rules];
  }

  @override
  void dispose() {
    _systemPrompt.dispose();
    _postHistory.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _status = DtButtonStatus.loading;
      _error = null;
    });
    try {
      await ref
          .read(appControllerProvider.notifier)
          .savePromptConfig(
            PromptConfig(
              systemPrefix: _systemPrompt.text,
              postHistoryInstructions: _postHistory.text,
              rules: _rules,
            ),
          );
      if (!mounted) return;
      setState(() => _status = DtButtonStatus.success);
      await Future<void>.delayed(const Duration(milliseconds: 300));
      if (mounted) Navigator.of(context).maybePop();
    } catch (error) {
      if (!mounted) return;
      final message = error is FormatException
          ? error.message
          : '提示词规则保存失败，请检查正则表达式。';
      setState(() {
        _status = DtButtonStatus.idle;
        _error = message;
      });
      messenger.showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _editRule(RegexRule? existing) async {
    final result = await Navigator.of(context).push<RegexRule>(
      MaterialPageRoute<RegexRule>(
        builder: (_) => PromptRuleEditorPage(existing: existing),
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      if (existing == null) {
        _rules.add(result);
      } else {
        _rules = [
          for (final rule in _rules) rule.id == result.id ? result : rule,
        ];
      }
    });
  }

  Future<void> _importPreset() async {
    final controller = ref.read(appControllerProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);
    final pasted = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        final textController = TextEditingController();
        return AlertDialog(
          title: const Text('导入提示词预设'),
          content: TextField(
            controller: textController,
            maxLines: 10,
            decoration: const InputDecoration(
              hintText: '粘贴包含 systemPrefix / rules 的 JSON',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, textController.text),
              child: const Text('导入'),
            ),
          ],
        );
      },
    );
    if (pasted == null || pasted.trim().isEmpty) return;
    try {
      await controller.importPromptPreset(pasted);
      if (!mounted) return;
      final prompts = ref.read(appControllerProvider).data.settings.prompts;
      setState(() {
        _systemPrompt.text = prompts.systemPrefix;
        _postHistory.text = prompts.postHistoryInstructions;
        _rules = [...prompts.rules];
        _error = null;
      });
      messenger.showSnackBar(const SnackBar(content: Text('预设已导入')));
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            error is FormatException ? error.message : '预设导入失败：$error',
          ),
        ),
      );
    }
  }

  Future<void> _exportPreset() async {
    final controller = ref.read(appControllerProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final json = controller.exportPromptPreset();
      await Clipboard.setData(ClipboardData(text: json));
      messenger.showSnackBar(const SnackBar(content: Text('提示词预设 JSON 已复制')));
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text('预设导出失败：$error')));
    }
  }

  Future<void> _importScripts() async {
    final controller = ref.read(appControllerProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);
    final pasted = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        final textController = TextEditingController();
        return AlertDialog(
          title: const Text('导入 SillyTavern 正则脚本'),
          content: TextField(
            controller: textController,
            maxLines: 10,
            decoration: const InputDecoration(
              hintText: '粘贴包含 scripts 数组的 JSON',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, textController.text),
              child: const Text('导入'),
            ),
          ],
        );
      },
    );
    if (pasted == null || pasted.trim().isEmpty) return;
    try {
      await controller.importRegexScripts(pasted);
      if (!mounted) return;
      final rules = ref.read(appControllerProvider).data.settings.prompts.rules;
      setState(() {
        _rules = [...rules];
        _error = null;
      });
      messenger.showSnackBar(const SnackBar(content: Text('正则脚本已导入')));
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            error is FormatException ? error.message : '导入失败：$error',
          ),
        ),
      );
    }
  }

  Future<void> _exportScripts() async {
    final controller = ref.read(appControllerProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final json = controller.exportRegexScripts();
      await Clipboard.setData(ClipboardData(text: json));
      messenger.showSnackBar(const SnackBar(content: Text('正则脚本 JSON 已复制')));
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text('导出失败：$error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final sorted = [..._rules]..sort((a, b) => a.order.compareTo(b.order));
    return DtDetailPage(
      title: '提示词与正则',
      subtitle: '本地规则，不执行脚本或远程代码',
      bottom: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: DtButton(
            label: '保存提示词规则',
            status: _status,
            loadingText: '正在验证并保存…',
            successText: '已保存',
            onPressed: _save,
          ),
        ),
      ),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DtSurface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '全局系统提示词',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                const Text(
                  '用于长期写作风格和角色表达。安全规则、用户边界与本轮纠正始终优先，不能被这里覆盖。',
                  style: TextStyle(fontSize: 12, height: 1.6),
                ),
                const SizedBox(height: 10),
                DtTextField(
                  controller: _systemPrompt,
                  minLines: 4,
                  maxLines: 10,
                  decoration: const InputDecoration(
                    hintText: '例如：保持克制的第三人称有限视角，避免客服腔。',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          DtSurface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '后置指令',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                const Text(
                  '在历史和最终回应前追加，只用于控制表达方式与格式。',
                  style: TextStyle(fontSize: 12, height: 1.6),
                ),
                const SizedBox(height: 10),
                DtTextField(
                  controller: _postHistory,
                  minLines: 3,
                  maxLines: 8,
                  decoration: const InputDecoration(
                    hintText: '例如：不要总结旧对话，不长篇解释。',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          DtSurface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '提示词预设',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                const Text(
                  '支持 SillyTavern Chat Completion 预设；会映射主提示词、辅助提示词、后置指令和常用生成参数，并合并本地正则规则。',
                  style: TextStyle(fontSize: 12, height: 1.6),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: DtButton(
                        label: '导入预设',
                        variant: DtButtonVariant.secondary,
                        onPressed: _importPreset,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DtButton(
                        label: '导出预设',
                        variant: DtButtonVariant.secondary,
                        onPressed: _exportPreset,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Expanded(
                child: Text(
                  '正则变换',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
              DtIconButton(
                icon: Icons.file_download_outlined,
                tooltip: '导入 ST 正则脚本',
                onTap: _importScripts,
              ),
              DtIconButton(
                icon: Icons.ios_share_rounded,
                tooltip: '导出 ST 正则脚本',
                onTap: _exportScripts,
              ),
              DtIconButton(
                icon: Icons.add_rounded,
                tooltip: '新增正则规则',
                onTap: () => _editRule(null),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (sorted.isEmpty)
            const DtSurface(
              child: Text(
                r'还没有规则。可分别处理用户输入或 AI 输出，支持 $1 等标准替换引用。',
                style: TextStyle(fontSize: 13, height: 1.6),
              ),
            )
          else
            for (final rule in sorted)
              Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: DtSurface(
                  child: DtSettingRow(
                    icon: Icons.code_rounded,
                    title: rule.name,
                    subtitle:
                        '${rule.target.label} · ${rule.enabled ? '启用' : '停用'} · ${rule.pattern}',
                    trailing: FSwitch(
                      value: rule.enabled,
                      onChange: (value) => setState(() {
                        _rules = [
                          for (final item in _rules)
                            item.id == rule.id
                                ? item.copyWith(enabled: value)
                                : item,
                        ];
                      }),
                    ),
                    onTap: () => _editRule(rule),
                  ),
                ),
              ),
          const SizedBox(height: 10),
          const Text(
            '规则只在本机执行正则替换，不运行 JavaScript、Shell、网络请求或角色卡内脚本。',
            style: TextStyle(
              fontSize: 12,
              height: 1.6,
              color: DtColors.textSecondary,
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                _error!,
                key: const ValueKey('prompt-rule-error'),
                style: const TextStyle(
                  fontSize: 13,
                  color: DtColors.coral,
                  height: 1.5,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class PromptRuleEditorPage extends StatefulWidget {
  const PromptRuleEditorPage({super.key, this.existing});

  final RegexRule? existing;

  @override
  State<PromptRuleEditorPage> createState() => _PromptRuleEditorPageState();
}

class _PromptRuleEditorPageState extends State<PromptRuleEditorPage> {
  late final _name = TextEditingController(
    text: widget.existing?.name ?? '新的正则规则',
  );
  late final _pattern = TextEditingController(text: widget.existing?.pattern);
  late final _replacement = TextEditingController(
    text: widget.existing?.replacement,
  );
  late final _order = TextEditingController(
    text: '${widget.existing?.order ?? 100}',
  );
  late RegexTarget _target = widget.existing?.target ?? RegexTarget.aiOutput;
  late bool _enabled = widget.existing?.enabled ?? true;
  late bool _caseSensitive = widget.existing?.caseSensitive ?? false;
  late bool _multiline = widget.existing?.multiline ?? true;
  late bool _dotAll = widget.existing?.dotAll ?? true;

  @override
  void dispose() {
    _name.dispose();
    _pattern.dispose();
    _replacement.dispose();
    _order.dispose();
    super.dispose();
  }

  void _save() {
    final rule = RegexRule(
      id: widget.existing?.id ?? 'regex_${const Uuid().v4()}',
      name: _name.text.trim().isEmpty ? '未命名规则' : _name.text.trim(),
      pattern: _pattern.text,
      replacement: _replacement.text,
      target: _target,
      enabled: _enabled,
      caseSensitive: _caseSensitive,
      multiline: _multiline,
      dotAll: _dotAll,
      order: int.tryParse(_order.text.trim()) ?? 100,
    );
    final error = RegexTransformer.validate(rule);
    if (error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    Navigator.of(context).pop(rule);
  }

  @override
  Widget build(BuildContext context) {
    return DtDetailPage(
      title: widget.existing == null ? '新增正则规则' : '编辑正则规则',
      subtitle: '只做本地正则替换',
      bottom: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: DtButton(label: '保存规则', successText: '已保存', onPressed: _save),
        ),
      ),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DtSurface(
            child: Column(
              children: [
                DtTextField(
                  controller: _name,
                  decoration: const InputDecoration(labelText: '规则名称'),
                ),
                const SizedBox(height: 12),
                DtTextField(
                  controller: _pattern,
                  minLines: 2,
                  maxLines: 6,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: const InputDecoration(
                    labelText: '正则表达式',
                    hintText: r'例如：\*([^*]+)\*',
                  ),
                ),
                const SizedBox(height: 12),
                DtTextField(
                  controller: _replacement,
                  minLines: 2,
                  maxLines: 6,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: const InputDecoration(
                    labelText: '替换为',
                    hintText: r'例如：*$1*',
                  ),
                ),
                const SizedBox(height: 12),
                DtTextField(
                  controller: _order,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: '执行顺序'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          DtSurface(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                DtSettingRow(
                  icon: Icons.swap_horiz_rounded,
                  title: '作用位置',
                  subtitle: _target.label,
                  trailing: SizedBox(
                    width: 145,
                    child: FSelect<RegexTarget>(
                      items: const {
                        '用户输入': RegexTarget.userInput,
                        'AI 输出': RegexTarget.aiOutput,
                      },
                      initialValue: _target,
                      onChange: (value) {
                        if (value != null) setState(() => _target = value);
                      },
                    ),
                  ),
                ),
                const Divider(indent: 62),
                _FlagRow(
                  title: '区分大小写',
                  value: _caseSensitive,
                  onChanged: (value) => setState(() => _caseSensitive = value),
                ),
                const Divider(indent: 62),
                _FlagRow(
                  title: '多行模式',
                  value: _multiline,
                  onChanged: (value) => setState(() => _multiline = value),
                ),
                const Divider(indent: 62),
                _FlagRow(
                  title: '点号匹配换行',
                  value: _dotAll,
                  onChanged: (value) => setState(() => _dotAll = value),
                ),
                const Divider(indent: 62),
                _FlagRow(
                  title: '启用规则',
                  value: _enabled,
                  onChanged: (value) => setState(() => _enabled = value),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            r'替换内容支持标准捕获组引用，例如 $1、$2。表达式和输出长度都有上限，避免误操作造成无限文本。',
            style: TextStyle(
              fontSize: 12,
              height: 1.6,
              color: DtColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _FlagRow extends StatelessWidget {
  const _FlagRow({
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return DtSettingRow(
      icon: Icons.tune_rounded,
      title: title,
      trailing: FSwitch(value: value, onChange: onChanged),
      onTap: null,
    );
  }
}
