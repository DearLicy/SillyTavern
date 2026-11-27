import '../components/dt_input.dart';
import '../components/dt_avatar_editor.dart';
import '../../data/image_content.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../application/app_controller.dart';
import '../../domain/models.dart';
import '../components/dt_detail_page.dart';
import '../components/dt_controls.dart';

class CharacterEditorPage extends ConsumerStatefulWidget {
  const CharacterEditorPage({super.key, required this.characterId});

  final String characterId;

  @override
  ConsumerState<CharacterEditorPage> createState() =>
      _CharacterEditorPageState();
}

class _CharacterEditorPageState extends ConsumerState<CharacterEditorPage> {
  late final TextEditingController _name;
  late final TextEditingController _handle;
  late final TextEditingController _age;
  late final TextEditingController _intro;
  late final TextEditingController _persona;
  late final TextEditingController _scenario;
  late final TextEditingController _exampleDialogue;
  late final TextEditingController _systemPrompt;
  late final TextEditingController _postHistoryInstructions;
  late final TextEditingController _creatorNotes;
  late final TextEditingController _voiceProfile;
  late final TextEditingController _personalPreferences;
  late final TextEditingController _greeting;
  late final TextEditingController _tags;
  String? _existingId;
  late final String _draftId = 'char_${const Uuid().v4()}';
  int _color = 0xFF4F7DF3;

  AvatarChange? _avatarChange;
  String? _avatarReference;
  DtButtonStatus _saveStatus = DtButtonStatus.idle;
  String? _saveError;

  @override
  void initState() {
    super.initState();
    final data = ref.read(appControllerProvider).data;
    final existing = data.characters
        .where((e) => e.id == widget.characterId)
        .firstOrNull;
    _existingId = existing?.id;
    _name = TextEditingController(text: existing?.name ?? '');
    _handle = TextEditingController(text: existing?.handle ?? '');
    _age = TextEditingController(text: existing?.age ?? '成年');
    _intro = TextEditingController(text: existing?.intro ?? '');
    _persona = TextEditingController(text: existing?.persona ?? '');
    _scenario = TextEditingController(text: existing?.scenario ?? '');
    _exampleDialogue = TextEditingController(
      text: existing?.exampleDialogue ?? '',
    );
    _systemPrompt = TextEditingController(text: existing?.systemPrompt ?? '');
    _postHistoryInstructions = TextEditingController(
      text: existing?.postHistoryInstructions ?? '',
    );
    _creatorNotes = TextEditingController(text: existing?.creatorNotes ?? '');
    _voiceProfile = TextEditingController(text: existing?.voiceProfile ?? '');
    _personalPreferences = TextEditingController(
      text: existing?.personalPreferences ?? '',
    );
    _greeting = TextEditingController(text: existing?.greeting ?? '');
    _tags = TextEditingController(text: existing?.tags.join('、') ?? '');
    _avatarReference = existing?.avatarReference;
    _color = existing?.avatarColor ?? 0xFF4F7DF3;
  }

