import '../components/dt_input.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/app_controller.dart';
import '../../domain/models.dart';
import '../components/dt_controls.dart';
import '../components/dt_detail_page.dart';
import '../theme/dt_theme.dart';

class ConsentPage extends ConsumerStatefulWidget {
  const ConsentPage({super.key, required this.relationshipId});

  final String relationshipId;

  @override
  ConsumerState<ConsentPage> createState() => _ConsentPageState();
}

class _ConsentPageState extends ConsumerState<ConsentPage> {
  late final TextEditingController _safeWord;
  late final TextEditingController _allowed;
  late final TextEditingController _blocked;
  late ContentLevel _level;
  late bool _paused;

  @override
  void initState() {
    super.initState();
    final relationship = ref
        .read(appControllerProvider)
        .data
        .relationships
        .where((e) => e.id == widget.relationshipId)
        .firstOrNull;
    final consent = relationship?.consent ?? const ConsentProfile();
    _safeWord = TextEditingController(text: consent.safeWord);
    _allowed = TextEditingController(text: consent.allowedThemes.join('、'));
    _blocked = TextEditingController(text: consent.blockedThemes.join('、'));
    _level = consent.ceiling;
    _paused = consent.paused;
  }

  @override
  void dispose() {
    _safeWord.dispose();
    _allowed.dispose();
    _blocked.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(appControllerProvider).data;
    final relationship = data.relationships
        .where((e) => e.id == widget.relationshipId)
        .firstOrNull;
    final character = relationship == null
        ? null
        : data.characterForRelationship(relationship);
    if (relationship == null) {
      return const DtDetailPage(
        title: '内容与边界',
        child: Center(child: Text('关系不存在')),
      );
    }
    return DtDetailPage(
      title: '内容与边界',
      subtitle: character == null ? '只影响这段关系' : '只影响与 ${character.name} 的关系',
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DtSurface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '内容级别',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 5),
                const Text(
                  '全局设置是上限，这里只能下调或达到全局上限。',
                  style: TextStyle(fontSize: 11.5, height: 1.45),
                ),
                const SizedBox(height: 12),
                for (final level in ContentLevel.values)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _LevelTile(
                      level: level,
                      selected: _level == level,
                      disabled:
                          level.index > data.settings.contentCeiling.index,
                      onTap: () => setState(() => _level = level),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          DtSurface(
            child: Column(
              children: [
                DtTextField(
                  controller: _allowed,
                  decoration: const InputDecoration(
                    labelText: '允许主题',
                    hintText: '日常互动、剧情冒险、悬疑……',
                  ),
                ),
                const SizedBox(height: 12),
                DtTextField(
                  controller: _blocked,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: '明确禁止',
                    hintText: '强迫、羞辱、永久伤害……',
                  ),
                ),
                const SizedBox(height: 12),
                DtTextField(
                  controller: _safeWord,
                  decoration: const InputDecoration(
                    labelText: '安全词',
                    hintText: 'red',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          DtSurface(
            padding: EdgeInsets.zero,
            child: DtSwitchRow(
              value: _paused,
              onChanged: (value) => setState(() => _paused = value),
              title: const Text(
                '暂停当前亲密场景',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              subtitle: const Text(
                '暂停后角色只提供非亲密陪伴，等待你重新确认。',
                style: TextStyle(fontSize: 11),
              ),
              secondary: const Icon(
                Icons.pause_circle_outline_rounded,
                color: DtColors.coral,
              ),
            ),
          ),
          const SizedBox(height: 18),
          DtButton(
            label: '保存边界',
            onPressed: () {
              final allowed = _allowed.text
                  .split(RegExp(r'[、,，]'))
                  .map((e) => e.trim())
                  .where((e) => e.isNotEmpty)
                  .toList();
              final blocked = _blocked.text
                  .split(RegExp(r'[、,，]'))
                  .map((e) => e.trim())
                  .where((e) => e.isNotEmpty)
                  .toList();
              final updated = relationship.copyWith(
                consent: ConsentProfile(
                  ceiling: _level,
                  allowedThemes: allowed,
                  blockedThemes: blocked,
                  safeWord: _safeWord.text.trim().isEmpty
                      ? 'red'
                      : _safeWord.text.trim(),
                  paused: _paused,
                ),
                updatedAt: DateTime.now(),
              );
              ref
                  .read(appControllerProvider.notifier)
                  .updateRelationship(updated);
              Navigator.pop(context);
            },
          ),
          const SizedBox(height: 10),
          DtButton(
            label: '立即停止当前场景',
            icon: Icons.emergency_rounded,
            variant: DtButtonVariant.danger,
            onPressed: () {
              final updated = relationship.copyWith(
                consent: relationship.consent.copyWith(paused: true),
                updatedAt: DateTime.now(),
              );
              ref
                  .read(appControllerProvider.notifier)
                  .updateRelationship(updated);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('已停止当前亲密场景。角色只会进行安全确认与非亲密陪伴。')),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _LevelTile extends StatelessWidget {
  const _LevelTile({
    required this.level,
    required this.selected,
    required this.disabled,
    required this.onTap,
  });

  final ContentLevel level;
  final bool selected;
  final bool disabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Opacity(
      opacity: disabled ? 0.42 : 1,
      child: InkWell(
        onTap: disabled ? null : onTap,
        borderRadius: BorderRadius.circular(15),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            color: selected
                ? DtColors.brand.withValues(alpha: dark ? 0.16 : 0.08)
                : (dark ? const Color(0xFF1B202D) : const Color(0xFFF5F7FA)),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: selected
                  ? DtColors.brand.withValues(alpha: 0.55)
                  : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_off_rounded,
                size: 20,
                color: selected
                    ? DtColors.brand
                    : (dark
                          ? const Color(0xFF778094)
                          : const Color(0xFFA0A7B6)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      level.label,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      level.description,
                      style: const TextStyle(fontSize: 10.5),
                    ),
                  ],
                ),
              ),
              if (level == ContentLevel.nsfw)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: DtColors.coral.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: const Text(
                    '18+',
                    style: TextStyle(
                      color: DtColors.coral,
                      fontSize: 8,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
