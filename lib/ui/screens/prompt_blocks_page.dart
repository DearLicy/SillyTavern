import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:uuid/uuid.dart';

import '../../application/app_controller.dart';
import '../../domain/models.dart';
import '../components/dt_controls.dart';
import '../components/dt_detail_page.dart';
import '../components/dt_edit_sheet.dart';
import '../components/dt_input.dart';
import '../theme/dt_theme.dart';

class PromptBlocksPage extends ConsumerStatefulWidget {
  const PromptBlocksPage({super.key});

  @override
  ConsumerState<PromptBlocksPage> createState() => _PromptBlocksPageState();
}

enum _BlockAction { moveUp, moveDown, delete }

class _PromptBlocksPageState extends ConsumerState<PromptBlocksPage> {
  bool _saving = false;

  List<PromptBlock> _normalized(List<PromptBlock> blocks) {
    final ordered = [...blocks]..sort((a, b) => a.order.compareTo(b.order));
    return [
      for (var index = 0; index < ordered.length; index++)
        ordered[index].copyWith(order: index),
    ];
  }

  Future<void> _persist(List<PromptBlock> blocks) async {
    if (_saving) return;
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final prompts = ref.read(appControllerProvider).data.settings.prompts;
      await ref
          .read(appControllerProvider.notifier)
          .savePromptConfig(prompts.copyWith(blocks: _normalized(blocks)));
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            error is FormatException
                ? error.message
                : 'Prompt Manager 保存失败：$error',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _edit([PromptBlock? existing]) async {
    final prompts = ref.read(appControllerProvider).data.settings.prompts;
    final result = await Navigator.of(context).push<PromptBlock>(
      MaterialPageRoute<PromptBlock>(
        builder: (_) => PromptBlockEditorPage(
          existing: existing,
          nextOrder: prompts.blocks.length,
        ),
      ),
    );
    if (result == null || !mounted) return;
    final blocks = [...prompts.blocks];
    final index = blocks.indexWhere((block) => block.id == result.id);
    if (index < 0) {
      blocks.add(result);
    } else {
      blocks[index] = result;
    }
    await _persist(blocks);
  }

  Future<void> _toggle(PromptBlock block, bool enabled) async {
    final prompts = ref.read(appControllerProvider).data.settings.prompts;
    await _persist([
      for (final item in prompts.blocks)
        item.id == block.id ? item.copyWith(enabled: enabled) : item,
    ]);
  }

  Future<void> _move(PromptBlock block, int delta) async {
    final prompts = ref.read(appControllerProvider).data.settings.prompts;
    final ordered = _normalized(prompts.blocks);
    final index = ordered.indexWhere((item) => item.id == block.id);
    final target = index + delta;
    if (index < 0 || target < 0 || target >= ordered.length) return;
    final moved = ordered.removeAt(index);
    ordered.insert(target, moved);
    await _persist(ordered);
  }

  Future<void> _delete(PromptBlock block) async {
    final confirmed = await showDtEditSheet(
      context: context,
      title: '删除“${block.name}”？',
      description: '只删除这个 Prompt Manager 条目，不影响角色卡、世界书或聊天记录。',
      actionLabel: '删除提示词',
      danger: true,
      onSubmit: (_) async {},
    );
    if (confirmed != true || !mounted) return;
    final prompts = ref.read(appControllerProvider).data.settings.prompts;
    await _persist(
      prompts.blocks.where((item) => item.id != block.id).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final prompts = ref.watch(appControllerProvider).data.settings.prompts;
    final blocks = _normalized(prompts.blocks);
    return DtDetailPage(
      title: 'Prompt Manager',
      subtitle: '命名提示词 · 角色 · 注入位置',
      actions: [
        DtIconButton(
          icon: Icons.add_rounded,
          tooltip: '新增提示词块',
          onTap: _saving ? null : () => _edit(),
        ),
      ],
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
        children: [
          DtSurface(
            level: DtSurfaceLevel.tinted,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline_rounded, size: 19),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '提示词块按顺序组合进上下文。角色卡前/后使用 System 位置；历史前和指定深度会按所选角色注入。平台安全与用户本轮纠正始终优先。',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.6,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFFA7A096)
                          : DtColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (blocks.isEmpty)
            DtEmptyState(
              icon: Icons.view_list_outlined,
              title: '还没有提示词块',
              body: '导入 Chat Completion 预设时会保留命名提示词，也可以手动添加移动端常用的表达规则。',
              action: DtButton(label: '新增提示词块', onPressed: () => _edit()),
            )
          else
            for (var index = 0; index < blocks.length; index++) ...[
              _PromptBlockTile(
                key: ValueKey('prompt-block-${blocks[index].id}'),
                block: blocks[index],
                canMoveUp: index > 0,
                canMoveDown: index < blocks.length - 1,
                onTap: _saving ? null : () => _edit(blocks[index]),
                onToggle: _saving
                    ? null
                    : (value) => _toggle(blocks[index], value),
                onAction: (action) {
                  switch (action) {
                    case _BlockAction.moveUp:
                      _move(blocks[index], -1);
                      break;
                    case _BlockAction.moveDown:
                      _move(blocks[index], 1);
                      break;
                    case _BlockAction.delete:
                      _delete(blocks[index]);
                      break;
                  }
                },
              ),
              if (index != blocks.length - 1) const SizedBox(height: 9),
            ],
          if (_saving) ...[
            const SizedBox(height: 14),
            const LinearProgressIndicator(minHeight: 2),
          ],
        ],
      ),
    );
  }
}

