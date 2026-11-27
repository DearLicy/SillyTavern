import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../application/app_controller.dart';
import '../components/dt_controls.dart';
import '../components/dt_detail_page.dart';
import '../components/dt_edit_sheet.dart';

class ChatDataPage extends ConsumerWidget {
  const ChatDataPage({super.key, required this.threadId});
  final String threadId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(appControllerProvider).data;
    final thread = data.threads.where((t) => t.id == threadId).firstOrNull;
    final relationship = thread == null
        ? null
        : data.relationshipForThread(thread);
    final character = relationship == null
        ? null
        : data.characterForRelationship(relationship);
    if (thread == null || relationship == null || character == null) {
      return const DtDetailPage(
        title: '聊天数据',
        child: Center(child: Text('这段对话已不存在')),
      );
    }
    final controller = ref.read(appControllerProvider.notifier);
    final messageCount = data.messages
        .where((m) => m.threadId == threadId)
        .length;
    final memoryCount = data.memories
        .where((m) => m.relationshipId == relationship.id)
        .length;
    return DtDetailPage(
      title: '聊天与数据',
      subtitle: character.name,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DtSurface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$messageCount 条消息 · $memoryCount 条记忆',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text(
                  '当前用户人设：${data.personaById(relationship.personaId)?.name ?? '未绑定'}',
                ),
                const SizedBox(height: 8),
                const Text(
                  '清空和重新开始仅影响这段关系；用户人设、模型配置和其他角色保持不变。',
                  style: TextStyle(fontSize: 12, height: 1.6),
                ),
              ],
            ),
          ),
          if (thread.variables.isNotEmpty) ...[
            const SizedBox(height: 12),
            DtSurface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '宏变量',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  for (final entry in thread.variables.entries)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        '{{${entry.key}}} = ${entry.value}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, height: 1.5),
                      ),
                    ),
                  const SizedBox(height: 6),
                  const Text(
                    '由 {{setvar}}/{{addvar}}/{{incvar}} 等宏写入，仅影响这段对话。',
                    style: TextStyle(fontSize: 11.5, height: 1.5),
                  ),
                  const SizedBox(height: 8),
                  DtButton(
                    label: '清空宏变量',
                    variant: DtButtonVariant.secondary,
                    onPressed: () => controller.clearThreadVariables(threadId),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          DtSettingRow(
            icon: Icons.search_rounded,
            title: '查找聊天记录',
            subtitle: '搜索、查看、编辑或批量删除',
            onTap: () => context.push('/chat-history/$threadId'),
          ),
          DtSettingRow(
            icon: Icons.psychology_alt_outlined,
            title: '管理长期记忆',
            subtitle: '编辑、固定和删除角色记住的事',
            onTap: () => context.push('/memory/${relationship.id}'),
          ),
          const SizedBox(height: 20),
          DtSettingRow(
            icon: Icons.cleaning_services_outlined,
            title: '清空聊天记录',
            subtitle: '删除消息、图片附件与对话摘要，保留长期记忆',
            onTap: () => showDtEditSheet(
              context: context,
              title: '清空与${character.name}的聊天？',
              description:
                  '将删除这段对话的全部聊天记录、未共享的图片附件和对话摘要。长期记忆、角色和用户人设保留。此操作无法撤销。',
              actionLabel: '清空聊天记录',
              danger: true,
              onSubmit: (_) => controller.clearChatHistory(threadId),
            ),
          ),
          DtSettingRow(
            icon: Icons.restart_alt_rounded,
            title: '重新开始聊天',
            subtitle: '清除聊天、摘要和非边界记忆，角色设定与用户人设保留',
            onTap: () => showDtEditSheet(
              context: context,
              title: '与${character.name}重新开始？',
              description:
                  '删除这段对话的消息、附件、摘要和非边界记忆，保留角色卡、用户人设与固定记忆，不会自动发送开场白。此操作无法撤销。',
              actionLabel: '确认重新开始',
              danger: true,
              onSubmit: (_) => controller.restartRelationship(relationship.id),
            ),
          ),
          const SizedBox(height: 20),
          DtSettingRow(
            icon: Icons.person_remove_outlined,
            title: '删除角色及全部数据',
            subtitle: '删除角色的所有聊天、记忆与关联附件',
            onTap: () async {
              final deleted = await showDtEditSheet(
                context: context,
                title: '删除${character.name}？',
                description: '角色及其全部聊天、图片附件和记忆将从本机删除。你的用户人设和其他角色保留。此操作无法撤销。',
                actionLabel: '永久删除角色',
                danger: true,
                onSubmit: (_) => controller.deleteCharacter(character.id),
              );
              if (deleted == true && context.mounted) context.go('/characters');
            },
          ),
        ],
      ),
    );
  }
}
