import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../application/app_controller.dart';
import '../../domain/models.dart';
import '../components/dt_controls.dart';
import '../components/dt_detail_page.dart';
import '../components/dt_edit_sheet.dart';
import '../components/dt_input.dart';
import '../components/dt_sheet.dart';

class ChatHistoryPage extends ConsumerStatefulWidget {
  const ChatHistoryPage({super.key, required this.threadId});
  final String threadId;
  @override
  ConsumerState<ChatHistoryPage> createState() => _ChatHistoryPageState();
}

class _ChatHistoryPageState extends ConsumerState<ChatHistoryPage> {
  String _query = '';
  final Set<String> _selected = {};
  bool _selecting = false;

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(appControllerProvider).data;
    final history =
        data.messages
            .where((m) => m.threadId == widget.threadId && m.isRenderable)
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final query = _query.trim().toLowerCase();
    final visible = history
        .where(
          (m) =>
              query.isEmpty ||
              m.text.toLowerCase().contains(query) ||
              m.senderName.toLowerCase().contains(query),
        )
        .toList();
    final existingIds = history.map((m) => m.id).toSet();
    _selected.removeWhere((id) => !existingIds.contains(id));
    return DtDetailPage(
      title: '聊天记录',
      subtitle: '${history.length} 条记录',
      actions: [
        DtActionButton(
          onPressed: () => setState(() {
            _selecting = !_selecting;
            _selected.clear();
          }),
          child: Text(_selecting ? '取消' : '多选'),
        ),
      ],
      bottom: !_selecting
          ? null
          : SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    DtActionButton(
                      onPressed: () => setState(() {
                        if (visible.every((m) => _selected.contains(m.id))) {
                          _selected.removeAll(visible.map((m) => m.id));
                        } else {
                          _selected.addAll(visible.map((m) => m.id));
                        }
                      }),
                      child: const Text('全选结果'),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DtButton(
                        label: '删除（${_selected.length}）',
                        variant: DtButtonVariant.danger,
                        onPressed: _selected.isEmpty
                            ? null
                            : () async {
                                final ids = Set<String>.of(_selected);
                                final deleted = await showDtEditSheet(
                                  context: context,
                                  title: '删除 ${ids.length} 条消息？',
                                  description:
                                      '将删除选中的消息和不再使用的图片，清除这段对话的自动摘要与自动记忆，之后按剩余记录重新整理。手动记忆保留。此操作无法撤销。',
                                  actionLabel: '删除选中消息',
                                  danger: true,
                                  onSubmit: (_) => ref
                                      .read(appControllerProvider.notifier)
                                      .deleteMessages(ids),
                                );
                                if (deleted == true && mounted) {
                                  setState(() {
                                    _selected.clear();
                                    _selecting = false;
                                  });
                                }
                              },
                      ),
                    ),
                  ],
                ),
              ),
            ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: DtTextField(
              onChanged: (value) => setState(() => _query = value),
              decoration: const InputDecoration(
                hintText: '搜索内容或发送者',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
          ),
          Expanded(
            child: visible.isEmpty
                ? Center(child: Text(query.isEmpty ? '还没有聊天记录' : '没有找到匹配的消息'))
                : ListView.builder(
                    itemCount: visible.length,
                    itemBuilder: (context, index) {
                      final message = visible[index];
                      return DtSettingRow(
                        icon: _selecting
                            ? (_selected.contains(message.id)
                                  ? Icons.check_circle_rounded
                                  : Icons.circle_outlined)
                            : message.kind == MessageKind.image
                            ? Icons.image_outlined
                            : Icons.chat_bubble_outline_rounded,
                        title:
                            '${message.senderName} · ${DateFormat('MM-dd HH:mm').format(message.createdAt)}${message.editedAt == null ? '' : ' · 已编辑'}',
                        subtitle: message.text.isEmpty ? '[图片]' : message.text,
                        onTap: () {
                          if (_selecting) {
                            setState(() {
                              if (!_selected.remove(message.id)) {
                                _selected.add(message.id);
                              }
                            });
                          } else {
                            _showMessage(message);
                          }
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _showMessage(Message message) {
    showDtSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                message.senderName,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 260),
                child: SingleChildScrollView(
                  child: SelectableText(
                    message.text.isEmpty ? '[图片]' : message.text,
                  ),
                ),
              ),
              DtSettingRow(
                icon: Icons.copy_outlined,
                title: '复制文本',
                onTap: () async {
                  await Clipboard.setData(ClipboardData(text: message.text));
                  if (sheetContext.mounted) Navigator.pop(sheetContext);
                },
              ),
              DtSettingRow(
                icon: Icons.edit_outlined,
                title: '编辑消息',
                onTap: () {
                  Navigator.pop(sheetContext);
                  showDtEditSheet(
                    context: context,
                    title: '编辑消息',
                    description: '修改会保存到本机并用于后续对话。自动摘要和自动记忆会重新整理。',
                    initialText: message.text,
                    allowEmpty: message.kind == MessageKind.image,
                    actionLabel: '保存修改',
                    onSubmit: (text) => ref
                        .read(appControllerProvider.notifier)
                        .editMessage(message.id, text),
                  );
                },
              ),
              DtSettingRow(
                icon: Icons.delete_outline,
                title: '删除消息',
                onTap: () {
                  Navigator.pop(sheetContext);
                  showDtEditSheet(
                    context: context,
                    title: '删除这条消息？',
                    description: '删除后会清除过期的自动摘要和自动记忆。手动记忆保留，此操作无法撤销。',
                    actionLabel: '删除消息',
                    danger: true,
                    onSubmit: (_) => ref
                        .read(appControllerProvider.notifier)
                        .deleteMessage(message.id),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
