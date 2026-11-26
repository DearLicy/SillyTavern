import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:uuid/uuid.dart';

import '../../application/app_controller.dart';
import '../../domain/models.dart';
import '../components/dt_controls.dart';
import '../components/dt_detail_page.dart';
import '../components/dt_input.dart';

class WorldBooksPage extends ConsumerStatefulWidget {
  const WorldBooksPage({super.key});

  @override
  ConsumerState<WorldBooksPage> createState() => _WorldBooksPageState();
}

class _WorldBooksPageState extends ConsumerState<WorldBooksPage> {
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appControllerProvider);
    final controller = ref.read(appControllerProvider.notifier);
    final books = state.data.worldBooks;
    return DtDetailPage(
      title: '世界书',
      subtitle: '关键词资料与作者注记',
      actions: [
        DtIconButton(
          icon: Icons.add_rounded,
          tooltip: '新建世界书',
          onTap: () => _edit(context, controller, null),
        ),
      ],
      child: books.isEmpty
          ? DtEmptyState(
              icon: Icons.menu_book_outlined,
              title: '还没有世界书',
              body: '创建词条后，聊天会在关键词命中时自动把资料加入提示词。',
              action: DtButton(
                label: '创建世界书',
                onPressed: () => _edit(context, controller, null),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: books.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final book = books[index];
                return DtSurface(
                  child: DtSettingRow(
                    icon: Icons.auto_stories_outlined,
                    title: book.name,
                    subtitle:
                        '${book.entries.length} 条词条 · 注记深度 ${book.authorNoteDepth}',
                    onTap: () => _edit(context, controller, book),
                  ),
                );
              },
            ),
    );
  }

  Future<void> _edit(
    BuildContext context,
    AppController controller,
    WorldBook? existing,
  ) async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final result = await navigator.push<WorldBook>(
      MaterialPageRoute<WorldBook>(
        builder: (_) => WorldBookEditorPage(bookId: existing?.id ?? 'new'),
      ),
    );
    if (result == null || !mounted) return;
    try {
      await controller.saveWorldBook(result, create: existing == null);
    } catch (_) {
      if (mounted) {
        messenger.showSnackBar(const SnackBar(content: Text('世界书保存失败，请重试。')));
      }
    }
  }
}

class WorldBookEditorPage extends ConsumerStatefulWidget {
  const WorldBookEditorPage({super.key, required this.bookId});

  final String bookId;

  @override
  ConsumerState<WorldBookEditorPage> createState() =>
      _WorldBookEditorPageState();
}

class _WorldBookEditorPageState extends ConsumerState<WorldBookEditorPage> {
  final _name = TextEditingController();
  final _authorNote = TextEditingController();
  final _depth = TextEditingController(text: '2');
  late List<WorldInfoEntry> _entries;
  bool _enabled = true;

  @override
  void initState() {
    super.initState();
    final book = ref
        .read(appControllerProvider)
        .data
        .worldBooks
        .where((e) => e.id == widget.bookId)
        .firstOrNull;
    _name.text = book?.name ?? '默认世界书';
    _authorNote.text = book?.authorNote ?? '';
    _depth.text = '${book?.authorNoteDepth ?? 2}';
    _enabled = book?.enabled ?? true;
    _entries = List<WorldInfoEntry>.of(book?.entries ?? const []);
  }

