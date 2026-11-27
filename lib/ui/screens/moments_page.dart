import '../components/dt_sheet.dart';
import '../components/dt_edit_sheet.dart';
import '../components/dt_input.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../application/app_controller.dart';
import '../../domain/models.dart';
import '../components/dt_avatar.dart';
import '../components/dt_controls.dart';
import '../components/dt_motion.dart';
import '../theme/dt_theme.dart';

class MomentsPage extends ConsumerWidget {
  const MomentsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appControllerProvider);
    final data = state.data;
    final dark = Theme.of(context).brightness == Brightness.dark;

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
                padding: const EdgeInsets.fromLTRB(16, 14, 10, 10),
                leading: DtPressable(
                  onTap: () => Scaffold.of(context).openDrawer(),
                  semanticLabel: '打开个人资料',
                  child: DtAvatar(
                    name: data.owner.displayName,
                    reference: data.owner.avatarReference,
                    color: data.owner.avatarColor,
                    size: 42,
                    showStatus: true,
                  ),
                ),
                title: '动态',
                subtitle: '角色与你的本地动态',
                actions: [
                  DtIconButton(
                    icon: Icons.edit_outlined,
                    tooltip: '发布动态',
                    onTap: () => _showComposer(context, ref),
                    soft: true,
                  ),
                ],
              ),
            ),
          ),
          if (data.moments.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: DtEmptyState(
                icon: Icons.chat_bubble_outline,
                title: '还没有动态',
                body: '在这里留下你的第一条动态。',
                action: DtButton(
                  label: '发布动态',
                  onPressed: () => _showComposer(context, ref),
                ),
              ),
            ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 30),
            sliver: SliverList.separated(
              itemCount: data.moments.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final moment = data.moments[index];
                return DtStagger(
                  key: ValueKey('moment-${moment.id}'),
                  index: index,
                  child: _MomentCard(
                    moment: moment,
                    avatarReference: moment.authorId == data.owner.id
                        ? data.owner.avatarReference
                        : data.characters
                              .where((c) => c.id == moment.authorId)
                              .firstOrNull
                              ?.avatarReference,
                    ownerName: data.owner.displayName,
                    dark: dark,
                    onLike: () => ref
                        .read(appControllerProvider.notifier)
                        .toggleMomentLike(moment.id, data.owner.displayName),
                    onComment: () => _showCommentSheet(context, ref, moment),
                    onMore: () => _showMomentActions(context, ref, moment),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showMomentActions(BuildContext context, WidgetRef ref, Moment moment) {
    final pageContext = context;
    final data = ref.read(appControllerProvider).data;
    showDtSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!moment.fromAi && moment.authorId == data.owner.id)
                DtSettingRow(
                  icon: Icons.edit_outlined,
                  title: '编辑动态',
                  onTap: () {
                    Navigator.pop(context);
                    showDtEditSheet(
                      context: pageContext,
                      title: '编辑动态',
                      description: '修改正文，保留已有的点赞和评论。',
                      initialText: moment.content,
                      actionLabel: '保存修改',
                      onSubmit: (text) => ref
                          .read(appControllerProvider.notifier)
                          .editMoment(moment.id, text),
                    );
                  },
                ),
              DtSettingRow(
                icon: Icons.delete_outline,
                title: '删除动态',
                onTap: () {
                  Navigator.pop(context);
                  showDtEditSheet(
                    context: pageContext,
                    title: '删除这条动态？',
                    description: '正文、点赞和评论将一起从本机删除。此操作无法撤销。',
                    actionLabel: '删除动态',
                    danger: true,
                    onSubmit: (_) => ref
                        .read(appControllerProvider.notifier)
                        .deleteMoment(moment.id),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showComposer(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    showDtSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          0,
          16,
          MediaQuery.viewInsetsOf(context).bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '发布到动态',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            const Text('图片与视频将在后续版本开放。', style: TextStyle(fontSize: 12)),
            const SizedBox(height: 14),
            DtTextField(
              controller: controller,
              autofocus: true,
              minLines: 4,
              maxLines: 8,
              decoration: const InputDecoration(hintText: '这一刻想留下什么？'),
            ),
            const SizedBox(height: 12),
            DtButton(
              label: '发布',
              icon: Icons.arrow_upward_rounded,
              onPressed: () {
                ref
                    .read(appControllerProvider.notifier)
                    .publishMoment(controller.text);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    ).whenComplete(controller.dispose);
  }

  void _showCommentSheet(BuildContext context, WidgetRef ref, Moment moment) {
    final thisContext = context;
    final controller = TextEditingController();
    showDtSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          0,
          16,
          MediaQuery.viewInsetsOf(context).bottom + 16,
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '评论 · ${moment.authorName}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              if (moment.comments.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('还没有评论，说点什么吧。'),
                )
              else
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 260),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: moment.comments.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final comment = moment.comments[index];
                      return DtPressable(
                        onLongPress: () {
                          Navigator.pop(context);
                          showDtSheet<void>(
                            context: thisContext,
                            builder: (menuContext) => SafeArea(
                              top: false,
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  0,
                                  16,
                                  16,
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (!comment.fromAi)
                                      DtSettingRow(
                                        icon: Icons.edit_outlined,
                                        title: '编辑评论',
                                        onTap: () {
                                          Navigator.pop(menuContext);
                                          showDtEditSheet(
                                            context: thisContext,
                                            title: '编辑评论',
                                            description: '修改你的这条评论。',
                                            initialText: comment.content,
                                            actionLabel: '保存修改',
                                            onSubmit: (text) => ref
                                                .read(
                                                  appControllerProvider
                                                      .notifier,
                                                )
                                                .editMomentComment(
                                                  moment.id,
                                                  comment.id,
                                                  text,
                                                ),
                                          );
                                        },
                                      ),
                                    DtSettingRow(
                                      icon: Icons.delete_outline,
                                      title: '删除评论',
                                      onTap: () {
                                        Navigator.pop(menuContext);
                                        showDtEditSheet(
                                          context: thisContext,
                                          title: '删除这条评论？',
                                          description:
                                              '只删除选中的评论，动态和其他评论保留。此操作无法撤销。',
                                          actionLabel: '删除评论',
                                          danger: true,
                                          onSubmit: (_) => ref
                                              .read(
                                                appControllerProvider.notifier,
                                              )
                                              .deleteMomentComment(
                                                moment.id,
                                                comment.id,
                                              ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${comment.authorName}：',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                comment.content,
                                style: const TextStyle(
                                  fontSize: 13,
                                  height: 1.45,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DtTextField(
                      controller: controller,
                      autofocus: true,
                      decoration: const InputDecoration(hintText: '写下评论'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  DtButton(
                    label: '发送',
                    compact: true,
                    fullWidth: false,
                    onPressed: () {
                      ref
                          .read(appControllerProvider.notifier)
                          .addMomentComment(moment.id, controller.text);
                      Navigator.pop(context);
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ).whenComplete(controller.dispose);
  }
}

class _MomentCard extends StatelessWidget {
  const _MomentCard({
    required this.moment,
    this.avatarReference,
    required this.ownerName,
    required this.dark,
    required this.onLike,
    required this.onComment,
    required this.onMore,
  });

  final Moment moment;
  final String? avatarReference;
  final String ownerName;
  final bool dark;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final liked = moment.likedBy.contains(ownerName);
    return DtSurface(
      level: DtSurfaceLevel.raised,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      borderRadius: 12,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              DtAvatar(
                name: moment.authorName,
                reference: avatarReference,
                color: moment.avatarColor,
                size: 44,
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          moment.authorName,
                          style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (moment.fromAi) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: DtColors.violet.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: const Text(
                              'AI',
                              style: TextStyle(
                                color: DtColors.violet,
                                fontSize: 8,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _time(moment.createdAt),
                      style: TextStyle(
                        fontSize: 10.5,
                        color: dark
                            ? const Color(0xFF737C91)
                            : const Color(0xFF9AA2B2),
                      ),
                    ),
                  ],
                ),
              ),
              DtIconButton(
                icon: Icons.more_horiz_rounded,
                tooltip: '动态操作',
                onTap: onMore,
              ),
            ],
          ),
          const SizedBox(height: 13),
          Text(
            moment.content,
            style: const TextStyle(fontSize: 14.5, height: 1.65),
          ),
          const SizedBox(height: 12),
          Divider(
            color: dark ? const Color(0xFF242938) : const Color(0xFFEFF2F7),
          ),
          Row(
            children: [
              DtPressable(
                onTap: onLike,
                semanticLabel: liked ? '取消点赞' : '点赞',
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 7,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        liked
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        size: 18,
                        color: liked
                            ? DtColors.coral
                            : (dark
                                  ? const Color(0xFF8A93A7)
                                  : const Color(0xFF7E8798)),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        moment.likedBy.isEmpty
                            ? '喜欢'
                            : '${moment.likedBy.length}',
                        style: TextStyle(
                          fontSize: 11,
                          color: dark
                              ? const Color(0xFF8A93A7)
                              : const Color(0xFF7E8798),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              DtPressable(
                onTap: onComment,
                semanticLabel: '评论',
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 7,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.chat_bubble_outline_rounded,
                        size: 17,
                        color: dark
                            ? const Color(0xFF8A93A7)
                            : const Color(0xFF7E8798),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        moment.comments.isEmpty
                            ? '评论'
                            : '${moment.comments.length}',
                        style: TextStyle(
                          fontSize: 11,
                          color: dark
                              ? const Color(0xFF8A93A7)
                              : const Color(0xFF7E8798),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              if (moment.likedBy.isNotEmpty)
                Text(
                  _likeSummary(moment.likedBy),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    color: dark
                        ? const Color(0xFF6E778C)
                        : const Color(0xFF9CA4B3),
                  ),
                ),
            ],
          ),
          if (moment.comments.isNotEmpty) ...[
            const SizedBox(height: 9),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(11, 9, 11, 9),
              decoration: BoxDecoration(
                color: dark ? const Color(0xFF1A1F2D) : const Color(0xFFF5F7FB),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final comment in moment.comments.take(2))
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: '${comment.authorName}：',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            TextSpan(text: comment.content),
                          ],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          height: 1.45,
                          color: dark
                              ? const Color(0xFFB3BCCF)
                              : const Color(0xFF596174),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _time(DateTime value) {
    final diff = DateTime.now().difference(value);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inHours < 1) return '${diff.inMinutes} 分钟前';
    if (diff.inDays < 1) return '${diff.inHours} 小时前';
    if (diff.inDays == 1) return '昨天 ${DateFormat('HH:mm').format(value)}';
    return DateFormat('M月d日 HH:mm').format(value);
  }

  String _likeSummary(List<String> names) {
    if (names.length <= 2) return names.join('、');
    return '${names.take(2).join('、')} 等 ${names.length} 人';
  }
}
