import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';

import '../../application/app_controller.dart';
import '../../ai/ai_client.dart';
import '../../domain/models.dart';
import '../components/dt_controls.dart';
import '../components/dt_detail_page.dart';
import '../components/dt_input.dart';
import '../components/dt_model_picker.dart';

class ProviderPage extends ConsumerStatefulWidget {
  const ProviderPage({super.key});
  @override
  ConsumerState<ProviderPage> createState() => _ProviderPageState();
}

class _ProviderPageState extends ConsumerState<ProviderPage> {
  late final TextEditingController _baseUrl;
  final _apiKey = TextEditingController();
  final _maxOutputTokens = TextEditingController();
  final _frequencyPenalty = TextEditingController();
  final _presencePenalty = TextEditingController();
  final _stopSequences = TextEditingController();
  late ProviderKind _kind;
  late bool _remember;
  late List<String> _models;
  late String _model;
  late double _temperature;
  late double _topP;
  final _names = <String, String>{};
  bool _obscure = true, _fetching = false;
  DtButtonStatus _saveStatus = DtButtonStatus.idle;
  String? _error;
  int _request = 0;

  @override
  void initState() {
    super.initState();
    final provider = ref.read(appControllerProvider).data.settings.provider;
    _baseUrl = TextEditingController(text: provider.baseUrl);
    _kind = provider.kind;
    _remember = provider.rememberKey;
    _temperature = provider.temperature;
    _topP = provider.topP;
    _maxOutputTokens.text = provider.maxOutputTokens?.toString() ?? '';
    _frequencyPenalty.text = provider.frequencyPenalty == 0
        ? ''
        : '${provider.frequencyPenalty}';
    _presencePenalty.text = provider.presencePenalty == 0
        ? ''
        : '${provider.presencePenalty}';
    _stopSequences.text = provider.stopSequences.join('\n');
    _models = List.of(provider.models);
    // Older saved ids are retained; fresh installations always start empty.
    if (_models.isEmpty && provider.model.isNotEmpty) {
      _models.add(provider.model);
    }
    _model = provider.model;
    _baseUrl.addListener(_invalidateModels);
    _apiKey.addListener(_invalidateModels);
  }

  void _invalidateModels() {
    _request++;
    setState(() {
      _models = [];
      _names.clear();
      _model = '';
      _error = null;
      _fetching = false;
    });
  }

  ProviderConfig get _config => ProviderConfig(
    kind: _kind,
    baseUrl: _baseUrl.text.trim(),
    model: _model,
    models: _models,
    rememberKey: _remember,
    temperature: _temperature.clamp(0, 2),
    topP: _topP.clamp(0, 1),
    frequencyPenalty: _parseDouble(_frequencyPenalty.text, -2, 2),
    presencePenalty: _parseDouble(_presencePenalty.text, -2, 2),
    maxOutputTokens: switch (int.tryParse(_maxOutputTokens.text.trim())) {
      final int value when value > 0 => value.clamp(1, 131072),
      _ => null,
    },
    stopSequences: _stopSequences.text
        .split(RegExp(r'[\n，]'))
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .take(4)
        .toList(),
  );

  double _parseDouble(String value, double min, double max) {
    final parsed = double.tryParse(value.trim()) ?? 0;
    return parsed.clamp(min, max);
  }

  Future<void> _fetchModels() async {
    if (_fetching) return;
    final request = ++_request;
    setState(() {
      _fetching = true;
      _error = null;
    });
    try {
      final models = await ref
          .read(appControllerProvider.notifier)
          .fetchProviderModels(config: _config, apiKey: _apiKey.text.trim());
      if (!mounted || request != _request) return;
      setState(() {
        _models = models.map((e) => e.id).toList();
        _names.addEntries(models.map((e) => MapEntry(e.id, e.name)));
        if (!_models.contains(_model)) _model = _models.first;
      });
    } catch (error) {
      if (!mounted || request != _request) return;
      setState(() {
        _error = error is AiClientException
            ? error.message
            : (kIsWeb ? '无法连接供应商。请检查地址、网络及 CORS 设置。' : '无法连接供应商，请检查地址和网络后重试。');
      });
    } finally {
      if (mounted && request == _request) setState(() => _fetching = false);
    }
  }

