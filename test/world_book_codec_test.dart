import 'package:flutter_test/flutter_test.dart';
import 'package:sillytavern_app/data/world_book_codec.dart';
import 'package:sillytavern_app/domain/models.dart';

const _lorebook = '''
{
  "name": "旧城资料",
  "scan_depth": 8,
  "extensions": {
    "max_entries": 5,
    "recursion_depth": 3,
    "author_note": "保持冷峻、具体的叙事。",
    "author_note_depth": 2
  },
  "entries": {
    "12": {
      "uid": 12,
      "key": ["旧书店", "Bookshop"],
      "keysecondary": ["雨夜"],
      "comment": "旧书店",
      "content": "旧书店在雨夜只开侧门。",
      "constant": false,
      "order": 25,
      "disable": false,
      "probability": 60,
      "depth": 3,
      "caseSensitive": true,
      "extensions": {"recursive": true}
    },
    "2": {
      "uid": 2,
      "key": [],
      "content": "这座城市永远在下雨。",
      "constant": true,
      "order": 10,
      "disable": true
    }
  }
}
''';

void main() {
  const codec = WorldBookCodec();

  test('SillyTavern lorebook decodes declarative fields', () {
    final book = codec.decode(_lorebook, id: 'wb_import');
    expect(book.name, '旧城资料');
    expect(book.scanDepth, 8);
    expect(book.maxEntries, 5);
    expect(book.recursionDepth, 3);
    expect(book.authorNote, contains('冷峻'));
    expect(book.entries, hasLength(2));
    final first = book.entries.firstWhere((entry) => entry.order == 25);
    expect(first.keys, ['旧书店', 'Bookshop']);
    expect(first.secondaryKeys, ['雨夜']);
    expect(first.probability, 60);
    expect(first.caseSensitive, isTrue);
    expect(first.depth, 3);
    expect(first.enabled, isTrue);
    final constant = book.entries.firstWhere(
      (entry) => entry.mode == WorldInfoMode.constant,
    );
    expect(constant.enabled, isFalse);
  });

  test('exported lorebook round trips without losing advanced controls', () {
    const source = WorldBook(
      id: 'wb_source',
      name: '角色世界',
      scanDepth: 6,
      maxEntries: 3,
      recursionDepth: 2,
      authorNote: '短句。',
      entries: [
        WorldInfoEntry(
          id: 'one',
          keys: ['雾港'],
          secondaryKeys: ['夜晚'],
          content: '雾港的灯塔只在夜晚亮起。',
          probability: 75,
          recursive: true,
          caseSensitive: true,
          depth: 1,
        ),
      ],
    );
    final restored = codec.decode(codec.encode(source), id: 'wb_roundtrip');
    expect(restored.name, source.name);
    expect(restored.scanDepth, 6);
    expect(restored.maxEntries, 3);
    expect(restored.recursionDepth, 2);
    expect(restored.authorNote, '短句。');
    final entry = restored.entries.single;
    expect(entry.keys, ['雾港']);
    expect(entry.secondaryKeys, ['夜晚']);
    expect(entry.probability, 75);
    expect(entry.recursive, isTrue);
    expect(entry.caseSensitive, isTrue);
    expect(entry.depth, 1);
  });

  test('invalid, empty and oversized lorebooks fail closed', () {
    expect(
      () => codec.decode('{"entries":{}}', id: 'empty'),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => codec.decode('not json', id: 'bad'),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => codec.decode('x' * (WorldBookCodec.maxBytes + 1), id: 'large'),
      throwsA(isA<FormatException>()),
    );
  });
}
