import 'package:sillytavern_app/ai/repetition_guard.dart';
import 'package:sillytavern_app/domain/models.dart';
import 'package:flutter_test/flutter_test.dart';

Message reply(String id, String text) => Message(
  id: id,
  threadId: 'thread',
  senderId: 'character',
  senderName: '角色',
  text: text,
  createdAt: DateTime.now(),
  fromAi: true,
);

void main() {
  test('near-identical multi-sentence replies are detected', () {
    final match = RepetitionGuard.find(
      candidate: '（轻轻笑）你总是这样，嘴上说着不在意，其实比谁都在乎。',
      recentAssistantMessages: [reply('old', '你总是这样，嘴上说着不在意，其实比谁都在乎。')],
    );

    expect(match, isNotNull);
    expect(match!.similarity, greaterThanOrEqualTo(0.72));
  });

  test('a genuinely different reaction is not blocked', () {
    final match = RepetitionGuard.find(
      candidate: '行，那我不问了。水在桌上，喝完再说。',
      recentAssistantMessages: [reply('old', '你总是这样，嘴上说着不在意，其实比谁都在乎。')],
    );

    expect(match, isNull);
  });

  test('short replies only repeat when they are identical', () {
    final exact = RepetitionGuard.find(
      candidate: '哦。',
      recentAssistantMessages: [reply('old', '哦')],
    );
    final different = RepetitionGuard.find(
      candidate: '行。',
      recentAssistantMessages: [reply('old', '哦')],
    );

    expect(exact, isNotNull);
    expect(different, isNull);
  });
}