  @override
  void dispose() {
    for (final controller in [
      _name,
      _handle,
      _age,
      _intro,
      _persona,
      _scenario,
      _exampleDialogue,
      _systemPrompt,
      _postHistoryInstructions,
      _creatorNotes,
      _voiceProfile,
      _personalPreferences,
      _greeting,
      _tags,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DtDetailPage(
      title: _existingId == null ? '创建角色' : '编辑角色',
      subtitle: '角色必须是明确成年人，并保持稳定人设与边界',
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: DtAvatarEditor(
              name: _name.text,
              color: _color,
              reference: _avatarReference,
              change: _avatarChange,
              onChanged: (change) => setState(() => _avatarChange = change),
            ),
          ),
          const SizedBox(height: 16),
          if (_saveError != null)
            Text(
              _saveError!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          DtSurface(
            child: Column(
              children: [
                DtTextField(
                  controller: _name,
                  decoration: const InputDecoration(labelText: '角色名'),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DtTextField(
                        controller: _handle,
                        decoration: const InputDecoration(
                          labelText: '用户名',
                          hintText: '@name',
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DtTextField(
                        controller: _age,
                        decoration: const InputDecoration(labelText: '年龄'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                DtTextField(
                  controller: _intro,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(labelText: '公开简介'),
                ),
                const SizedBox(height: 12),
                DtTextField(
                  controller: _persona,
                  minLines: 5,
                  maxLines: 10,
                  decoration: const InputDecoration(
                    labelText: '稳定人设',
                    hintText: '身份、性格、表达方式、不可违背的边界……',
                  ),
                ),
                const SizedBox(height: 12),
                DtTextField(
                  controller: _scenario,
                  minLines: 2,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: '场景',
                    hintText: '这段角色扮演发生的地点、时间和初始情境',
                  ),
                ),
                const SizedBox(height: 12),
                DtTextField(
                  controller: _exampleDialogue,
                  minLines: 3,
                  maxLines: 8,
                  decoration: const InputDecoration(
                    labelText: '对话示例',
                    hintText: '{{user}}: ...\n{{char}}: ...',
                  ),
                ),
                const SizedBox(height: 12),
                DtTextField(
                  controller: _systemPrompt,
                  minLines: 2,
                  maxLines: 6,
                  decoration: const InputDecoration(
                    labelText: '角色系统提示词',
                    hintText: '角色卡的 system_prompt；不能覆盖平台安全约束',
                  ),
                ),
                const SizedBox(height: 12),
                DtTextField(
                  controller: _postHistoryInstructions,
                  minLines: 2,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: '角色后置指令',
                    hintText: 'post_history_instructions，用于格式和收尾约束',
                  ),
                ),
                const SizedBox(height: 12),
                DtTextField(
                  controller: _voiceProfile,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: '说话习惯与禁区',
                    hintText: '例如：多用短句、爱用“行吧”；绝不写“希望这能帮到你”、不在结尾硬加问号',
                  ),
                ),
                const SizedBox(height: 12),
                DtTextField(
                  controller: _creatorNotes,
                  minLines: 2,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: '作者注记',
                    hintText: '只对人类读者有用，不应当成角色指令执行',
                  ),
                ),
                const SizedBox(height: 12),
                DtTextField(
                  controller: _personalPreferences,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: '日常偏好与小坚持',
                    hintText: '喜欢或讨厌什么、无害但坚定的偏见；不要编造经历',
                  ),
                ),
                const SizedBox(height: 12),
                DtTextField(
                  controller: _greeting,
                  minLines: 3,
                  maxLines: 6,
                  decoration: const InputDecoration(labelText: '初次问候'),
                ),
                const SizedBox(height: 12),
                DtTextField(
                  controller: _tags,
                  decoration: const InputDecoration(
                    labelText: '标签',
                    hintText: '用顿号或逗号分隔',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          DtButton(
            label: _existingId == null ? '创建并开始对话' : '保存角色',
            status: _saveStatus,
            successText: '已保存',
            onPressed: () async {
              if (_saveStatus != DtButtonStatus.idle) return;
              if (_name.text.trim().isEmpty) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('请填写角色名')));
                return;
              }
              final controller = ref.read(appControllerProvider.notifier);
              final id = _existingId ?? _draftId;
              final prior = ref
                  .read(appControllerProvider)
                  .data
                  .characters
                  .where((item) => item.id == id)
                  .firstOrNull;
              final character = Character(
                id: id,
                avatarReference: _avatarReference,
                name: _name.text.trim().isEmpty ? '未命名角色' : _name.text.trim(),
                handle: _handle.text.trim().isEmpty
                    ? '@character'
                    : _handle.text.trim(),
                age: _age.text.trim().isEmpty ? '成年' : _age.text.trim(),
                intro: _intro.text.trim(),
                persona: _persona.text.trim(),
                scenario: _scenario.text.trim(),
                exampleDialogue: _exampleDialogue.text.trim(),
                systemPrompt: _systemPrompt.text.trim(),
                postHistoryInstructions: _postHistoryInstructions.text.trim(),
                creatorNotes: _creatorNotes.text.trim(),
                greeting: _greeting.text.trim(),
                avatarColor: _color,
                voiceProfile: _voiceProfile.text.trim(),
                personalPreferences: _personalPreferences.text.trim(),
                tags: _tags.text
                    .split(RegExp(r'[、,，]'))
                    .map((e) => e.trim())
                    .where((e) => e.isNotEmpty)
                    .toList(),
                alternateGreetings: prior?.alternateGreetings ?? const [],
                creator: prior?.creator ?? '',
              );
              setState(() {
                _saveStatus = DtButtonStatus.loading;
                _saveError = null;
              });
              try {
                final thread = await controller.saveCharacterProfile(
                  character,
                  avatar: _avatarChange,
                  create: _existingId == null,
                );
                if (!mounted) return;
                setState(() => _saveStatus = DtButtonStatus.success);
                await Future<void>.delayed(const Duration(milliseconds: 240));
                if (!mounted) return;
                if (thread != null) {
                  this.context.pushReplacement('/chat/${thread.id}');
                } else {
                  Navigator.pop(this.context);
                }
              } catch (_) {
                if (mounted) {
                  setState(() {
                    _saveStatus = DtButtonStatus.idle;
                    _saveError = '角色保存失败，请重试。';
                  });
                }
              }
            },
          ),
        ],
      ),
    );
  }
}
