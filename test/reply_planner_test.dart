import 'package:sillytavern_app/ai/context_assembler.dart';
import 'package:sillytavern_app/ai/reply_planner.dart';
import 'package:sillytavern_app/domain/models.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures/sample_data.dart';

void main() {
  test('short reaction gets a tiny, non-interrogating acknowledgment plan', () {
    final data = buildSeedData();
    final relationship = data.relationships.first;
    final character = data.characterForRelationship(relationship)!;
    final plan = ReplyPlanner.plan(
      character: character,
      relationship: relationship,
      userInput: '牛逼',
    );

    expect(plan.act, ReplyAct.acknowledge);
    expect(plan.length, ReplyLength.oneWord);
    expect(plan.maxQuestions, 0);
    expect(plan.toPromptInstruction(), contains('最多 5'));
  });

  test('direct questions are answered briefly without a forced follow-up', () {
    final data = buildSeedData();
    final relationship = data.relationships.first;
    final plan = ReplyPlanner.plan(
      character: data.characterForRelationship(relationship)!,
      relationship: relationship,
      userInput: '你今天吃饭了吗？',
    );
    expect(plan.act, ReplyAct.answer);
    expect(plan.length, ReplyLength.short);
    expect(plan.maxQuestions, 0);
  });

  test(
    'one-word acknowledgements filter narration without cutting the reply',
    () {
      final data = buildSeedData();
      final relationship = data.relationships.first;
      final plan = ReplyPlanner.plan(
        character: data.characterForRelationship(relationship)!,
        relationship: relationship,
        userInput: '牛逼',
      );

      final visible = plan.prepareText('（笑了一下）你也挺厉害的，哈哈。');
      expect(visible, '你也挺厉害的，哈哈。');
    },
  );

  test('explicit request for silence does not generate an answer', () {
    final data = buildSeedData();
    final relationship = data.relationships.first;
    final plan = ReplyPlanner.plan(
      character: data.characterForRelationship(relationship)!,
      relationship: relationship,
      userInput: '先不聊了，不用回复',
    );
    expect(plan.act, ReplyAct.staySilent);
    expect(plan.shouldReply, isFalse);
  });

  test('distress takes precedence over the default roleplay voice', () {
    final data = buildSeedData();
    final relationship = data.relationships.first;
    final plan = ReplyPlanner.plan(
      character: data.characterForRelationship(relationship)!,
      relationship: relationship,
      userInput: '我今天被老板骂了，真的好委屈。',
    );
    expect(plan.act, ReplyAct.comfort);
    expect(plan.length, ReplyLength.short);
  });

  test(
    'working context keeps four turns and retrieves at most three relevant facts',
    () {
      final data = buildSeedData();
      final thread = data.threads.first;
      final relationship = data.relationshipForThread(thread)!;
      final character = data.characterForRelationship(relationship)!;
      final persona = data.personaById(relationship.personaId)!;
      final history = [
        for (var index = 0; index < 30; index++)
          Message(
            id: 'history-$index',
            threadId: thread.id,
            senderId: index.isOdd ? character.id : persona.id,
            senderName: index.isOdd ? character.name : persona.name,
            text: '第 $index 条最近对话',
            createdAt: DateTime.utc(2026, 11, 20).add(Duration(minutes: index)),
            fromAi: index.isOdd,
          ),
      ];
      final prompt = const ContextAssembler().assemble(
        data: data.copyWith(messages: history),
        thread: thread,
        userInput: '用户不喜欢香菜，今天很累。',
      );

      final recent = prompt.messages
          .where((item) => item.role != 'system')
          .toList();
      expect(recent, hasLength(25));
      expect(recent.first.content, '第 6 条最近对话');
      expect(prompt.usedMemoryIds.length, lessThanOrEqualTo(3));
      expect(
        prompt.messages.where((item) => item.role == 'system').single.content,
        contains('本轮回复计划'),
      );
    },
  );
}
