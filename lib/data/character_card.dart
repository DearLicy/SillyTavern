import 'dart:convert';

import '../domain/models.dart';

class ImportedCharacterCard {
  const ImportedCharacterCard({required this.character, this.worldBook});

  final Character character;
  final WorldBook? worldBook;
}

/// SillyTavern Character Card V2 JSON compatibility. The importer accepts the
/// canonical nested `data` shape and common flattened legacy cards. It never
/// executes macros, scripts or remote resources from a card.
class CharacterCardCodec {
  const CharacterCardCodec();

  String encode(
    Character character, {
    WorldBook? worldBook,
    String creator = 'SillyTavern APP',
  }) {
    final resolvedCreator =
        character.creator.trim().isEmpty ? creator : character.creator.trim();
    final data = <String, dynamic>{
      'name': character.name,
      'description': character.intro,
      'personality': character.persona,
      'scenario': character.personalPreferences,
      'first_mes': character.greeting,
      'mes_example': '',
      'creator_notes': character.intro,
      'system_prompt': character.persona,
      'post_history_instructions': character.voiceProfile,
      'alternate_greetings': character.alternateGreetings,
      'character_book': worldBook == null
          ? null
          : _encodeCharacterBook(worldBook),
      'tags': character.tags,
      'creator': resolvedCreator,
      'character_version': '1.0',
      'extensions': {
        'sillytavern_app_handle': character.handle,
        'sillytavern_app_age': character.age,
        'sillytavern_app_voice_profile': character.voiceProfile,
        'sillytavern_app_personal_preferences': character.personalPreferences,
      },
    };
    return const JsonEncoder.withIndent('  ').convert({
      'spec': 'chara_card_v2',
      'spec_version': '2.0',
      'data': data,
      'name': character.name,
      'description': character.intro,
      'personality': character.persona,
      'scenario': character.personalPreferences,
      'first_mes': character.greeting,
      'avatar': 'none',
      'talkativeness': '0.5',
      'fav': false,
      'tags': character.tags,
    });
  }

  ImportedCharacterCard decode(String source, {required String id}) {
    if (source.length > 8 * 1024 * 1024) {
      throw const FormatException('角色卡过大，无法导入');
    }
    final decoded = jsonDecode(source.trim());
    if (decoded is! Map) throw const FormatException('角色卡必须是 JSON 对象');
    final root = Map<String, dynamic>.from(decoded);
    final data = root['data'] is Map
        ? Map<String, dynamic>.from(root['data'] as Map)
        : root;
    final name = [data['name'], root['name'], data['char_name']]
        .whereType<String>()
        .map((e) => e.trim())
        .firstWhere((e) => e.isNotEmpty, orElse: () => '');
    if (name.isEmpty) throw const FormatException('角色卡缺少角色名');
    String text(String key) {
      final value = data[key];
      return value is String ? value.trim() : '';
    }

    final extensions = data['extensions'] is Map
        ? Map<String, dynamic>.from(data['extensions'] as Map)
        : const <String, dynamic>{};
    String extension(String key) {
      final value = extensions[key];
      return value is String ? value.trim() : '';
    }

    final creator =
        text('creator').isNotEmpty
            ? text('creator')
            : (root['creator'] is String ? (root['creator'] as String).trim() : '');
    final alternateGreetings = [
      for (final value
          in (data['alternate_greetings'] as List? ??
              root['alternate_greetings'] as List? ??
              const []))
        value.toString().trim(),
    ]
        .where((e) => e.isNotEmpty)
        .take(20)
        .map((e) => e.length <= 4000 ? e : e.substring(0, 4000))
        .toList();

    final description = text('description');
    final personality = text('personality');
    final scenario = text('scenario');
    final creatorNotes = text('creator_notes');
    final systemPrompt = text('system_prompt');
    final postHistory = text('post_history_instructions');
    final tags = [
      for (final value
          in (data['tags'] as List? ?? root['tags'] as List? ?? const []))
        value.toString().trim(),
    ].where((e) => e.isNotEmpty).toList();

    final character = Character(
      id: id,
      avatarReference: null,
      name: name,
      handle: extension('sillytavern_app_handle').isEmpty
          ? '@${_slug(name)}'
          : extension('sillytavern_app_handle'),
      age: extension('sillytavern_app_age').isEmpty
          ? '成年'
          : extension('sillytavern_app_age'),
      intro: description,
      persona: [
        if (personality.isNotEmpty) personality,
        if (scenario.isNotEmpty) '场景：$scenario',
        if (systemPrompt.isNotEmpty) systemPrompt,
      ].join('\n\n'),
      greeting: text('first_mes'),
      avatarColor: _colorFromName(name),
      tags: tags,
      voiceProfile: [
        if (creatorNotes.isNotEmpty) creatorNotes,
        if (postHistory.isNotEmpty) postHistory,
        if (extension('sillytavern_app_voice_profile').isNotEmpty)
          extension('sillytavern_app_voice_profile'),
      ].join('\n\n'),
      personalPreferences: extension('sillytavern_app_personal_preferences'),
      alternateGreetings: alternateGreetings,
      creator: creator,
    );

    final bookRaw = data['character_book'];
    final book = bookRaw is Map
        ? _decodeCharacterBook(
            Map<String, dynamic>.from(bookRaw),
            name: '$name 的世界书',
            id: '$id-book',
          )
        : null;
    return ImportedCharacterCard(character: character, worldBook: book);
  }

