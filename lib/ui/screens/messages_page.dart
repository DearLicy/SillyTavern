import '../components/dt_sheet.dart';
import '../components/dt_input.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../application/app_controller.dart';
import '../../domain/models.dart';
import '../components/dt_avatar.dart';
import '../components/dt_controls.dart';
import '../components/dt_edit_sheet.dart';
import '../components/dt_motion.dart';
import '../theme/dt_theme.dart';

class MessagesPage extends ConsumerStatefulWidget {
  const MessagesPage({super.key});

  @override
  ConsumerState<MessagesPage> createState() => _MessagesPageState();
}

class _MessagesPageState extends ConsumerState<MessagesPage> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appControllerProvider);
    final data = state.data;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final threads = [...data.threads]
      ..sort((a, b) {
        if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
        return b.updatedAt.compareTo(a.updatedAt);
      });
    final filtered = threads.where((thread) {
      if (_query.trim().isEmpty) return true;
      final relationship = data.relationshipForThread(thread);
      final character = relationship == null
          ? null
          : data.characterForRelationship(relationship);
      return thread.title.toLowerCase().contains(_query.toLowerCase()) ||
          (character?.intro.toLowerCase().contains(_query.toLowerCase()) ??
              false);
    }).toList();

    return SafeArea(
      bottom: false,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
          SliverToBoxAdapter(
            child: DtStagger(
              child: DtPageHeader(
                padding: const EdgeInsets.fromLTRB(16, 14, 12, 10),
                leading: _OwnerAvatarButton(owner: data.owner),
                title: 'SillyTavern',
                subtitle: '${threads.length} 个会话 · 本地优先',
                actions: [
                  DtIconButton(
                    icon: Icons.people_outline_rounded,
                    tooltip: '角色库',
                    onTap: () => context.push('/characters'),
                  ),
                  const SizedBox(width: 4),
                  DtIconButton(
                    icon: Icons.add_rounded,
                    tooltip: '新建对话',
                    onTap: () => _showQuickActions(context, ref),
                    soft: true,
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: DtStagger(
              index: 1,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 2, 16, 10),
                child: DtTextField(
                  onChanged: (value) => setState(() => _query = value),
                  textInputAction: TextInputAction.search,
                  decoration: const InputDecoration(
                    hintText: '搜索会话或角色',
                    prefixIcon: Icon(Icons.search_rounded, size: 21),
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 13),
                  ),
                ),
              ),
            ),
          ),
          if (filtered.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: DtEmptyState(
                icon: Icons.forum_outlined,
                title: '还没有找到对话',
                body: '创建自己的用户人设和角色，开始第一段对话。',
                action: DtButton(
                  label: '创建角色',
                  onPressed: () => context.push('/character/new'),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.only(bottom: 24),
              sliver: SliverList.separated(
                itemCount: filtered.length,
                separatorBuilder: (_, __) =>
                    const Divider(height: .5, indent: 78),
                itemBuilder: (context, index) {
                  final thread = filtered[index];
                  final relationship = data.relationshipForThread(thread);
                  final character = relationship == null
                      ? null
                      : data.characterForRelationship(relationship);
                  if (relationship == null || character == null) {
                    return const SizedBox.shrink();
                  }
                  final lastMessage = _lastMessage(data, thread.id);
                  final unread = thread.unread;
                  return DtStagger(
                    key: ValueKey('thread-${thread.id}'),
                    index: index,
                    child: _ConversationTile(
                      thread: thread,
                      character: character,
                      lastMessage: lastMessage,
                      unread: unread,
                      dark: dark,
                      onTap: () {
                        ref
                            .read(appControllerProvider.notifier)
                            .markThreadRead(thread.id);
                        context.push('/chat/${thread.id}');
                      },
                      onLongPress: () =>
                          _showThreadActions(context, ref, thread),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Message? _lastMessage(AppData data, String threadId) {
    final list = data.messages.where((e) => e.threadId == threadId).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return list.isEmpty ? null : list.last;
  }

  void _showQuickActions(BuildContext context, WidgetRef ref) {
    showDtSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DtSettingRow(
                icon: Icons.chat_bubble_outline_rounded,
                title: '发起新对话',
                subtitle: '从角色库选择一张角色卡',
                onTap: () {
                  Navigator.pop(context);
                  context.push('/characters');
                },
              ),
              DtSettingRow(
                icon: Icons.groups_2_outlined,
                title: '发起群聊',
                subtitle: '选择两个或更多角色加入同一段对话',
                onTap: () {
                  Navigator.pop(context);
                  _showCreateGroup(this.context, ref);
                },
              ),
              DtSettingRow(
                icon: Icons.person_add_alt_1_rounded,
                title: '创建角色',
                subtitle: '创建新的角色',
                onTap: () {
                  Navigator.pop(context);
                  context.push('/character/new');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showCreateGroup(BuildContext context, WidgetRef ref) async {
    final data = ref.read(appControllerProvider).data;
    final characters = data.characters;
    if (characters.length < 2) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('至少需要两个角色才能发起群聊')));
      return;
    }
    final selected = <String>{};
    final picked = await showDialog<List<String>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('发起群聊'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final character in characters)
                  CheckboxListTile(
                    value: selected.contains(character.id),
                    title: Text(character.name),
                    subtitle: Text(character.handle),
                    onChanged: (value) => setDialogState(() {
                      if (value == true) {
                        selected.add(character.id);
                      } else {
                        selected.remove(character.id);
                      }
                    }),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: selected.length < 2
                  ? null
                  : () => Navigator.pop(
                      dialogContext,
                      selected.toList(growable: false),
                    ),
              child: Text('创建（${selected.length}）'),
            ),
          ],
        ),
      ),
    );
    if (picked == null || picked.length < 2) return;
    try {
      final thread = await ref
          .read(appControllerProvider.notifier)
          .createGroupChat(characterIds: picked);
      if (context.mounted) context.push('/chat/${thread.id}');
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('群聊创建失败：$error')));
      }
    }
  }

  void _showThreadActions(
    BuildContext context,
    WidgetRef ref,
    ChatThread thread,
  ) {
    final controller = ref.read(appControllerProvider.notifier);
    showDtSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DtSettingRow(
                icon: Icons.manage_history_rounded,
                title: '聊天与数据',
                subtitle: '查找记录、清空聊天或重新开始',
                onTap: () {
                  Navigator.pop(context);
                  this.context.push('/chat-data/${thread.id}');
                },
              ),
              DtSettingRow(
                icon: Icons.push_pin_outlined,
                title: thread.pinned ? '取消置顶' : '置顶对话',
                onTap: () {
                  controller.toggleThreadPinned(thread.id);
                  Navigator.pop(context);
                },
              ),
              DtSettingRow(
                icon: thread.muted
                    ? Icons.notifications_active_outlined
                    : Icons.notifications_off_outlined,
                title: thread.muted ? '恢复提醒' : '消息免打扰',
                onTap: () {
                  controller.toggleThreadMuted(thread.id);
                  Navigator.pop(context);
                },
              ),
              DtSettingRow(
                icon: Icons.delete_sweep_outlined,
                iconColor: DtColors.coral,
                title: '清空单人物聊天记录',
                subtitle: '只清掉这段对话，保留角色、用户人设和长期记忆',
                onTap: () {
                  Navigator.pop(context);
                  showDtEditSheet(
                    context: this.context,
                    title: '清空与${thread.title}的聊天？',
                    description:
                        '将删除这条会话的全部消息、图片附件与对话摘要。角色、用户人设和长期记忆都会保留，不会自动发送开场白。此操作无法撤销。',
                    actionLabel: '清空聊天记录',
                    danger: true,
                    onSubmit: (_) => controller.clearChatHistory(thread.id),
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

class _OwnerAvatarButton extends StatelessWidget {
  const _OwnerAvatarButton({required this.owner});

  final OwnerProfile owner;

  @override
  Widget build(BuildContext context) {
    return DtPressable(
      onTap: () => Scaffold.of(context).openDrawer(),
      semanticLabel: '打开个人资料',
      child: DtAvatar(
        name: owner.displayName,
        reference: owner.avatarReference,
        color: owner.avatarColor,
        size: 42,
        showStatus: true,
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({
    required this.thread,
    required this.character,
    required this.lastMessage,
    required this.unread,
    required this.dark,
    required this.onTap,
    required this.onLongPress,
  });

  final ChatThread thread;
  final Character character;
  final Message? lastMessage;
  final int unread;
  final bool dark;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final subtitle = lastMessage?.text.replaceAll(RegExp(r'\s+'), ' ').trim();
    return DtSurface(
      level: thread.pinned ? DtSurfaceLevel.floating : DtSurfaceLevel.raised,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      borderRadius: 0,
      backgroundColor: thread.pinned
          ? (dark ? const Color(0xFF24211C) : DtColors.surfaceMuted)
          : null,
      onTap: onTap,
      onLongPress: onLongPress,
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              DtAvatar(
                name: character.name,
                reference: character.avatarReference,
                color: character.avatarColor,
                size: 50,
                heroTag: 'character-${character.id}',
              ),
              if (unread > 0)
                Positioned(
                  right: -3,
                  top: -4,
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 20),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: DtColors.coral,
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(
                        color: dark ? DtColors.darkBg : DtColors.mist,
                        width: 2,
                      ),
                    ),
                    child: Text(
                      unread > 99 ? '99+' : '$unread',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        character.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      _timeLabel(thread.updatedAt),
                      style: TextStyle(
                        fontSize: 10.5,
                        color: dark
                            ? const Color(0xFF727B90)
                            : const Color(0xFF9AA2B2),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (thread.muted) ...[
                      Icon(
                        Icons.notifications_off_outlined,
                        size: 13,
                        color: dark
                            ? const Color(0xFF737C91)
                            : const Color(0xFFA1A8B7),
                      ),
                      const SizedBox(width: 4),
                    ],
                    Expanded(
                      child: Text(
                        subtitle == null || subtitle.isEmpty
                            ? '开始一段新的对话'
                            : '${lastMessage!.fromAi ? '' : '你：'}$subtitle',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.3,
                          color: dark
                              ? const Color(0xFF949DB1)
                              : const Color(0xFF7B8396),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _timeLabel(DateTime value) {
    final now = DateTime.now();
    if (value.year == now.year &&
        value.month == now.month &&
        value.day == now.day) {
      return DateFormat('HH:mm').format(value);
    }
    if (now.difference(value).inDays == 1) return '昨天';
    return DateFormat('M/d').format(value);
  }
}
