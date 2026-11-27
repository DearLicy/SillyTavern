import 'package:sillytavern_app/ai/context_assembler.dart';
import 'package:sillytavern_app/domain/models.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures/sample_data.dart';

void main() {
  const assembler = ContextAssembler();

  AppData withWorldBook(WorldBook book) {
    final seed = buildSeedData();
    return seed.copyWith(worldBooks: [book]);
  }

  test('world book keyword and constant entries reach the prompt', () async {
    final data = withWorldBook(
      WorldBook(
        id: 'wb_test',
        name: '旧书店',
        entries: [
          const WorldInfoEntry(
            id: 'keyword',
            keys: ['旧书店'],
            content: '旧书店在雨夜会亮一盏橘色灯。',
          ),
          const WorldInfoEntry(
            id: 'constant',
            keys: [],
            content: '角色讨厌别人把书随便塞回书架。',
            mode: WorldInfoMode.constant,
          ),
        ],
        authorNote: '用短句，不要客服腔。',
        authorNoteDepth: 3,
      ),
    );
    final thread = data.threads.first;
    final bundle = assembler.assemble(
      data: data,
      thread: thread,
      userInput: '旧书店今天开门了吗',
      now: DateTime(2026, 11, 26),
    );
    final system = bundle.messages.first.content;
    expect(system, contains('旧书店在雨夜会亮一盏橘色灯。'));
    expect(system, contains('角色讨厌别人把书随便塞回书架。'));
    expect(system, contains('【作者注记 · 高优先级风格约束】'));
    expect(system, contains('用短句，不要客服腔。'));
  });

  test('disabled books and non-matching keywords do not inject lore', () {
    final data = withWorldBook(
      const WorldBook(
        id: 'wb_off',
        name: '关闭',
        enabled: false,
        authorNote: '不要注入',
        entries: [
          WorldInfoEntry(id: 'keyword', keys: ['旧书店'], content: '不要出现'),
        ],
      ),
    );
    final thread = data.threads.first;
    final bundle = assembler.assemble(
      data: data,
      thread: thread,
      userInput: '今天天气不错',
      now: DateTime(2026, 11, 26),
    );
    final system = bundle.messages.first.content;
    expect(system, isNot(contains('不要出现')));
    expect(system, isNot(contains('不要注入')));
  });

  test('world book survives JSON round trip without credentials', () {
    final data = withWorldBook(
      const WorldBook(
        id: 'wb_json',
        name: '测试世界',
        entries: [
          WorldInfoEntry(
            id: 'wi',
            keys: ['咖啡'],
            content: '他们第一次见面在旧咖啡店。',
            recursive: true,
          ),
        ],
      ),
    );
    final restored = AppData.decode(data.encode());
    expect(restored.worldBooks, hasLength(1));
    expect(restored.worldBooks.first.entries.single.keys, ['咖啡']);
    expect(restored.worldBooks.first.entries.single.recursive, isTrue);
    expect(data.encode(), isNot(contains('sk-')));
  });

  test('SillyTavern macros expand to character and persona names', () {
    final seed = buildSeedData();
    final data = seed.copyWith(
      worldBooks: const [
        WorldBook(
          id: 'wb_macro',
          name: '宏',
          entries: [
            WorldInfoEntry(
              id: 'macro',
              keys: ['介绍'],
              content: '{{char}} 认识 {{user}}，会直接叫对方名字。',
              mode: WorldInfoMode.constant,
            ),
          ],
        ),
      ],
    );
    final bundle = assembler.assemble(
      data: data,
      thread: data.threads.first,
      userInput: '介绍一下',
      now: DateTime(2026, 11, 26),
    );
    final system = bundle.messages.first.content;
    expect(system, contains('顾言 认识 林澈'));
    expect(system, isNot(contains('{{char}}')));
    expect(system, isNot(contains('{{user}}')));
  });

  test('recursive entries can trigger a second lore entry', () {
    final seed = buildSeedData();
    final data = seed.copyWith(
      worldBooks: const [
        WorldBook(
          id: 'wb_recursive',
          name: '递归',
          entries: [
            WorldInfoEntry(
              id: 'first',
              keys: ['旧书店'],
              content: '旧书店旁边是新月码头。',
              recursive: true,
              order: 1,
            ),
            WorldInfoEntry(
              id: 'second',
              keys: ['码头'],
              content: '码头只在凌晨开放。',
              order: 2,
            ),
          ],
        ),
      ],
    );
    final bundle = assembler.assemble(
      data: data,
      thread: data.threads.first,
      userInput: '旧书店今天开门吗',
      now: DateTime(2026, 11, 26),
    );
    final system = bundle.messages.first.content;
    expect(system, contains('旧书店旁边是新月码头。'));
    expect(system, contains('码头只在凌晨开放。'));
  });

  test(
    'global prompt prefix and post-history instructions reach the system prompt',
    () {
      final seed = buildSeedData();
      final data = seed.copyWith(
        settings: seed.settings.copyWith(
          prompts: const PromptConfig(
            systemPrefix: '{{char}} 和 {{user}} 都用短句。',
            postHistoryInstructions: '绝不写客服收尾。',
          ),
        ),
      );
      final bundle = assembler.assemble(
        data: data,
        thread: data.threads.first,
        userInput: '你好',
        now: DateTime(2026, 11, 26),
      );
      final system = bundle.messages.first.content;
      expect(system, contains('【全局系统提示词 · 高优先级风格约束】'));
      expect(system, contains('顾言 和 林澈 都用短句。'));
      expect(system, contains('【后置指令 · 仅限表达与格式】绝不写客服收尾。'));
    },
  );
}