  WorldBook _decodeCharacterBook(
    Map<String, dynamic> raw, {
    required String name,
    required String id,
  }) {
    final entries = raw['entries'] is List ? raw['entries'] as List : const [];
    return WorldBook(
      id: id,
      name: raw['name'] is String && (raw['name'] as String).trim().isNotEmpty
          ? (raw['name'] as String).trim()
          : name,
      entries: [
        for (final item in entries.whereType<Map>())
          WorldInfoEntry(
            id: 'wi_${item.hashCode.toUnsigned(32)}_${item['id'] ?? ''}',
            keys: [
              for (final key in (item['keys'] as List? ?? const []))
                key.toString().trim(),
            ].where((e) => e.isNotEmpty).toList(),
            content: '${item['content'] ?? ''}'.trim(),
            comment: '${item['comment'] ?? item['name'] ?? ''}'.trim(),
            mode: item['constant'] == true
                ? WorldInfoMode.constant
                : WorldInfoMode.keyword,
            order:
                (item['insertion_order'] as num?)?.toInt() ??
                (item['order'] as num?)?.toInt() ??
                100,
            recursive:
                item['extensions'] is Map &&
                (item['extensions'] as Map)['recursive'] == true,
            enabled: item['enabled'] as bool? ?? true,
          ),
      ].where((e) => e.content.isNotEmpty).toList(),
      enabled: true,
    );
  }

  Map<String, dynamic> _encodeCharacterBook(WorldBook book) => {
    'name': book.name,
    'entries': [
      for (var i = 0; i < book.entries.length; i++)
        {
          'id': i,
          'keys': book.entries[i].keys,
          'secondary_keys': const <String>[],
          'comment': book.entries[i].comment,
          'content': book.entries[i].content,
          'constant': book.entries[i].mode == WorldInfoMode.constant,
          'selective': true,
          'insertion_order': book.entries[i].order,
          'enabled': book.entries[i].enabled,
          'position': 'before_char',
          'extensions': {'recursive': book.entries[i].recursive},
        },
    ],
    'extensions': {
      'author_note': book.authorNote,
      'author_note_depth': book.authorNoteDepth,
    },
  };

  String _slug(String value) {
    final slug = value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\u4e00-\u9fff]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    return slug.isEmpty ? 'character' : slug;
  }

  int _colorFromName(String name) {
    var hash = 0;
    for (final rune in name.runes) {
      hash = (hash * 31 + rune) & 0x7fffffff;
    }
    const colors = [0xFF4F7DF3, 0xFF8E6FD8, 0xFF32A99A, 0xFFE590AA, 0xFFD99A4E];
    return colors[hash % colors.length];
  }
}
