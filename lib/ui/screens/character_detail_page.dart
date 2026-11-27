import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../application/app_controller.dart';
import '../../ai/relationship_dynamics.dart';
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
        .where((e) => e.id == characterId)
        .firstOrNull;
    if (character == null) {
      return const DtDetailPage(
        title: '角色资料',
        child: Center(child: Text('角色不存在')),
      );
    }
    final relationship = data.relationships
        .where((e) => e.characterId == character.id)
        .firstOrNull;
    final persona = relationship == null
        ? null
        : data.personaById(relationship.personaId);
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
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'memory' && relationship != null) {
                context.push('/memory/${relationship.id}');
              }
              if (value == 'director' && relationship != null) {
                context.push('/director/${relationship.id}');
              }
              if (value == 'consent' && relationship != null) {
                context.push('/consent/${relationship.id}');
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'memory', child: Text('记忆管理')),
              PopupMenuItem(value: 'director', child: Text('导演模式')),
              PopupMenuItem(value: 'consent', child: Text('内容与边界')),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
        children: [
          _HeroCard(character: character, relationship: relationship),
          if (relationship != null) ...[
            const SizedBox(height: 14),
            _RelationshipPanel(relationship: relationship, persona: persona),
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
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('备选开场已复制')),
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          DtSurface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '角色设定',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 9),
                Text(
                  character.persona,
                  style: const TextStyle(fontSize: 13.5, height: 1.65),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          DtSurface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '当前场景',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                if (relationship == null)
                  const Text('尚未建立关系')
                else ...[
                  _InfoLine(
                    icon: Icons.place_outlined,
                    text: relationship.scene.location,
                  ),
                  _InfoLine(
                    icon: Icons.schedule_rounded,
                    text: relationship.scene.timeHint,
                  ),
                  _InfoLine(
                    icon: Icons.mood_outlined,
                    text: relationship.scene.mood,
                  ),
                  if (relationship.scene.notes.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        relationship.scene.notes,
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 1.55,
                          color: dark
                              ? const Color(0xFF96A0B4)
                              : const Color(0xFF737C8E),
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 18),
          if (thread != null)
            DtSettingRow(
              icon: Icons.manage_history_rounded,
              title: '聊天与数据',
              subtitle: '查找记录、清空聊天、重新开始或删除角色',
              onTap: () => context.push('/chat-data/${thread.id}'),
            ),
          if (thread != null)
            DtButton(
              label: '进入对话',
              icon: Icons.chat_bubble_outline_rounded,
              onPressed: () => context.push('/chat/${thread.id}'),
            ),
        ],
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.character, required this.relationship});

  final Character character;
  final Relationship? relationship;

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
            color: color.withValues(alpha: 0.26),
            blurRadius: 28,
            offset: const Offset(0, 12),
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
            showStatus: true,
          ),
          const SizedBox(height: 14),
          Text(
            character.name,
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
          const SizedBox(height: 8),
          Text(
            character.intro,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              height: 1.55,
            ),
          ),
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
      ),
    );
  }
}

class _RelationshipPanel extends StatelessWidget {
  const _RelationshipPanel({required this.relationship, required this.persona});

  final Relationship relationship;
  final UserPersona? persona;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final deltas = relationship.lastMetricDelta.entries
        .where((entry) => entry.value != 0)
        .map(
          (entry) =>
              '${RelationshipDynamics.displayLabel(entry.key)} ${entry.value > 0 ? '+' : ''}${entry.value}',
        )
        .join(' · ');
    return DtSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                '关系',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: DtColors.violet.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  relationship.stage,
                  style: const TextStyle(
                    color: DtColors.violet,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                '用户人设 · ${persona?.name ?? '未设置'}',
                style: TextStyle(
                  fontSize: 11.5,
                  color: dark
                      ? const Color(0xFF99A2B5)
                      : const Color(0xFF747D90),
                ),
              ),
              const Spacer(),
              Text(
                '称呼 · ${relationship.nickname}',
                style: TextStyle(
                  fontSize: 11.5,
                  color: dark
                      ? const Color(0xFF99A2B5)
                      : const Color(0xFF747D90),
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
                      SizedBox(
                        width: 48,
                        height: 48,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            CircularProgressIndicator(
                              value: (entry.value / 100).clamp(0, 1),
                              strokeWidth: 4,
                              backgroundColor: dark
                                  ? const Color(0xFF293042)
                                  : const Color(0xFFEDF1F8),
                              color: entry.key == '心动'
                                  ? DtColors.rose
                                  : DtColors.brand,
                            ),
                            Text(
                              '${entry.value}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        RelationshipDynamics.displayLabel(entry.key),
                        style: TextStyle(
                          fontSize: 10.5,
                          color: dark
                              ? const Color(0xFF9099AD)
                              : const Color(0xFF7F889A),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
            decoration: BoxDecoration(
              color: dark ? const Color(0xFF202636) : const Color(0xFFF5F3FC),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  deltas.isEmpty ? '关系会随真实互动自然变化' : '上轮变化 · $deltas',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: dark ? const Color(0xFFCBC4F7) : DtColors.violet,
                  ),
                ),
                if (relationship.lastMetricReason.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    relationship.lastMetricReason,
                    style: TextStyle(
                      fontSize: 10.5,
                      height: 1.45,
                      color: dark
                          ? const Color(0xFF9199AA)
                          : const Color(0xFF7D8494),
                    ),
                  ),
                ],
                const SizedBox(height: 3),
                Text(
                  '已完成 ${relationship.interactionCount} 轮关系互动',
                  style: TextStyle(
                    fontSize: 9.5,
                    color: dark
                        ? const Color(0xFF6E778B)
                        : const Color(0xFF9CA3B2),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: DtColors.brand),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 12.5))),
        ],
      ),
    );
  }
}
