import 'package:sillytavern_app/application/app_controller.dart';
import 'package:sillytavern_app/data/character_card.dart';
import 'package:sillytavern_app/data/png_character_card.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures/fake_store.dart';
import 'fixtures/sample_data.dart';

const _card = '''
{
  "spec": "chara_card_v2",
  "spec_version": "2.0",
  "data": {
    "name": "知夏",
    "description": "{{char}} 是旧城书店的店员。",
    "personality": "说话简短，观察细致。",
    "scenario": "雨夜书店即将打烊。",
    "first_mes": "门外雨很大。你要进来避一会儿吗？",
    "mes_example": "",
    "creator_notes": "用少量动作描写。",
    "system_prompt": "{{char}} 只叫用户 {{user}}。",
    "post_history_instructions": "不要客服腔。",
    "alternate_greetings": [],
    "tags": ["书店", "慢热"],
    "character_book": {
      "name": "旧书店资料",
      "entries": [
        {
          "id": 1,
          "keys": ["旧书店"],
          "comment": "地点",
          "content": "旧书店在雨夜会留一盏橘色灯。",
          "constant": false,
          "insertion_order": 10,
          "enabled": true,
          "extensions": {"recursive": true}
        }
      ]
    }
  }
}
''';

void main() {
  const codec = CharacterCardCodec();

  test('V2 character card decodes into character and world book', () {
    final imported = codec.decode(_card, id: 'char_new');
    expect(imported.character.name, '知夏');
    expect(imported.character.tags, ['书店', '慢热']);
    expect(imported.character.greeting, contains('雨很大'));
    expect(imported.character.scenario, '雨夜书店即将打烊。');
    expect(imported.character.systemPrompt, contains('{{char}}'));
    expect(imported.character.postHistoryInstructions, '不要客服腔。');
    expect(imported.worldBook, isNotNull);
    expect(imported.worldBook!.entries.single.keys, ['旧书店']);
    expect(imported.worldBook!.entries.single.recursive, isTrue);
  });

  test('V2 world book preserves SillyTavern matching controls', () {
    const card = '''
    {
      "spec": "chara_card_v2",
      "spec_version": "2.0",
      "data": {
        "name": "知夏",
        "description": "旧城书店的店员。",
        "first_mes": "雨还没停。",
        "character_book": {
          "name": "书店规则",
          "scan_depth": 6,
          "extensions": {
            "max_entries": 3,
            "recursion_depth": 1
          },
          "entries": [
            {
              "id": 1,
              "keys": ["Old Bookshop"],
              "secondary_keys": ["rain"],
              "probability": 35,
              "content": "Rain closes the back room.",
              "insertion_order": 10,
              "enabled": true,
              "extensions": {
                "recursive": true,
                "case_sensitive": true,
                "depth": 2
              }
            }
          ]
        }
      }
    }
    ''';
    final imported = codec.decode(card, id: 'char_world_info');
    final book = imported.worldBook!;
    final entry = book.entries.single;
    expect(book.scanDepth, 6);
    expect(book.maxEntries, 3);
    expect(book.recursionDepth, 1);
    expect(entry.secondaryKeys, ['rain']);
    expect(entry.probability, 35);
    expect(entry.caseSensitive, isTrue);
    expect(entry.depth, 2);

    final encoded = codec.encode(imported.character, worldBook: book);
    final roundTrip = codec.decode(encoded, id: 'char_world_info_2');
    expect(roundTrip.worldBook!.scanDepth, 6);
    expect(roundTrip.worldBook!.maxEntries, 3);
    expect(roundTrip.worldBook!.entries.single.secondaryKeys, ['rain']);
    expect(roundTrip.worldBook!.entries.single.caseSensitive, isTrue);
    expect(roundTrip.worldBook!.entries.single.depth, 2);
  });

  test('exported V2 card round trips and excludes local paths or keys', () {
    final seed = buildSeedData();
    final character = seed.characters.first;
    final json = codec.encode(character);
    expect(json, contains('"spec": "chara_card_v2"'));
    expect(json, isNot(contains('sk-')));
    expect(json, isNot(contains('avatar_')));
    final imported = codec.decode(json, id: 'char_roundtrip');
    expect(imported.character.name, character.name);
    expect(imported.character.greeting, character.greeting);
  });

  test('invalid and oversized cards fail closed', () {
    expect(
      () => codec.decode('{"data":{}}', id: 'x'),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => codec.decode('x' * (9 * 1024 * 1024), id: 'x'),
      throwsA(isA<FormatException>()),
    );
  });

  test(
    'controller import adds a relationship and embedded world book',
    () async {
      final seed = buildSeedData();
      final store = FakeStore(
        seed.copyWith(
          settings: seed.settings.copyWith(currentPersonaId: 'persona_lin'),
        ),
      );
      final controller = AppController(
        store: store,
        keyStore: FakeKeyStore(),
        toolKeyStore: FakeKeyStore(),
        attachmentStore: MemoryAttachments(),
      );
      addTearDown(controller.dispose);
      for (var i = 0; i < 40 && controller.state.loading; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      final beforeCharacters = controller.state.data.characters.length;
      final beforeBooks = controller.state.data.worldBooks.length;
      final thread = await controller.importCharacterCard(_card);
      final data = controller.state.data;
      expect(thread.relationshipId, isNotEmpty);
      expect(data.characters, hasLength(beforeCharacters + 1));
      expect(data.worldBooks, hasLength(beforeBooks + 1));
      expect(data.characters.last.name, '知夏');
      expect(data.worldBooks.last.name, '旧书店资料');
      final exported = controller.exportCharacterCard(data.characters.last.id);
      expect(exported, contains('"character_book"'));
      expect(exported, contains('旧书店资料'));
      final png = await controller.exportPngCharacterCard(
        data.characters.last.id,
      );
      expect(const PngCharacterCard().extractJson(png), contains('旧书店资料'));
      expect(await store.load(), isNotNull);
    },
  );

  test('V2 card preserves creator and alternate greetings', () {
    const card = """
    {
      "spec": "chara_card_v2",
      "spec_version": "2.0",
      "data": {
        "name": "晚晴",
        "description": "{{char}} 是海边旅店的老板娘。",
        "first_mes": "风大，先进来。",
        "alternate_greetings": ["雨停了，要出去走走吗？", "早餐在桌上。"],
        "creator": "某作者",
        "tags": ["海边"]
      }
    }
    """;
    final imported = codec.decode(card, id: 'char_alt');
    expect(imported.character.creator, '某作者');
    expect(imported.character.alternateGreetings, ['雨停了，要出去走走吗？', '早餐在桌上。']);

    final encoded = codec.encode(imported.character);
    final roundTrip = codec.decode(encoded, id: 'char_alt_2');
    expect(roundTrip.character.creator, '某作者');
    expect(
      roundTrip.character.alternateGreetings,
      imported.character.alternateGreetings,
    );
  });

  test('legacy flat V1 card maps alternate greetings', () {
    const card = """
    {
      "name": "旧卡角色",
      "description": "旧格式描述",
      "first_mes": "你好。",
      "alternate_greetings": ["晚上好。"],
      "creator": "legacy"
    }
    """;
    final imported = codec.decode(card, id: 'char_legacy');
    expect(imported.character.name, '旧卡角色');
    expect(imported.character.creator, 'legacy');
    expect(imported.character.alternateGreetings, ['晚上好。']);
  });
}
