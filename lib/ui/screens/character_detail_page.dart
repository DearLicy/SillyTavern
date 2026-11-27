import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../application/app_controller.dart';
import '../../domain/models.dart';
import '../components/dt_avatar.dart';
import '../components/dt_controls.dart';
import '../components/dt_detail_page.dart';
import '../theme/dt_theme.dart';

class CharacterDetailPage extends ConsumerWidget {
  const CharacterDetailPage({super.key, required this.characterId});

  final String characterId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(appControllerProvider).data;
    final character = data.characters
        .where((item) => item.id == characterId)
        .firstOrNull;
    if (character == null) {
      return const DtDetailPage(
        title: '角色资料',
        child: Center(child: Text('角色不存在')),
      );
    }
    final relationship = data.relationships
        .where((item) => item.characterId == character.id)
        .firstOrNull;
    final thread = relationship == null
        ? null
        : data.threadForRelationship(relationship.id);
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: dark ? DtColors.darkBg : DtColors.mist,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 19),
        ),
        actions: [
          IconButton(
            onPressed: () => context.push('/character-editor/${character.id}'),
            icon: const Icon(Icons.edit_outlined),
            tooltip: '编辑角色',
          ),
          if (relationship != null)
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'memory') {
                  context.push('/memory/${relationship.id}');
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'memory', child: Text('长期记忆')),
              ],
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
        children: [
          _HeroCard(character: character),
          const SizedBox(height: 14),
          if (character.intro.trim().isNotEmpty)
            _TextCard(title: '角色描述', text: character.intro),
          if (character.persona.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            _TextCard(title: '性格与设定', text: character.persona),
          ],
          if (character.scenario.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            _TextCard(title: '场景', text: character.scenario),
          ],
          if (character.exampleDialogue.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            _TextCard(title: '对话示例', text: character.exampleDialogue),
          ],
          if (character.systemPrompt.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            _TextCard(title: '角色系统提示词', text: character.systemPrompt),
          ],
          if (character.postHistoryInstructions.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            _TextCard(title: '角色后置指令', text: character.postHistoryInstructions),
          ],
          if (character.creatorNotes.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            _TextCard(title: '作者注记', text: character.creatorNotes),
          ],
          if (character.voiceProfile.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            _TextCard(title: '语言风格', text: character.voiceProfile),
          ],
          if (character.personalPreferences.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            _TextCard(title: '补充设定', text: character.personalPreferences),
          ],
          if (character.greeting.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            _TextCard(title: '开场白', text: character.greeting),
          ],
          if (character.alternateGreetings.isNotEmpty) ...[
            const SizedBox(height: 12),
            DtSurface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '备选开场',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 9),
                  for (var i = 0; i < character.alternateGreetings.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        '${i + 1}. ${character.alternateGreetings[i]}',
                        maxLines: 6,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13, height: 1.6),
                      ),
                    ),
                  DtButton(
                    label: '复制全部备选开场',
                    variant: DtButtonVariant.secondary,
                    onPressed: () async {
                      await Clipboard.setData(
                        ClipboardData(
                          text: character.alternateGreetings.join('\n\n'),
                        ),
                      );
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(const SnackBar(content: Text('备选开场已复制')));
                    },
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 18),
          if (thread != null) ...[
            DtSettingRow(
              icon: Icons.manage_history_rounded,
              title: '聊天与数据',
              subtitle: '查找记录、清空聊天、创建分支或删除角色',
              onTap: () => context.push('/chat-data/${thread.id}'),
            ),
            const SizedBox(height: 8),
            DtButton(
              label: '进入对话',
              icon: Icons.chat_bubble_outline_rounded,
              onPressed: () => context.push('/chat/${thread.id}'),
            ),
          ] else
            DtButton(
              label: '开始第一段对话',
              icon: Icons.chat_bubble_outline_rounded,
              onPressed: () async {
                try {
                  final created = ref
                      .read(appControllerProvider.notifier)
                      .startChatForCharacter(character.id);
                  if (!context.mounted) return;
                  context.push('/chat/${created.id}');
                } catch (error) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('$error')));
                }
              },
            ),
        ],
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.character});

  final Character character;

  @override
  Widget build(BuildContext context) {
    final color = Color(character.avatarColor);
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.92),
            Color.lerp(color, Colors.black, 0.24) ?? color,
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.24),
            blurRadius: 26,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          DtAvatar(
            name: character.name,
            reference: character.avatarReference,
            color: character.avatarColor,
            size: 92,
          ),
          const SizedBox(height: 14),
          Text(
            character.name,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            character.handle,
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
          if (character.creator.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              '角色卡作者 · ${character.creator}',
              style: const TextStyle(color: Colors.white70, fontSize: 10),
            ),
          ],
          if (character.tags.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              alignment: WrapAlignment.center,
              children: [
                for (final tag in character.tags)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Text(
                      tag,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _TextCard extends StatelessWidget {
  const _TextCard({required this.title, required this.text});

  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return DtSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 9),
          Text(text, style: const TextStyle(fontSize: 13.5, height: 1.65)),
        ],
      ),
    );
  }
}
