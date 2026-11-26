import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';

import '../../ai/ai_client.dart';
import '../../application/app_controller.dart';
import '../../domain/models.dart';
import '../components/dt_controls.dart';
import '../components/dt_detail_page.dart';
import '../components/dt_input.dart';
import '../theme/dt_theme.dart';

class ToolSettingsPage extends ConsumerStatefulWidget {
  const ToolSettingsPage({super.key});

  @override
  ConsumerState<ToolSettingsPage> createState() => _ToolSettingsPageState();
}

class _ToolSettingsPageState extends ConsumerState<ToolSettingsPage> {
  final _key = TextEditingController();
  late bool _useChatKey, _remember;
  bool _obscure = true, _clearing = false;
  DtButtonStatus _status = DtButtonStatus.idle;
  String? _error;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(appControllerProvider).data.settings;
    _useChatKey =
        settings.tools.useChatKey && settings.provider.isOfficialDeepSeek;
    _remember = settings.tools.rememberKey;
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _status = DtButtonStatus.loading;
      _error = null;
    });
    try {
      await ref
          .read(appControllerProvider.notifier)
          .saveToolConfig(
            config: DeepSeekToolConfig(
              useChatKey: _useChatKey,
              rememberKey: _remember,
            ),
            apiKey: _key.text,
          );
      if (!mounted) return;
      _key.clear();
      setState(() => _status = DtButtonStatus.success);
      await Future<void>.delayed(const Duration(milliseconds: 300));
      if (mounted && ModalRoute.of(context)?.isCurrent == true) {
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/settings');
        }
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _status = DtButtonStatus.idle;
          _error = error is AiClientException ? error.message : '保存失败，请重试。';
        });
      }
    }
  }

  Future<void> _clear() async {
    setState(() {
      _clearing = true;
      _error = null;
    });
    try {
      await ref.read(appControllerProvider.notifier).clearToolKey();
      if (!mounted) return;
      _key.clear();
    } catch (_) {
      if (mounted) setState(() => _error = '清除失败，请重试。');
    } finally {
      if (mounted) setState(() => _clearing = false);
    }
  }

  @override
  void dispose() {
    _key.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appControllerProvider);
    final busy = _clearing || _status != DtButtonStatus.idle;
    return DtDetailPage(
      title: '搜索与语音',
      subtitle: 'DeepSeek 官方工具',
      bottom: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: DtButton(
            label: '保存工具配置',
            status: _status,
            loadingText: '正在保存…',
            successText: '已保存',
            onPressed: _clearing ? null : _save,
          ),
        ),
      ),
      child: AbsorbPointer(
        absorbing: busy,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              '联网搜索、图片文字识别、语音转文字和朗读可独立接入，聊天仍使用你选定的供应商。',
              style: TextStyle(fontSize: 14, height: 1.6),
            ),
            const SizedBox(height: 16),
            DtSurface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '密钥来源',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  DtSegmentedControl(
                    labels: const ['复用官方聊天', '单独配置'],
                    index: _useChatKey ? 0 : 1,
                    onChanged: (index) => setState(() {
                      _useChatKey = index == 0;
                      _error = null;
                    }),
                  ),
                  const SizedBox(height: 16),
                  if (_useChatKey) ...[
                    Text(
                      state.data.settings.provider.isOfficialDeepSeek &&
                              state.hasApiKey
                          ? '使用「模型与供应商」中保存的官方 Key。'
                          : '当前聊天未配置 DeepSeek 官方 Key，请选择「单独配置」。',
                      style: const TextStyle(fontSize: 14, height: 1.6),
                    ),
                  ] else ...[
                    DtTextField(
                      controller: _key,
                      obscureText: _obscure,
                      autocorrect: false,
                      enableSuggestions: false,
                      decoration: InputDecoration(
                        labelText: state.hasToolApiKey
                            ? '官方 API Key（留空保留）'
                            : '官方 API Key',
                        hintText: '粘贴 DeepSeek 官方密钥',
                        suffixIcon: DtIconButton(
                          icon: _obscure ? FIcons.eye : FIcons.eyeOff,
                          tooltip: '切换工具密钥可见性',
                          onTap: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Expanded(
                          child: Text('记住工具密钥', style: TextStyle(fontSize: 14)),
                        ),
                        FSwitch(
                          value: _remember,
                          onChange: (value) =>
                              setState(() => _remember = value),
                        ),
                      ],
                    ),
                    Text(
                      kIsWeb
                          ? '默认仅保留在本标签页；开启后写入浏览器存储，同源脚本可读取。'
                          : '默认仅保留在本次会话；开启后写入系统安全存储。',
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.6,
                        color: DtColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '工具请求仅发送至 api.deepseek.com，可能产生官方 API 费用。保存配置不会发起付费请求。普通备份与媒体备份均不含密钥。',
              style: TextStyle(
                fontSize: 12,
                height: 1.6,
                color: DtColors.textSecondary,
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  _error!,
                  key: const ValueKey('tools-error'),
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color: DtColors.coral,
                  ),
                ),
              ),
            if (state.hasToolApiKey)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: DtButton(
                  label: '清除独立工具密钥',
                  variant: DtButtonVariant.ghost,
                  status: _clearing
                      ? DtButtonStatus.loading
                      : DtButtonStatus.idle,
                  loadingText: '正在清除…',
                  onPressed: _clear,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
