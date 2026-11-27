import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../application/app_controller.dart';
import '../../domain/models.dart';
import '../components/dt_avatar.dart';
import '../components/dt_controls.dart';
import '../components/dt_detail_page.dart';
import '../components/dt_edit_sheet.dart';
import '../components/dt_motion.dart';
import '../theme/dt_theme.dart';

class PersonasPage extends ConsumerWidget {
  const PersonasPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(appControllerProvider).data;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return DtDetailPage(
      title: '用户人设',
      subtitle: '可选 · 用于替换角色卡中的 {{user}}',
      actions: [
        DtIconButton(
          onTap: () => context.push('/persona/new'),
          icon: Icons.add_rounded,
          tooltip: '创建用户人设',
          soft: true,
        ),
      ],
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
        children: [
          _InfoBanner(dark: dark),
          const SizedBox(height: 14),
          for (final persona in data.personas) ...[
            _PersonaCard(
              persona: persona,
              selected: persona.id == data.settings.currentPersonaId,
              relationshipCount: data.relationships
                  .where((e) => e.personaId == persona.id)
                  .length,
              onTap: () => ref
                  .read(appControllerProvider.notifier)
                  .selectPersona(persona.id),
              onEdit: () => context.push('/persona/${persona.id}'),
              onDelete: () => showDtEditSheet(
                context: context,
                title: '删除用户人设「${persona.name}」？',
                description:
                    data.relationships.any((r) => r.personaId == persona.id)
                    ? '该用户人设仍绑定着角色关系，不能直接删除，以免混淆身份和记忆。请先管理相关角色。'
                    : '将删除这套用户人设。若它是当前用户人设，会自动切换到剩余用户人设；没有剩余时回到未选择状态。此操作无法撤销。',
                actionLabel: '删除用户人设',
                danger: true,
                onSubmit: (_) => ref
                    .read(appControllerProvider.notifier)
                    .deletePersona(persona.id),
              ),
            ),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 6),
          DtButton(
            label: '创建新的用户人设',
            icon: Icons.auto_awesome_rounded,
            variant: DtButtonVariant.secondary,
            onPressed: () => context.push('/persona/new'),
          ),
        ],
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({required this.dark});

  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: dark
              ? const [Color(0xFF25203F), Color(0xFF1A1D2B)]
              : const [Color(0xFFF0ECFF), Color(0xFFF7F8FC)],
        ),
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: DtColors.violet.withValues(alpha: 0.2)),
        boxShadow: DtShadows.soft(dark),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.auto_awesome_rounded, color: DtColors.violet, size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              '用户人设是可选的。未选择时，角色卡中的 {{user}} 会回退为本地用户资料。不同人设拥有独立的姓名、背景与偏好。',
              style: TextStyle(fontSize: 12.5, height: 1.55),
            ),
          ),
        ],
      ),
    );
  }
}

class _PersonaCard extends StatelessWidget {
  const _PersonaCard({
    required this.persona,
    required this.selected,
    required this.relationshipCount,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  final UserPersona persona;
  final bool selected;
  final int relationshipCount;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return DtPressable(
      onTap: onTap,
      semanticLabel: '切换用户人设 ${persona.name}',
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: dark ? DtColors.darkSurface : DtColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? DtColors.violet.withValues(alpha: 0.75)
                : (dark ? const Color(0xFF252B39) : const Color(0xFFE9EDF5)),
            width: selected ? 1.3 : 0.8,
          ),
          boxShadow: DtShadows.soft(dark),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DtAvatar(
              name: persona.name,
              reference: persona.avatarReference,
              color: persona.avatarColor,
              size: 58,
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        persona.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(width: 7),
                      Text(
                        '${persona.age} 岁 · ${persona.pronouns}',
                        style: const TextStyle(
                          fontSize: 10.5,
                          color: Color(0xFF8B93A4),
                        ),
                      ),
                      const Spacer(),
                      if (selected)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: DtColors.violet.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: const Text(
                            '当前',
                            style: TextStyle(
                              color: DtColors.violet,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    persona.personality,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.45,
                      color: dark
                          ? const Color(0xFF98A1B5)
                          : const Color(0xFF737C8F),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        '$relationshipCount 段关系',
                        style: const TextStyle(
                          fontSize: 10,
                          color: DtColors.brand,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      DtIconButton(
                        icon: Icons.delete_outline,
                        tooltip: '删除用户人设',
                        onTap: onDelete,
                      ),
                      DtActionButton.icon(
                        onPressed: onEdit,
                        icon: const Icon(Icons.edit_outlined, size: 15),
                        label: const Text('编辑'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