class _PromptBlockTile extends StatelessWidget {
  const _PromptBlockTile({
    super.key,
    required this.block,
    required this.canMoveUp,
    required this.canMoveDown,
    required this.onTap,
    required this.onToggle,
    required this.onAction,
  });

  final PromptBlock block;
  final bool canMoveUp;
  final bool canMoveDown;
  final VoidCallback? onTap;
  final ValueChanged<bool>? onToggle;
  final ValueChanged<_BlockAction> onAction;

  @override
  Widget build(BuildContext context) {
    final position = block.position == PromptInjectionPosition.atDepth
        ? '${block.position.label} ${block.depth}'
        : block.position.label;
    return DtSurface(
      padding: EdgeInsets.zero,
      child: DtSettingRow(
        icon: switch (block.role) {
          PromptBlockRole.system => Icons.notes_rounded,
          PromptBlockRole.user => Icons.person_outline_rounded,
          PromptBlockRole.assistant => Icons.auto_awesome_outlined,
        },
        title: block.name,
        subtitle: '${block.role.label} · $position',
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            PopupMenuButton<_BlockAction>(
              tooltip: '提示词块操作',
              enabled: onTap != null,
              onSelected: onAction,
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: _BlockAction.moveUp,
                  enabled: canMoveUp,
                  child: const Text('上移'),
                ),
                PopupMenuItem(
                  value: _BlockAction.moveDown,
                  enabled: canMoveDown,
                  child: const Text('下移'),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: _BlockAction.delete,
                  child: Text('删除'),
                ),
              ],
              icon: const Icon(Icons.more_horiz_rounded, size: 20),
            ),
            FSwitch(value: block.enabled, onChange: onToggle),
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}

class PromptBlockEditorPage extends StatefulWidget {
  const PromptBlockEditorPage({
    super.key,
    this.existing,
    required this.nextOrder,
  });

  final PromptBlock? existing;
  final int nextOrder;

  @override
  State<PromptBlockEditorPage> createState() => _PromptBlockEditorPageState();
}

class _PromptBlockEditorPageState extends State<PromptBlockEditorPage> {
  late final TextEditingController _name;
  late final TextEditingController _content;
  late final TextEditingController _depth;
  late PromptBlockRole _role;
  late PromptInjectionPosition _position;
  late bool _enabled;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _name = TextEditingController(text: existing?.name ?? '');
    _content = TextEditingController(text: existing?.content ?? '');
    _depth = TextEditingController(text: '${existing?.depth ?? 0}');
    _role = existing?.role ?? PromptBlockRole.system;
    _position = existing?.position ?? PromptInjectionPosition.beforeHistory;
    _enabled = existing?.enabled ?? true;
  }

