import 'package:sillytavern_app/ai/context_assembler.dart';
import 'package:sillytavern_app/domain/models.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures/sample_data.dart';

void main() {
  const assembler = ContextAssembler();
  String promptText(PromptBundle bundle) =>
      bundle.messages.map((message) => message.content).join('\n');

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
    final prompt = promptText(bundle);
    expect(prompt, contains('旧书店在雨夜会亮一盏橘色灯。'));
    expect(prompt, contains('角色讨厌别人把书随便塞回书架。'));
    expect(prompt, contains('【作者注记 · 高优先级风格约束】'));
    expect(prompt, contains('用短句，不要客服腔。'));
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
    final prompt = promptText(bundle);
    expect(prompt, isNot(contains('不要出现')));
    expect(prompt, isNot(contains('不要注入')));
  });

  test('world book survives JSON round trip without credentials', () {
    final data = withWorldBook(
      const WorldBook(
        id: 'wb_json',
        name: '测试世界',
        scanDepth: 7,
        maxEntries: 6,
        recursionDepth: 3,
        entries: [
          WorldInfoEntry(
            id: 'wi',
            keys: ['咖啡'],
            secondaryKeys: ['雨夜'],
            content: '他们第一次见面在旧咖啡店。',
            recursive: true,
            caseSensitive: true,
            depth: 2,
          ),
        ],
      ),
    );
    final restored = AppData.decode(data.encode());
    expect(restored.worldBooks, hasLength(1));
    expect(restored.worldBooks.first.entries.single.keys, ['咖啡']);
    expect(restored.worldBooks.first.entries.single.recursive, isTrue);
    expect(restored.worldBooks.first.entries.single.secondaryKeys, ['雨夜']);
    expect(restored.worldBooks.first.entries.single.caseSensitive, isTrue);
    expect(restored.worldBooks.first.entries.single.depth, 2);
    expect(restored.worldBooks.first.scanDepth, 7);
    expect(restored.worldBooks.first.maxEntries, 6);
    expect(restored.worldBooks.first.recursionDepth, 3);
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
    final prompt = promptText(bundle);
    expect(prompt, contains('顾言 认识 林澈'));
    expect(prompt, isNot(contains('{{char}}')));
    expect(prompt, isNot(contains('{{user}}')));
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
    final prompt = promptText(bundle);
    expect(prompt, contains('旧书店旁边是新月码头。'));
    expect(prompt, contains('码头只在凌晨开放。'));
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
      expect(system, contains('【全局系统提示词】'));
      expect(system, contains('顾言 和 林澈 都用短句。'));
      expect(system, contains('【后置指令 · 仅限表达与格式】绝不写客服收尾。'));
    },
  );

  test('secondary keys must also match', () {
    final seed = buildSeedData();
    final data = seed.copyWith(
      messages: const [],
      worldBooks: const [
        WorldBook(
          id: 'wb_secondary',
          name: '双关键词',
          entries: [
            WorldInfoEntry(
              id: 'both',
              keys: ['旧书店'],
              secondaryKeys: ['雨夜'],
              content: '雨夜的旧书店会提前打烊。',
            ),
          ],
        ),
      ],
    );
    final thread = data.threads.first;
    final without = assembler.assemble(
      data: data,
      thread: thread,
      userInput: '旧书店今天开门吗',
      now: DateTime(2026, 11, 26),
    );
    expect(promptText(without), isNot(contains('提前打烊')));
    final withBoth = assembler.assemble(
      data: data,
      thread: thread,
      userInput: '旧书店的雨夜还开门吗',
      now: DateTime(2026, 11, 26),
    );
    expect(promptText(withBoth), contains('提前打烊'));
  });

  test('zero probability entries never fire', () {
    final seed = buildSeedData();
    final data = seed.copyWith(
      messages: const [],
      worldBooks: const [
        WorldBook(
          id: 'wb_probability',
          name: '概率',
          entries: [
            WorldInfoEntry(
              id: 'never',
              keys: ['码头'],
              content: '零概率条目不应出现。',
              probability: 0,
            ),
          ],
        ),
      ],
    );
    final bundle = assembler.assemble(
      data: data,
      thread: data.threads.first,
      userInput: '码头在哪',
      now: DateTime(2026, 11, 26),
    );
    expect(promptText(bundle), isNot(contains('零概率条目不应出现')));
  });

  test('recursion depth zero disables recursive expansion', () {
    final seed = buildSeedData();
    final data = seed.copyWith(
      messages: const [],
      worldBooks: const [
        WorldBook(
          id: 'wb_depth0',
          name: '不递归',
          recursionDepth: 0,
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
    final prompt = promptText(bundle);
    expect(prompt, contains('旧书店旁边是新月码头'));
    expect(prompt, isNot(contains('码头只在凌晨开放')));
  });

  test('scan depth controls which recent messages can trigger keys', () {
    final base = buildSeedData();
    final now = DateTime(2026, 1, 1);
    final threadId = base.threads.first.id;
    final messages = [
      Message(
        id: 'old',
        threadId: threadId,
        senderId: 'owner',
        senderName: '林澈',
        text: '我们晚点去码头。',
        createdAt: now,
      ),
      Message(
        id: 'new',
        threadId: threadId,
        senderId: 'char_gu',
        senderName: '顾言',
        text: '今天有点累。',
        createdAt: now.add(const Duration(minutes: 1)),
      ),
    ];
    WorldBook book(int scanDepth) => WorldBook(
      id: 'wb_scan',
      name: '扫描',
      scanDepth: scanDepth,
      entries: const [
        WorldInfoEntry(id: 'dock', keys: ['码头'], content: '码头夜间有雾。'),
      ],
    );
    final shallow = assembler.assemble(
      data: base.copyWith(messages: messages, worldBooks: [book(1)]),
      thread: base.threads.first,
      userInput: '你好',
      now: now,
    );
    expect(promptText(shallow), isNot(contains('码头夜间有雾')));
    final deep = assembler.assemble(
      data: base.copyWith(messages: messages, worldBooks: [book(2)]),
      thread: base.threads.first,
      userInput: '你好',
      now: now,
    );
    expect(promptText(deep), contains('码头夜间有雾'));
  });

  test('each world book scans its own recent-message window', () {
    final base = buildSeedData();
    final now = DateTime(2026, 1, 1);
    final threadId = base.threads.first.id;
    final messages = [
      Message(
        id: 'old',
        threadId: threadId,
        senderId: 'owner',
        senderName: '林澈',
        text: '我们晚点去码头。',
        createdAt: now,
      ),
      Message(
        id: 'new',
        threadId: threadId,
        senderId: 'char_gu',
        senderName: '顾言',
        text: '今天有点累。',
        createdAt: now.add(const Duration(minutes: 1)),
      ),
    ];
    final data = base.copyWith(
      messages: messages,
      worldBooks: const [
        WorldBook(
          id: 'wb_deep',
          name: '扫描两条',
          scanDepth: 2,
          entries: [
            WorldInfoEntry(id: 'deep', keys: ['码头'], content: '深扫描命中。'),
          ],
        ),
        WorldBook(
          id: 'wb_shallow',
          name: '不扫描历史',
          scanDepth: 0,
          entries: [
            WorldInfoEntry(id: 'shallow', keys: ['码头'], content: '浅扫描不应命中。'),
          ],
        ),
      ],
    );
    final prompt = promptText(
      assembler.assemble(
        data: data,
        thread: base.threads.first,
        userInput: '你好',
        now: now,
      ),
    );
    expect(prompt, contains('深扫描命中。'));
    expect(prompt, isNot(contains('浅扫描不应命中。')));
  });

  test('entry depth changes where lore appears in the prompt', () {
    final base = buildSeedData();
    final now = DateTime(2026, 1, 1);
    final threadId = base.threads.first.id;
    final messages = [
      Message(
        id: 'one',
        threadId: threadId,
        senderId: 'owner',
        senderName: '林澈',
        text: '第一句。',
        createdAt: now,
      ),
      Message(
        id: 'two',
        threadId: threadId,
        senderId: 'char_gu',
        senderName: '顾言',
        text: '第二句。',
        createdAt: now.add(const Duration(minutes: 1)),
      ),
      Message(
        id: 'three',
        threadId: threadId,
        senderId: 'owner',
        senderName: '林澈',
        text: '第三句。',
        createdAt: now.add(const Duration(minutes: 2)),
      ),
    ];
    final data = base.copyWith(
      messages: messages,
      worldBooks: const [
        WorldBook(
          id: 'wb_positions',
          name: '位置',
          entries: [
            WorldInfoEntry(
              id: 'deep',
              keys: [],
              content: '深度二资料。',
              mode: WorldInfoMode.constant,
              depth: 2,
              order: 1,
            ),
            WorldInfoEntry(
              id: 'bottom',
              keys: [],
              content: '深度零资料。',
              mode: WorldInfoMode.constant,
              depth: 0,
              order: 2,
            ),
          ],
        ),
      ],
    );
    final bundle = assembler.assemble(
      data: data,
      thread: base.threads.first,
      userInput: '你好',
      now: now,
    );
    expect(bundle.messages[0].content, isNot(contains('深度二资料。')));
    expect(bundle.messages[2].content, contains('深度二资料。'));
    expect(bundle.messages[5].content, contains('深度零资料。'));
    expect(bundle.messages.last.content, '你好');
  });
}
