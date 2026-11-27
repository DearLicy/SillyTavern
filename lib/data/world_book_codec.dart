import 'dart:convert';

import '../domain/models.dart';

/// Imports and exports standalone SillyTavern World Info / Lorebook JSON.
///
/// Only declarative fields are mapped. Scripts, regex keys, vector settings and
/// remote resources are intentionally ignored instead of being executed.
class WorldBookCodec {
  const WorldBookCodec();

  static const maxBytes = 8 * 1024 * 1024;

  WorldBook decode(String source, {required String id, String? fallbackName}) {
    if (source.length > maxBytes) {
      throw const FormatException('世界书文件过大，无法导入');
    }
    Object? decoded;
    try {
      decoded = jsonDecode(source.trim());
    } on FormatException {
      throw const FormatException('世界书不是有效的 JSON');
    }
    if (decoded is! Map) throw const FormatException('世界书必须是 JSON 对象');
    final root = Map<String, dynamic>.from(decoded);
    final rawEntries = root['entries'];
    final records = <Map<String, dynamic>>[];
    if (rawEntries is Map) {
      final keys = rawEntries.keys.map((key) => key.toString()).toList()
        ..sort(_naturalCompare);
      for (final key in keys) {
        final value = rawEntries[key];
        if (value is Map) {
          records.add({...Map<String, dynamic>.from(value), '_key': key});
        }
      }
    } else if (rawEntries is List) {
      for (var index = 0; index < rawEntries.length; index++) {
        final value = rawEntries[index];
        if (value is Map) {
          records.add({
            ...Map<String, dynamic>.from(value),
            '_index': '$index',
          });
        }
      }
    }
    if (records.isEmpty) throw const FormatException('世界书没有可导入词条');

    final entries = <WorldInfoEntry>[];
    for (var index = 0; index < records.length; index++) {
      final item = records[index];
      final content = _text(item['content']);
      if (content.isEmpty) continue;
      final primary = _strings(item['key'], fallback: item['keys']);
      final secondary = _strings(
        item['keysecondary'],
        fallback: item['secondary_keys'],
      );
      final extensions = item['extensions'] is Map
          ? Map<String, dynamic>.from(item['extensions'] as Map)
          : const <String, dynamic>{};
      final uid = _firstText([
        item['uid'],
        item['id'],
        item['_key'],
        item['_index'],
        '$index',
      ]);
      entries.add(
        WorldInfoEntry(
          id: 'wi_${id}_${_safeId(uid)}_$index',
          keys: primary,
          secondaryKeys: secondary,
          content: content,
          comment: _text(item['comment']).isEmpty
              ? primary.join('、')
              : _text(item['comment']),
          mode: item['constant'] == true
              ? WorldInfoMode.constant
              : WorldInfoMode.keyword,
          order: _integer(item['order'], fallback: item['insertion_order']) ?? 100,
          probability: (_integer(item['probability']) ?? 100).clamp(0, 100),
          recursive: extensions['recursive'] == true,
          enabled: item['disable'] != true && item['enabled'] != false,
          caseSensitive:
              item['caseSensitive'] == true ||
              item['case_sensitive'] == true ||
              extensions['case_sensitive'] == true,
          depth:
              (_integer(item['depth'], fallback: extensions['depth']) ?? 4)
                  .clamp(0, 20),
        ),
      );
    }
    if (entries.isEmpty) throw const FormatException('世界书词条内容为空');

    final extensions = root['extensions'] is Map
        ? Map<String, dynamic>.from(root['extensions'] as Map)
        : const <String, dynamic>{};
    final name = _text(root['name']);
    final resolvedName = name.isNotEmpty
        ? name
        : (fallbackName?.trim().isNotEmpty ?? false
              ? fallbackName!.trim()
              : '导入的世界书');
    return WorldBook(
      id: id,
      name: resolvedName,
      entries: entries,
      authorNote: _text(extensions['author_note']),
      authorNoteDepth:
          (_integer(extensions['author_note_depth']) ?? 2).clamp(0, 10),
      scanDepth:
          (_integer(root['scan_depth'], fallback: root['scanDepth']) ?? 4)
              .clamp(0, 20),
      maxEntries:
          (_integer(extensions['max_entries'], fallback: root['max_entries']) ??
                  4)
              .clamp(1, 20),
      recursionDepth:
          (_integer(
                    extensions['recursion_depth'],
                    fallback: root['recursion_depth'],
                  ) ??
                  2)
              .clamp(0, 6),
    );
  }

  String encode(WorldBook book) {
    final entries = <String, dynamic>{};
    for (var index = 0; index < book.entries.length; index++) {
      final entry = book.entries[index];
      entries['$index'] = {
        'uid': index,
        'key': entry.keys,
        'keysecondary': entry.secondaryKeys,
        'comment': entry.comment,
        'content': entry.content,
        'constant': entry.mode == WorldInfoMode.constant,
        'selective': true,
        'order': entry.order,
        'position': 0,
        'disable': !entry.enabled,
        'probability': entry.probability,
        'depth': entry.depth,
        'caseSensitive': entry.caseSensitive,
        'extensions': {
          'recursive': entry.recursive,
          'case_sensitive': entry.caseSensitive,
        },
      };
    }
    return const JsonEncoder.withIndent('  ').convert({
      'name': book.name,
      'description': '',
      'scan_depth': book.scanDepth,
      'extensions': {
        'max_entries': book.maxEntries,
        'recursion_depth': book.recursionDepth,
        'author_note': book.authorNote,
        'author_note_depth': book.authorNoteDepth,
      },
      'entries': entries,
    });
  }

  List<String> _strings(Object? value, {Object? fallback}) {
    final source = value is List ? value : fallback;
    if (source is! List) return const [];
    return source
        .map(_text)
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList();
  }

  int? _integer(Object? value, {Object? fallback}) {
    final selected = value ?? fallback;
    if (selected is num) return selected.toInt();
    return int.tryParse(_text(selected));
  }

  String _firstText(List<Object?> values) {
    for (final value in values) {
      final text = _text(value);
      if (text.isNotEmpty) return text;
    }
    return 'entry';
  }

  String _text(Object? value) => switch (value) {
    final String text => text.trim(),
    final num number => '$number',
    final bool flag => '$flag',
    _ => '',
  };

  String _safeId(String value) =>
      value.replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '_');

  int _naturalCompare(String a, String b) {
    final ai = int.tryParse(a);
    final bi = int.tryParse(b);
    if (ai != null && bi != null) return ai.compareTo(bi);
    return a.compareTo(b);
  }
}
