import '../components/dt_input.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../application/app_controller.dart';
import '../../ai/relationship_dynamics.dart';
import '../../domain/models.dart';
import '../components/dt_avatar.dart';
import '../components/dt_controls.dart';
import '../components/dt_motion.dart';
import '../theme/dt_theme.dart';

class ContactsPage extends ConsumerStatefulWidget {
  const ContactsPage({super.key});

  @override
  ConsumerState<ContactsPage> createState() => _ContactsPageState();
}

class _ContactsPageState extends ConsumerState<ContactsPage> {
  String _query = '';
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appControllerProvider);
    final data = state.data;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final characters = data.characters.where((character) {
      if (_query.trim().isEmpty) return true;
      final q = _query.toLowerCase();
      return character.name.toLowerCase().contains(q) ||
          character.intro.toLowerCase().contains(q) ||
          character.tags.any((e) => e.toLowerCase().contains(q));
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
                title: '联系人',
                subtitle:
                    '${data.characters.length} 位角色 · ${data.relationships.length} 段关系',
                actions: [
                  DtIconButton(
                    icon: Icons.badge_outlined,
                    tooltip: '角色卡',
                    onTap: () => context.push('/character-cards'),
                    soft: false,
                  ),
                  const SizedBox(width: 4),
                  DtIconButton(
                    icon: Icons.person_add_alt_1_rounded,
                    tooltip: '创建角色',
                    onTap: () => context.push('/character/new'),
                    soft: false,
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: DtStagger(
              index: 1,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: DtTextField(
                  onChanged: (value) => setState(() => _query = value),
                  decoration: const InputDecoration(
                    hintText: '搜索角色、标签或关系',
                    prefixIcon: Icon(Icons.search_rounded, size: 21),
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 13),
                  ),
                ),
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 16)),
          SliverToBoxAdapter(
            child: DtStagger(
              index: 3,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: DtSegmentedControl(
                        labels: const ['角色', '分组', '关系'],
                        index: _tab,
                        onChanged: (value) => setState(() => _tab = value),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '${characters.length}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: dark
                            ? const Color(0xFF9B9388)
                            : DtColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 8)),
          if (characters.isEmpty && _tab == 0)
            SliverFillRemaining(
              hasScrollBody: false,
              child: DtEmptyState(
                icon: Icons.person_outline,
                title: '还没有角色',
                body: '从一个名字和一段人设开始。',
                action: DtButton(
                  label: '创建角色',
                  onPressed: () => context.push('/character/new'),
                ),
              ),
            )
          else if (_tab == 0)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 30),
              sliver: SliverList.separated(
                itemCount: characters.length,
                separatorBuilder: (_, __) => Divider(
                  indent: 82,
                  color: dark
                      ? const Color(0xFF232837)
                      : const Color(0xFFEDF0F5),
                ),
                itemBuilder: (context, index) {
                  final character = characters[index];
                  final relationship = _relationshipFor(data, character.id);
                  return DtStagger(
                    key: ValueKey('character-${character.id}'),
                    index: index,
                    child: _CharacterTile(
                      character: character,
                      relationship: relationship,
                      onTap: () => context.push('/character/${character.id}'),
                    ),
                  );
                },
              ),
            )
          else if (_tab == 1)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 30),
              sliver: SliverList.list(
                children: [
                  DtStagger(
                    child: _GroupCard(
                      title: '特别关心',
                      count: data.relationships
                          .where((e) => (e.metrics['好感'] ?? 0) >= 70)
                          .length,
                      color: DtColors.rose,
                    ),
                  ),
                  const SizedBox(height: 10),
                  DtStagger(
                    index: 1,
                    child: _GroupCard(
                      title: '最近角色',
                      count: data.relationships.length,
                      color: DtColors.brand,
                    ),
                  ),
                  const SizedBox(height: 10),
                  DtStagger(
                    index: 2,
                    child: _GroupCard(
                      title: '尚未归类',
                      count: characters
                          .where((c) => _relationshipFor(data, c.id) == null)
                          .length,
                      color: DtColors.violet,
                    ),
                  ),
                ],
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 30),
              sliver: SliverList.separated(
                itemCount: data.relationships.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final relationship = data.relationships[index];
                  final character = data.characterForRelationship(relationship);
                  if (character == null) return const SizedBox.shrink();
                  return DtStagger(
                    key: ValueKey('relationship-${relationship.id}'),
                    index: index,
                    child: _RelationshipCard(
                      relationship: relationship,
                      character: character,
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Relationship? _relationshipFor(AppData data, String characterId) {
    for (final relationship in data.relationships) {
      if (relationship.characterId == characterId) return relationship;
    }
    return null;
  }
}

class _CharacterTile extends StatelessWidget {
  const _CharacterTile({
    required this.character,
    required this.relationship,
    required this.onTap,
  });

  final Character character;
  final Relationship? relationship;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return DtPressable(
      onTap: onTap,
      semanticLabel: character.name,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: Row(
          children: [
            DtAvatar(
              name: character.name,
              reference: character.avatarReference,
              color: character.avatarColor,
              size: 54,
              showStatus: relationship != null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        character.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        character.handle,
                        style: TextStyle(
                          fontSize: 10.5,
                          color: dark
                              ? const Color(0xFF697287)
                              : const Color(0xFFA1A8B7),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    character.intro,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: dark
                          ? const Color(0xFF929BAF)
                          : const Color(0xFF7B8395),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Wrap(
                    spacing: 5,
                    children: [
                      if (relationship != null)
                        _MiniTag(
                          text: relationship!.stage,
                          color: DtColors.violet,
                        ),
                      for (final tag in character.tags.take(2))
                        _MiniTag(text: tag, color: DtColors.brand),
                    ],
                  ),
                ],
              ),
            ),
            if (relationship != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    RelationshipDynamics.displayLabel('心动'),
                    style: TextStyle(
                      fontSize: 9.5,
                      color: dark
                          ? const Color(0xFF727B8F)
                          : const Color(0xFF9CA4B4),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${relationship!.metrics['心动'] ?? 0}',
                    style: const TextStyle(
                      color: DtColors.rose,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              )
            else
              Icon(
                Icons.chevron_right_rounded,
                color: dark ? const Color(0xFF5B6478) : const Color(0xFFB6BCCA),
              ),
          ],
        ),
      ),
    );
  }
}

class _MiniTag extends StatelessWidget {
  const _MiniTag({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({
    required this.title,
    required this.count,
    required this.color,
  });

  final String title;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return DtSurface(
      level: DtSurfaceLevel.raised,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      borderRadius: 12,
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.folder_outlined, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 11,
              color: dark ? const Color(0xFF80899D) : const Color(0xFF949CAD),
            ),
          ),
        ],
      ),
    );
  }
}

class _RelationshipCard extends StatelessWidget {
  const _RelationshipCard({
    required this.relationship,
    required this.character,
  });

  final Relationship relationship;
  final Character character;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return DtSurface(
      level: DtSurfaceLevel.floating,
      padding: const EdgeInsets.all(16),
      borderRadius: 12,
      onTap: () => context.push('/character/${character.id}'),
      child: Column(
        children: [
          Row(
            children: [
              DtAvatar(
                name: character.name,
                reference: character.avatarReference,
                color: character.avatarColor,
                size: 46,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      character.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      relationship.stage,
                      style: const TextStyle(
                        fontSize: 11,
                        color: DtColors.violet,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                relationship.consent.ceiling.label,
                style: TextStyle(
                  fontSize: 10,
                  color: dark
                      ? const Color(0xFF778196)
                      : const Color(0xFF9AA2B2),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              for (final entry in relationship.metrics.entries) ...[
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        '${entry.value}',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        RelationshipDynamics.displayLabel(entry.key),
                        style: TextStyle(
                          fontSize: 10,
                          color: dark
                              ? const Color(0xFF7D869A)
                              : const Color(0xFF969EAE),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