  @override
  void dispose() {
    _name.dispose();
    _authorNote.dispose();
    _depth.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DtDetailPage(
      title: widget.bookId == 'new' ? '新建世界书' : '编辑世界书',
      subtitle: '资料仅保存在本机，命中关键词后注入提示词',
      bottom: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: DtButton(
            label: '保存世界书',
            successText: '已保存',
            onPressed: () {
              if (_name.text.trim().isEmpty) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('请填写世界书名称')));
                return;
              }
              final book = WorldBook(
                id: widget.bookId == 'new'
                    ? 'wb_${const Uuid().v4()}'
                    : widget.bookId,
                name: _name.text.trim(),
                entries: _entries,
                authorNote: _authorNote.text.trim(),
                authorNoteDepth: int.tryParse(_depth.text.trim()) ?? 2,
                enabled: _enabled,
              );
              Navigator.of(context).pop(book);
            },
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
                Row(
                  children: [
                    const Expanded(child: Text('启用这本书')),
                    FSwitch(
                      value: _enabled,
                      onChange: (v) => setState(() => _enabled = v),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          DtSurface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '作者注记',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                DtTextField(
                  controller: _authorNote,
                  minLines: 3,
                  maxLines: 6,
                  decoration: const InputDecoration(
                    hintText: '写好角色语气、叙事视角等长期风格要求',
                  ),
                ),
                const SizedBox(height: 10),
                DtTextField(
                  controller: _depth,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: '注入深度（0–10）'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('词条', style: TextStyle(fontWeight: FontWeight.w700)),
              DtIconButton(
                icon: Icons.add_rounded,
                tooltip: '添加词条',
                onTap: () => _editEntry(context, null),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final entry in _entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: DtSurface(
                child: DtSettingRow(
                  icon: Icons.bookmark_border_rounded,
                  title: entry.comment.isEmpty
                      ? entry.keys.join('、')
                      : entry.comment,
                  subtitle: '${entry.mode.label} · ${entry.content}',
                  onTap: () => _editEntry(context, entry),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _editEntry(
    BuildContext context,
    WorldInfoEntry? existing,
  ) async {
    final result = await Navigator.of(context).push<WorldInfoEntry>(
      MaterialPageRoute<WorldInfoEntry>(
        builder: (_) => WorldInfoEditorPage(entryId: existing?.id ?? 'new'),
      ),
    );
    if (result == null) return;
    setState(() {
      if (existing == null) {
        _entries.add(result);
      } else {
        _entries = [for (final e in _entries) e.id == result.id ? result : e];
      }
    });
  }
}

class WorldInfoEditorPage extends ConsumerStatefulWidget {
  const WorldInfoEditorPage({super.key, required this.entryId});

  final String entryId;

  @override
  ConsumerState<WorldInfoEditorPage> createState() =>
      _WorldInfoEditorPageState();
}

class _WorldInfoEditorPageState extends ConsumerState<WorldInfoEditorPage> {
  final _keys = TextEditingController();
  final _content = TextEditingController();
  final _comment = TextEditingController();
  final _order = TextEditingController(text: '100');
  late WorldInfoMode _mode;
  bool _recursive = false, _enabled = true;

  @override
  void initState() {
    super.initState();
    _mode = WorldInfoMode.keyword;
  }

  @override
  void dispose() {
    _keys.dispose();
    _content.dispose();
    _comment.dispose();
    _order.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DtDetailPage(
      title: widget.entryId == 'new' ? '新增词条' : '编辑词条',
      bottom: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: DtButton(
            label: '保存词条',
            successText: '已保存',
            onPressed: () {
              if (_content.text.trim().isEmpty) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('请填写词条内容')));
                return;
              }
              Navigator.of(context).pop(
                WorldInfoEntry(
                  id: widget.entryId == 'new'
                      ? 'wi_${const Uuid().v4()}'
                      : widget.entryId,
                  keys: _keys.text
                      .split(RegExp(r'[,，、]'))
                      .map((e) => e.trim())
                      .where((e) => e.isNotEmpty)
                      .toList(),
                  content: _content.text.trim(),
                  comment: _comment.text.trim(),
                  mode: _mode,
                  order: int.tryParse(_order.text.trim()) ?? 100,
                  recursive: _recursive,
                  enabled: _enabled,
                ),
              );
            },
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
                  controller: _keys,
                  decoration: const InputDecoration(
                    labelText: '关键词',
                    hintText: '用逗号分隔；常驻模式可留空',
                  ),
                ),
                const SizedBox(height: 12),
                DtTextField(
                  controller: _comment,
                  decoration: const InputDecoration(labelText: '备注'),
                ),
                const SizedBox(height: 12),
                DtTextField(
                  controller: _content,
                  minLines: 4,
                  maxLines: 10,
                  decoration: const InputDecoration(labelText: '注入内容'),
                ),
                const SizedBox(height: 12),
                DtTextField(
                  controller: _order,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: '排序'),
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
                  icon: Icons.search_rounded,
                  title: '模式',
                  subtitle: _mode.label,
                  onTap: () => setState(
                    () => _mode = _mode == WorldInfoMode.keyword
                        ? WorldInfoMode.constant
                        : WorldInfoMode.keyword,
                  ),
                ),
                const Divider(indent: 62),
                DtSettingRow(
                  icon: Icons.repeat_rounded,
                  title: '递归匹配',
                  subtitle: '命中后继续匹配已注入资料中的关键词',
                  trailing: FSwitch(
                    value: _recursive,
                    onChange: (v) => setState(() => _recursive = v),
                  ),
                  onTap: null,
                ),
                const Divider(indent: 62),
                DtSettingRow(
                  icon: Icons.check_circle_outline_rounded,
                  title: '启用',
                  trailing: FSwitch(
                    value: _enabled,
                    onChange: (v) => setState(() => _enabled = v),
                  ),
                  onTap: null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
