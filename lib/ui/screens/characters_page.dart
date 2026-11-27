import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../application/app_controller.dart';
import '../../domain/models.dart';
import '../components/dt_avatar.dart';
import '../components/dt_controls.dart';
import '../components/dt_input.dart';
import '../components/dt_motion.dart';
import '../theme/dt_theme.dart';

/// Character library for the mobile SillyTavern client. Characters are the
/// source of truth; threads are only conversations opened from them.
class CharactersPage extends ConsumerStatefulWidget {
  const CharactersPage({super.key});

  @override
  ConsumerState<CharactersPage> createState() => _CharactersPageState();
}

class _CharactersPageState extends ConsumerState<CharactersPage> {
  String _query = '';
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(appControllerProvider).data;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final query = _query.trim().toLowerCase();
    final characters = data.characters.where((character) {
      if (query.isEmpty) return true;
      return character.name.toLowerCase().contains(query) ||
          character.intro.toLowerCase().contains(query) ||
          character.persona.toLowerCase().contains(query) ||
          character.tags.any((tag) => tag.toLowerCase().contains(query));
    }).toList();
    final tags = <String, int>{};
    for (final character in characters) {
      for (final tag in character.tags) {
        tags.update(tag, (value) => value + 1, ifAbsent: () => 1);
      }
    }
    final orderedTags = tags.entries.toList()
      ..sort((a, b) {
        final count = b.value.compareTo(a.value);
        return count == 0 ? a.key.compareTo(b.key) : count;
      });

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
                  semanticLabel: '打开菜单',
                  child: DtAvatar(
                    name: data.owner.displayName,
                    reference: data.owner.avatarReference,
                    color: data.owner.avatarColor,
                    size: 42,
                  ),
                ),
                title: '角色',
                subtitle:
                    '${data.characters.length} 张角色卡 · ${data.worldBooks.length} 本世界书',
                actions: [
                  DtIconButton(
                    icon: Icons.chat_bubble_outline_rounded,
                    tooltip: '返回会话',
                    onTap: () => context.go('/'),
                  ),
                  const SizedBox(width: 4),
                  DtIconButton(
                    icon: Icons.badge_outlined,
                    tooltip: '导入与导出角色卡',
                    onTap: () => context.push('/character-cards'),
                  ),
                  const SizedBox(width: 4),
                  DtIconButton(
                    icon: Icons.add_rounded,
                    tooltip: '创建角色',
                    soft: true,
                    onTap: () => context.push('/character/new'),
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
                    hintText: '搜索角色、描述或标签',
                    prefixIcon: Icon(Icons.search_rounded, size: 21),
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 13),
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: DtStagger(
              index: 2,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: DtSegmentedControl(
                  labels: const ['角色', '标签'],
                  index: _tab,
                  onChanged: (value) => setState(() => _tab = value),
                ),
              ),
            ),
          ),
          if (characters.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: DtEmptyState(
                icon: Icons.person_search_outlined,
                title: query.isEmpty ? '还没有角色卡' : '没有匹配的角色',
                body: query.isEmpty
                    ? '创建角色，或导入 SillyTavern Character Card V2 JSON/PNG。'
                    : '换一个名字、描述或标签试试。',
                action: DtButton(
                  label: query.isEmpty ? '导入角色卡' : '创建角色',
                  onPressed: () => context.push(
                    query.isEmpty ? '/character-cards' : '/character/new',
                  ),
                ),
              ),
            )
          else if (_tab == 0)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 30),
              sliver: SliverList.separated(
                itemCount: characters.length,
                separatorBuilder: (_, __) => Divider(
                  height: 1,
                  indent: 78,
                  color: dark
                      ? const Color(0xFF252A37)
                      : const Color(0xFFEDEFF4),
                ),
                itemBuilder: (context, index) {
                  final character = characters[index];
                  return DtStagger(
                    key: ValueKey('character-${character.id}'),
                    index: index,
                    child: _CharacterTile(character: character),
                  );
                },
              ),
            )
          else if (orderedTags.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: DtEmptyState(
                icon: Icons.sell_outlined,
                title: '还没有标签',
                body: '在角色编辑器里添加标签，即可按标签整理角色卡。',
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 2, 16, 30),
              sliver: SliverList.separated(
                itemCount: orderedTags.length,
                separatorBuilder: (_, __) => const SizedBox(height: 9),
                itemBuilder: (context, index) {
                  final entry = orderedTags[index];
                  return DtStagger(
                    index: index,
                    child: DtSurface(
                      level: DtSurfaceLevel.raised,
                      borderRadius: 12,
                      onTap: () => setState(() {
                        _query = entry.key;
                        _tab = 0;
                      }),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: DtColors.brand.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.sell_outlined,
                              color: DtColors.brand,
                              size: 19,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              entry.key,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Text(
                            '${entry.value}',
                            style: TextStyle(
                              fontSize: 11,
                              color: dark
                                  ? const Color(0xFF8992A4)
                                  : DtColors.textTertiary,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.chevron_right_rounded, size: 20),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _CharacterTile extends StatelessWidget {
  const _CharacterTile({required this.character});

  final Character character;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final summary = character.intro.trim().isNotEmpty
        ? character.intro.trim()
        : character.persona.trim();
    return DtPressable(
      semanticLabel: character.name,
      onTap: () => context.push('/character/${character.id}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        child: Row(
          children: [
            DtAvatar(
              name: character.name,
              reference: character.avatarReference,
              color: character.avatarColor,
              size: 54,
              heroTag: 'character-${character.id}',
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
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (character.tags.isNotEmpty)
                        Text(
                          character.tags.first,
                          style: TextStyle(
                            fontSize: 10,
                            color: dark
                                ? const Color(0xFF7E8798)
                                : DtColors.textTertiary,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    summary.isEmpty ? '尚无角色描述' : summary,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      color: dark
                          ? const Color(0xFF949DB0)
                          : const Color(0xFF747D8D),
                    ),
                  ),
                  if (character.creator.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'by ${character.creator}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 9.5,
                        color: dark
                            ? const Color(0xFF6E7788)
                            : const Color(0xFFA0A7B2),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              Icons.chevron_right_rounded,
              color: dark ? const Color(0xFF5B6476) : const Color(0xFFB4BAC5),
            ),
          ],
        ),
      ),
    );
  }
}
