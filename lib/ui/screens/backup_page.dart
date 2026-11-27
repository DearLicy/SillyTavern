import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../application/app_controller.dart';
import '../components/dt_controls.dart';
import '../components/dt_detail_page.dart';
import '../components/dt_edit_sheet.dart';

class BackupPage extends ConsumerStatefulWidget {
  const BackupPage({super.key});
  @override
  ConsumerState<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends ConsumerState<BackupPage> {
  DtButtonStatus _exportStatus = DtButtonStatus.idle;
  String? _error;
  @override
  Widget build(BuildContext context) {
    final controller = ref.read(appControllerProvider.notifier);
    return DtDetailPage(
      title: '数据与备份',
      subtitle: '包含本地头像和图片，不包含 API Key',
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DtSurface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '完整备份',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 10),
                const Text(
                  '导出角色卡、用户人设、消息、记忆、世界书及图片原件。备份包含私人内容，请保存在你信任的地方。',
                  style: TextStyle(fontSize: 13, height: 1.6),
                ),
                const SizedBox(height: 14),
                DtButton(
                  label: '复制完整备份',
                  loadingText: '正在打包附件…',
                  successText: '已复制',
                  status: _exportStatus,
                  onPressed: () async {
                    if (_exportStatus != DtButtonStatus.idle) return;
                    setState(() {
                      _error = null;
                      _exportStatus = DtButtonStatus.loading;
                    });
                    try {
                      final backup = await controller.exportPortableBackup();
                      await Clipboard.setData(ClipboardData(text: backup));
                      if (!mounted) return;
                      setState(() => _exportStatus = DtButtonStatus.success);
                      await Future<void>.delayed(
                        const Duration(milliseconds: 300),
                      );
                    } catch (error) {
                      if (mounted) {
                        setState(
                          () => _error = error is StateError
                              ? error.message
                              : '备份失败，请重试。',
                        );
                      }
                    } finally {
                      if (mounted) {
                        setState(() => _exportStatus = DtButtonStatus.idle);
                      }
                    }
                  },
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          DtSettingRow(
            icon: Icons.restore,
            title: '从 JSON 恢复',
            subtitle: '检查全部附件后覆盖当前数据，保留已配置密钥',
            onTap: () => showDtEditSheet(
              context: context,
              title: '从 JSON 恢复',
              description:
                  '恢复将替换本机数据。支持旧 V2 JSON 和新版含图片的完整备份；旧版 JSON 不包含图片原件。建议先备份当前数据。',
              initialText: '',
              actionLabel: '覆盖恢复',
              danger: true,
              onSubmit: controller.importBackup,
            ),
          ),
          DtSettingRow(
            icon: Icons.delete_outline,
            title: '清空本地数据',
            subtitle: '删除全部角色、用户人设、图片和密钥，恢复空白状态',
            onTap: () => showDtEditSheet(
              context: context,
              title: '清空全部本地数据？',
              description: '角色卡、用户人设、会话、记忆、世界书、图片和 API Key 都会被删除。此操作无法撤销。',
              actionLabel: '清空全部数据',
              danger: true,
              onSubmit: (_) async {
                await controller.resetData();
                if (context.mounted) context.go('/');
              },
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Web 数据与附件保存在当前浏览器。清理站点数据、结束隐私模式或更换浏览器可能丢失数据，请定期备份。',
            style: TextStyle(fontSize: 12, height: 1.6),
          ),
        ],
      ),
    );
  }
}
