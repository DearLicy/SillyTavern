import 'package:flutter_test/flutter_test.dart';
import 'package:sillytavern_app/ai/group_speaker.dart';
import 'package:sillytavern_app/domain/models.dart';

Character _character(String id, String name) => Character(
  id: id,
  name: name,
  handle: '@$id',
  age: '成年',
  intro: '',
  persona: '',
  greeting: '',
  avatarColor: 0xFF4F7DF3,
  tags: const [],
);

Message _message(String id, Character sender, {bool fromAi = true}) => Message(
  id: id,
  threadId: 't',
  senderId: sender.id,
  senderName: sender.name,
  text: '...',
  createdAt: DateTime(2026, 1, 1),
  fromAi: fromAi,
);

void main() {
  final gu = _character('char_gu', '顾言');
  final shen = _character('char_shen', '沈砚');

  test('bracket prefix selects speaker and strips marker', () {
    final result = GroupSpeaker.resolve(
      raw: '【沈砚】先把水杯拿起来。',
      participants: [gu, shen],
      history: const [],
    );
    expect(result.character.id, 'char_shen');
    expect(result.text, '先把水杯拿起来。');
  });

  test('colon prefix is accepted', () {
    final result = GroupSpeaker.resolve(
      raw: '顾言：还没睡？',
      participants: [gu, shen],
      history: const [],
    );
    expect(result.character.id, 'char_gu');
    expect(result.text, '还没睡？');
  });

  test('unknown prefix falls back to least recent speaker', () {
    final result = GroupSpeaker.resolve(
      raw: '【路人】随便说一句',
      participants: [gu, shen],
      history: [_message('m1', gu), _message('m2', gu)],
    );
    expect(result.character.id, 'char_shen');
    expect(result.text, contains('随便说一句'));
  });

  test('stripPrefix removes bracket marker for live previews', () {
    expect(GroupSpeaker.stripPrefix('【顾言】在。'), '在。');
    expect(GroupSpeaker.stripPrefix('没有前缀'), '没有前缀');
  });
}