  Future<void> _save() async {
    if (_models.isEmpty || !_models.contains(_model)) {
      setState(() => _error = '请先拉取模型，再选择一个默认模型');
      return;
    }
    setState(() {
      _saveStatus = DtButtonStatus.loading;
      _error = null;
    });
    try {
      await ref
          .read(appControllerProvider.notifier)
          .saveProvider(
            config: _config,
            apiKey: _apiKey.text.trim().isEmpty ? null : _apiKey.text.trim(),
          );
      if (!mounted) return;
      setState(() => _saveStatus = DtButtonStatus.success);
      await Future<void>.delayed(const Duration(milliseconds: 300));
      if (mounted && ModalRoute.of(context)?.isCurrent == true) {
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/');
        }
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _saveStatus = DtButtonStatus.idle;
          _error = error is AiClientException ? error.message : '保存失败，请重试';
        });
      }
    }
  }

  Future<void> _pickModel() async {
    final picked = await showDtModelPicker(
      context: context,
      models: _models,
      names: _names,
      selected: _model,
    );
    if (picked != null && mounted) setState(() => _model = picked);
  }

  @override
  void dispose() {
    _request++;
    _baseUrl.dispose();
    _apiKey.dispose();
    _maxOutputTokens.dispose();
    _frequencyPenalty.dispose();
    _presencePenalty.dispose();
    _stopSequences.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appControllerProvider);
    final busy = _saveStatus != DtButtonStatus.idle;
    return DtDetailPage(
      title: '模型与供应商',
      subtitle: '默认接入 DeepSeek 官方',
      bottom: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: DtButton(
            label: '保存',
            status: _saveStatus,
            loadingText: '正在保存…',
            successText: '已保存',
            onPressed: _fetching ? null : _save,
          ),
        ),
      ),
      child: AbsorbPointer(
        absorbing: busy,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            DtSurface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '连接设置',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  DtSegmentedControl(
                    labels: const ['OpenAI 兼容', 'Anthropic'],
                    index: _kind == ProviderKind.anthropic ? 1 : 0,
                    onChanged: (index) {
                      _kind = index == 0
                          ? ProviderKind.openaiCompatible
                          : ProviderKind.anthropic;
                      _invalidateModels();
                    },
                  ),
                  const SizedBox(height: 16),
                  DtTextField(
                    controller: _baseUrl,
                    keyboardType: TextInputType.url,
                    autocorrect: false,
                    decoration: const InputDecoration(
                      labelText: '供应商地址',
                      hintText: 'https://api.deepseek.com',
                    ),
                  ),
                  const SizedBox(height: 16),
                  DtTextField(
                    controller: _apiKey,
                    obscureText: _obscure,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: InputDecoration(
                      labelText: state.hasApiKey
                          ? (_config.sharesCredentialScopeWith(
                                  state.data.settings.provider,
                                )
                                ? 'API Key（留空保留已保存密钥）'
                                : 'API Key（新供应商需重新填写）')
                          : 'API Key',
                      hintText: '粘贴你的密钥',
                      suffixIcon: DtIconButton(
                        icon: _obscure ? FIcons.eye : FIcons.eyeOff,
                        tooltip: '切换密钥可见性',
                        onTap: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Expanded(
                        child: Text('记住密钥', style: TextStyle(fontSize: 14)),
                      ),
                      FSwitch(
                        value: _remember,
                        onChange: (value) => setState(() => _remember = value),
                      ),
                    ],
                  ),
                  Text(
                    kIsWeb
                        ? '关闭时仅保留在本标签页；开启后保存到浏览器。'
                        : '关闭时仅保留在本次会话；开启后保存到系统安全存储。',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF777A85),
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            DtButton(
              label: '拉取模型',
              variant: DtButtonVariant.secondary,
              status: _fetching ? DtButtonStatus.loading : DtButtonStatus.idle,
              loadingText: '正在拉取…',
              icon: FIcons.refreshCw,
              onPressed: _fetchModels,
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  _error!,
                  key: const ValueKey('provider-error'),
                  style: const TextStyle(
                    color: Color(0xFFD95E58),
                    height: 1.5,
                    fontSize: 13,
                  ),
                ),
              ),
            const SizedBox(height: 16),
            DtSurface(
              padding: EdgeInsets.zero,
              child: DtSettingRow(
                icon: FIcons.box,
                title: '默认模型',
                subtitle: _model.isEmpty
                    ? '拉取后点击选择，无需手填'
                    : (_names[_model] ?? _model),
                onTap: _models.isEmpty ? null : _pickModel,
              ),
            ),
            const SizedBox(height: 16),
            DtSurface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '生成参数',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    '这些参数按供应商原样发送；不支持的供应商可能忽略或拒绝，出现错误时恢复默认值再试。',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.5,
                      color: Color(0xFF777A85),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _ProviderSlider(
                    title: '温度',
                    value: _temperature,
                    min: 0,
                    max: 2,
                    format: (value) => value.toStringAsFixed(2),
                    hint: '越高越发散，角色聊天建议 0.7–1.0。',
                    onChanged: (value) => setState(() => _temperature = value),
                  ),
                  const SizedBox(height: 12),
                  _ProviderSlider(
                    title: 'Top P',
                    value: _topP,
                    min: 0,
                    max: 1,
                    format: (value) => value.toStringAsFixed(2),
                    hint: '1 表示不额外截断候选词；通常无需和温度同时调低。',
                    onChanged: (value) => setState(() => _topP = value),
                  ),
                  const SizedBox(height: 12),
                  DtTextField(
                    controller: _maxOutputTokens,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '最大输出 Token',
                      hintText: '留空自动',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DtTextField(
                          controller: _frequencyPenalty,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                            signed: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: '频率惩罚',
                            hintText: '0',
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DtTextField(
                          controller: _presencePenalty,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                            signed: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: '存在惩罚',
                            hintText: '0',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  DtTextField(
                    controller: _stopSequences,
                    minLines: 1,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: '停止序列',
                      hintText: '每行一个，最多 4 个',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '聊天请求直接发送给你选择的供应商。图片会作为真实多模态输入，需选择支持识图的模型。搜索、OCR 和语音可单独配置 DeepSeek 官方 Key，与第三方聊天同时使用。SillyTavern 不托管密钥或聊天内容。',
              style: TextStyle(
                fontSize: 12,
                height: 1.6,
                color: Color(0xFF777A85),
              ),
            ),
            DtSettingRow(
              icon: FIcons.mic,
              title: '搜索与语音',
              subtitle: '独立配置官方工具密钥',
              onTap: () => context.push('/tools'),
            ),
            if (state.hasApiKey)
              Padding(
                padding: const EdgeInsets.only(top: 20),
                child: DtButton(
                  label: '清除已保存的密钥',
                  variant: DtButtonVariant.ghost,
                  onPressed: () async {
                    await ref
                        .read(appControllerProvider.notifier)
                        .clearProviderKey();
                    if (mounted) setState(() => _error = null);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ProviderSlider extends StatelessWidget {
  const _ProviderSlider({
    required this.title,
    required this.value,
    required this.min,
    required this.max,
    required this.format,
    required this.hint,
    required this.onChanged,
  });

  final String title;
  final double value;
  final double min;
  final double max;
  final String Function(double value) format;
  final String hint;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final selected = value.clamp(min, max);
    final normalized = max == min ? 0.0 : (selected - min) / (max - min);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            Text(
              format(selected),
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        FSlider(
          controller: null,
          initialSelection: FSliderSelection(max: normalized),
          onChange: (selection) {
            onChanged(min + (max - min) * selection.offset.max);
          },
        ),
        Text(
          hint,
          style: TextStyle(
            fontSize: 10.5,
            height: 1.4,
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF7F889C)
                : const Color(0xFF8C95A7),
          ),
        ),
      ],
    );
  }
}
