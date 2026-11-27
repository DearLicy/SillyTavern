import '../components/dt_input.dart';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/app_controller.dart';
import '../../domain/models.dart';
import '../components/dt_controls.dart';
import '../components/dt_detail_page.dart';
import '../theme/dt_theme.dart';

class DirectorPage extends ConsumerStatefulWidget {
  const DirectorPage({super.key, required this.relationshipId});

  final String relationshipId;

  @override
  ConsumerState<DirectorPage> createState() => _DirectorPageState();
}

class _DirectorPageState extends ConsumerState<DirectorPage> {
  late double _narration;
  late double _autonomy;
  late double _intimacy;
  late Pacing _pacing;
  late final TextEditingController _instructions;

  @override
  void initState() {
    super.initState();
    final relationship = ref
        .read(appControllerProvider)
        .data
        .relationships
        .where((e) => e.id == widget.relationshipId)
        .firstOrNull;
    final director = relationship?.scene.director ?? const DirectorConfig();
    _narration = director.narration;
    _autonomy = director.autonomy;
    _intimacy = director.intimacy;
    _pacing = director.pacing;
    _instructions = TextEditingController(text: director.instructions);
  }

  @override
  void dispose() {
    _instructions.dispose();
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
        title: '导演模式',
        child: Center(child: Text('关系不存在')),
      );
    }
    return DtDetailPage(
      title: '导演模式',
      subtitle: character == null
          ? '调整当前场景'
          : '只改变 ${character.name} 此刻的剧情，不改角色卡',
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DtSurface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '剧情节奏',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                DtSegmentedControl(
                  labels: const ['慢热', '自然', '强推进'],
                  index: Pacing.values.indexOf(_pacing),
                  onChanged: (index) =>
                      setState(() => _pacing = Pacing.values[index]),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          DtSurface(
            child: Column(
              children: [
                _SliderRow(
                  title: '旁白比例',
                  value: _narration,
                  onChanged: (value) => setState(() => _narration = value),
                  hint: '少旁白只保留对话，多旁白强化环境与动作。',
                ),
                Divider(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF252B39)
                      : const Color(0xFFEDF0F6),
                ),
                _SliderRow(
                  title: '角色主动性',
                  value: _autonomy,
                  onChanged: (value) => setState(() => _autonomy = value),
                  hint: '控制角色是否主动抛出话题、行动和剧情钩子。',
                ),
                Divider(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF252B39)
                      : const Color(0xFFEDF0F6),
                ),
                _SliderRow(
                  title: '关系推进强度',
                  value: _intimacy,
                  onChanged: (value) => setState(() => _intimacy = value),
                  hint: '仍受关系内容上限与用户硬边界约束。',
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          DtSurface(
            child: DtTextField(
              controller: _instructions,
              minLines: 4,
              maxLines: 8,
              decoration: const InputDecoration(
                labelText: '本轮导演指令',
                hintText: '例如：让关心落在动作里，不要连续追问；本场景只推进到拥抱。',
              ),
            ),
          ),
          const SizedBox(height: 18),
          DtButton(
            label: '应用导演设置',
            onPressed: () {
              final updated = relationship.copyWith(
                scene: relationship.scene.copyWith(
                  director: DirectorConfig(
                    pacing: _pacing,
                    narration: _narration,
                    autonomy: _autonomy,
                    intimacy: _intimacy,
                    instructions: _instructions.text.trim(),
                  ),
                ),
                updatedAt: DateTime.now(),
              );
              ref
                  .read(appControllerProvider.notifier)
                  .updateRelationship(updated);
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }
}

class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.title,
    required this.value,
    required this.onChanged,
    required this.hint,
  });

  final String title;
  final double value;
  final ValueChanged<double> onChanged;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            Text(
              '${(value * 100).round()}%',
              style: const TextStyle(
                color: DtColors.brand,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        FSlider(
          controller: null,
          initialSelection: FSliderSelection(max: value),
          onChange: (selection) => onChanged(selection.offset.max),
        ),
        Text(
          hint,
          style: TextStyle(
            fontSize: 10.5,
            height: 1.4,
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF7F889C)
                : const Color(0xFF8C95A7),
          ),
        ),
      ],
    );
  }
}
