import 'package:sillytavern_app/ai/context_assembler.dart';
import 'fixtures/sample_data.dart';
import 'package:sillytavern_app/domain/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const assembler = ContextAssembler();

  test(
    'prompt prioritizes hard boundaries and includes retrieved memories',
    () {
      final data = buildSeedData();
      final thread = data.threads.firstWhere((e) => e.id == 'thread_gu');
      final bundle = assembler.assemble(
        data: data,
        thread: thread,
        userInput: '今天工作很累，晚上想和你多待一会儿',
      );

      final system = bundle.messages.first.content;
      expect(bundle.messages.first.role, 'system');
      expect(
        system.indexOf('平台安全约束'),
        lessThan(system.indexOf('Character Card')),
      );
      expect(system, contains('只扮演明确成年的虚构角色'));
      expect(system, contains('Character Card'));
      expect(system, contains('【本轮回复计划】'));
      expect(system, contains('避免复读'));
      expect(bundle.usedMemoryIds, contains('mem_3'));
      expect(bundle.usedMemoryIds.length, lessThanOrEqualTo(3));
      expect(bundle.messages.last.content, contains('工作很累'));
    },
  );

  test('pinned boundary memories rank before recent non-pinned memories', () {
    final now = DateTime.now();
    final memories = [
      MemoryItem(
        id: 'recent',
        relationshipId: 'rel',
        type: MemoryType.experience,
        title: '刚刚发生',
        content: '喝水',
        createdAt: now,
      ),
      MemoryItem(
        id: 'boundary',
        relationshipId: 'rel',
        type: MemoryType.boundary,
        title: '不可越过',
        content: '必须先确认',
        createdAt: now.subtract(const Duration(days: 20)),
        pinned: true,
      ),
    ];

    final result = assembler.retrieveMemories(
      all: memories,
      query: '今天',
      limit: 2,
    );
    expect(result.first.id, 'boundary');
  });

  test('unrelated memories are not injected just to fill the context', () {
    final now = DateTime.now();
    final result = assembler.retrieveMemories(
      all: [
        MemoryItem(
          id: 'old',
          relationshipId: 'rel',
          type: MemoryType.experience,
          title: '一起看海',
          content: '周末去了海边',
          createdAt: now,
        ),
        MemoryItem(
          id: 'unrelated',
          relationshipId: 'rel',
          type: MemoryType.userFact,
          title: '不吃香菜',
          content: '用户讨厌香菜',
          createdAt: now,
        ),
      ],
      query: '海边的风很大',
    );
    expect(result.map((item) => item.id), ['old']);
  });
}