  @override
  void dispose() {
    _name.dispose();
    _content.dispose();
    _depth.dispose();
    super.dispose();
  }

  void _save() {
    final name = _name.text.trim();
    final content = _content.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请填写提示词块名称')));
      return;
    }
    if (content.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请填写提示词内容')));
      return;
    }
    final existing = widget.existing;
    Navigator.of(context).pop(
      PromptBlock(
        id: existing?.id ?? 'prompt_${const Uuid().v4()}',
        name: name,
        content: content,
        role: _role,
        position: _position,
        depth: _position == PromptInjectionPosition.atDepth
            ? (int.tryParse(_depth.text.trim()) ?? 0).clamp(0, 100)
            : 0,
        enabled: _enabled,
        order: existing?.order ?? widget.nextOrder,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DtDetailPage(
      title: widget.existing == null ? '新增提示词块' : '编辑提示词块',
      subtitle: '声明式文本，不执行脚本或远程代码',
      bottom: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: DtButton(
            label: '保存提示词块',
            successText: '已保存',
            onPressed: _save,
          ),
        ),
      ),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DtSurface(
            child: Column(
              children: [
                DtTextField(
                  controller: _name,
                  decoration: const InputDecoration(labelText: '名称'),
                ),
                const SizedBox(height: 12),
                DtTextField(
                  controller: _content,
                  minLines: 8,
                  maxLines: 18,
                  decoration: const InputDecoration(
                    labelText: '提示词内容',
                    hintText: '例如：保持短句和自然停顿，不要总结对话。',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          DtSurface(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                DtSettingRow(
                  icon: Icons.badge_outlined,
                  title: '消息角色',
                  subtitle: _role.label,
                  trailing: SizedBox(
                    width: 130,
                    child: FSelect<PromptBlockRole>(
                      items: const {
                        'System': PromptBlockRole.system,
                        'User': PromptBlockRole.user,
                        'Assistant': PromptBlockRole.assistant,
                      },
                      initialValue: _role,
                      onChange: (value) {
                        if (value != null) setState(() => _role = value);
                      },
                    ),
                  ),
                ),
                const Divider(indent: 62),
                DtSettingRow(
                  icon: Icons.vertical_align_bottom_rounded,
                  title: '注入位置',
                  subtitle: _position.label,
                  trailing: SizedBox(
                    width: 145,
                    child: FSelect<PromptInjectionPosition>(
                      items: const {
                        '角色卡前': PromptInjectionPosition.beforeCharacter,
                        '角色卡后': PromptInjectionPosition.afterCharacter,
                        '历史前': PromptInjectionPosition.beforeHistory,
                        '历史深度': PromptInjectionPosition.atDepth,
                      },
                      initialValue: _position,
                      onChange: (value) {
                        if (value != null) setState(() => _position = value);
                      },
                    ),
                  ),
                ),
                if (_position == PromptInjectionPosition.atDepth) ...[
                  const Divider(indent: 62),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
                    child: DtTextField(
                      controller: _depth,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: '距当前消息的深度',
                        hintText: '0 = 当前用户消息之前',
                      ),
                    ),
                  ),
                ],
                const Divider(indent: 62),
                DtSettingRow(
                  icon: Icons.toggle_on_outlined,
                  title: '启用提示词块',
                  trailing: FSwitch(
                    value: _enabled,
                    onChange: (value) => setState(() => _enabled = value),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            '角色卡前/后会作为 System 文本插入。历史前和历史深度会按所选角色插入，但都不能覆盖平台安全或用户本轮停止要求。',
            style: TextStyle(
              fontSize: 12,
              height: 1.6,
              color: DtColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
