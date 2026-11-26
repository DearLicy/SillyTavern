import 'package:sillytavern_app/ai/context_assembler.dart';
import 'package:sillytavern_app/ai/conversation_summary.dart';
import 'package:sillytavern_app/domain/models.dart';
import 'fixtures/sample_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 11, 20);

  ChatThread thread({
    String id = 'thread-a',
    String memo = '',
    String? cursor,
  }) => ChatThread(
    id: id,
    relationshipId: 'relationship-$id',
    type: ThreadType.direct,
    title: id,
    updatedAt: now,
    contextMemo: memo,
    summarizedThroughMessageId: cursor,
  );

  List<Message> history(String threadId, int count) => [
    for (var index = 0; index < count; index++)
      Message(
        id: '$threadId-$index',
        threadId: threadId,
        senderId: index.isEven ? 'owner' : 'character',
        senderName: index.isEven ? '用户' : '角色',
        text: '第 $index 条记得住的对话',
        createdAt: now.add(Duration(seconds: index)),
        fromAi: index.isOdd,
      ),
  ];

  test(
    'summary window waits, compacts older turns, and keeps recent turns',
    () {
      final messages = history('thread-a', 5);
      expect(
        ConversationSummaryWindow.create(thread: thread(), source: messages),
        isNull,
      );

      final window = ConversationSummaryWindow.create(
        thread: thread(),
        source: history('thread-a', 12),
      );
      expect(window, isNotNull);
      expect(window!.messages, hasLength(4));
      expect(window.messages.first.id, 'thread-a-0');
      expect(window.lastMessageId, 'thread-a-3');
      expect(window.toTranscript(), contains('"speaker":"用户"'));
      expect(window.toTranscript(), contains('第 0 条记得住的对话'));
    },
  );

  test('summary cursor makes updates incremental and isolated by thread', () {
    final source = [...history('thread-a', 24), ...history('thread-b', 20)];
    final window = ConversationSummaryWindow.create(
      thread: thread(cursor: 'thread-a-3', memo: '上次备忘'),
      source: source,
    );
    expect(window, isNotNull);
    expect(window!.messages.first.id, 'thread-a-4');
    expect(window.lastMessageId, 'thread-a-15');
    expect(
      window.messages.every((message) => message.threadId == 'thread-a'),
      isTrue,
    );
  });

  test('edited/deleted summary anchor retries using a bounded window', () {
    final window = ConversationSummaryWindow.create(
      thread: thread(memo: '已有剧情', cursor: 'deleted-message'),
      source: history('thread-a', 20),
    );
    expect(window, isNotNull);
    expect(window!.messages, hasLength(12));
    expect(window.messages.first.id, 'thread-a-0');
  });

  test('main prompt receives only this thread continuity memo', () {
    final data = buildSeedData();
    final first = data.threads.first;
    final withMemo = first.copyWith(contextMemo: '他们约好下次一起去海边。');
    final updatedData = data.copyWith(
      threads: [
        for (final item in data.threads) item.id == first.id ? withMemo : item,
      ],
    );
    final prompt = const ContextAssembler().assemble(
      data: updatedData,
      thread: withMemo,
      userInput: '你还记得我们的约定吗？',
    );
    expect(prompt.messages.first.content, contains('他们约好下次一起去海边。'));

    final otherThread = data.threads.last;
    final otherPrompt = const ContextAssembler().assemble(
      data: updatedData,
      thread: otherThread,
      userInput: '你好',
    );
    expect(otherPrompt.messages.first.content, isNot(contains('下次一起去海边')));
  });
}
