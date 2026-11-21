import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

import 'dt_controls.dart';
import 'dt_input.dart';
import 'dt_sheet.dart';

Future<String?> showDtModelPicker({
  required BuildContext context,
  required List<String> models,
  required Map<String, String> names,
  required String selected,
}) => showDtSheet<String>(
  context: context,
  builder: (_) =>
      _ModelPicker(models: models, names: names, selected: selected),
);

class _ModelPicker extends StatefulWidget {
  const _ModelPicker({
    required this.models,
    required this.names,
    required this.selected,
  });
  final List<String> models;
  final Map<String, String> names;
  final String selected;
  @override
  State<_ModelPicker> createState() => _ModelPickerState();
}

class _ModelPickerState extends State<_ModelPicker> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final terms = _search.text
        .trim()
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((s) => s.isNotEmpty)
        .toList();
    final visible = widget.models.where((id) {
      final label = '$id ${widget.names[id] ?? ''}'.toLowerCase();
      return terms.every(label.contains);
    }).toList();
    final inset = MediaQuery.viewInsetsOf(context).bottom;
    final height = (MediaQuery.sizeOf(context).height * .70 - inset * .55)
        .clamp(240.0, 560.0);
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(0, 0, 0, inset + 12),
        child: SizedBox(
          height: height,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        '选择默认模型',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    DtIconButton(
                      icon: FIcons.x,
                      tooltip: '关闭模型选择',
                      onTap: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: DtTextField(
                  controller: _search,
                  autocorrect: false,
                  textInputAction: TextInputAction.search,
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) {
                    if (visible.length == 1) {
                      Navigator.pop(context, visible.single);
                    }
                  },
                  decoration: InputDecoration(
                    hintText: '搜索模型名称或 ID',
                    prefixIcon: const Icon(FIcons.search, size: 18),
                    suffixIcon: _search.text.isEmpty
                        ? null
                        : DtIconButton(
                            icon: FIcons.x,
                            tooltip: '清除模型搜索',
                            onTap: () => setState(_search.clear),
                          ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                child: Text(
                  '显示 ${visible.length} / ${widget.models.length} 个模型',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              Expanded(
                child: visible.isEmpty
                    ? const Center(child: Text('没有匹配的模型，换个关键词试试'))
                    : ListView.builder(
                        key: const ValueKey('model-picker-list'),
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        itemCount: visible.length,
                        itemBuilder: (context, index) {
                          final id = visible[index];
                          final name = widget.names[id] ?? id;
                          return DtSettingRow(
                            key: ValueKey('model-option-$id'),
                            icon: FIcons.box,
                            title: name,
                            subtitle: name == id ? null : id,
                            trailing: id == widget.selected
                                ? const Icon(FIcons.check, size: 18)
                                : null,
                            onTap: () => Navigator.pop(context, id),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
