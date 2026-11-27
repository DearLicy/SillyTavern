import 'dart:async';
import 'dart:typed_data';

import 'package:sillytavern_app/ai/ai_client.dart';
import 'package:sillytavern_app/ai/context_assembler.dart';
import 'package:sillytavern_app/ai/conversation_summary.dart';
import 'package:sillytavern_app/application/app_controller.dart';
import 'package:sillytavern_app/data/attachment_store_base.dart';
import 'package:sillytavern_app/domain/models.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures/fake_store.dart';
import 'fixtures/sample_data.dart';

class _Attachments implements AttachmentStore {
  final removed = <String>[];
  bool fail = false;
  @override
  Future<void> delete(String reference) async {
    if (fail) throw StateError('disk failure');
    removed.add(reference);
  }

  @override
  Future<void> clear() async {}
  @override
  Future<Uint8List?> readImage(String reference) async =>
      MemoryAttachments.pixel;
  @override
  Future<String> saveImage({
    required String id,
    required Uint8List bytes,
    required String mimeType,
  }) async => id;
}

class _DeferredAi extends AiClient {
  final summaryStarted = Completer<void>();
  final summary = Completer<ConversationMemoryUpdate>();
  final mainStarted = Completer<void>();
  final main = Completer<String>();
  bool deferMain = false;
  final requests = <List<PromptMessage>>[];
  @override
  Future<String> streamReply({
    required ProviderConfig config,
    required String apiKey,
    required List<PromptMessage> messages,
    required void Function(String) onUpdate,
    int? maxOutputTokens,
    Future<void>? abortTrigger,
  }) async {
    requests.add(messages);
    if (!mainStarted.isCompleted) mainStarted.complete();
    final reply = deferMain ? await main.future : '刚好路过那家书店，就进去看了看。';
    onUpdate(reply);
    return reply;
  }

  @override
  Future<ConversationMemoryUpdate> summarizeConversation({
    required ProviderConfig config,
    required String apiKey,
    required String previousSummary,
    required List<ConversationMemoryFact> previousFacts,
    required String conversationExcerpt,
    Future<void>? abortTrigger,
  }) async {
    if (!summaryStarted.isCompleted) summaryStarted.complete();
    // Deliberately ignore cancellation: guards must reject late provider data.
    return summary.future;
  }
}

class _FailingStore extends FakeStore {
  _FailingStore(super.data);
  bool fail = false;
  @override
  Future<void> save(AppData value) async {
    if (fail) throw StateError('database failure');
    await super.save(value);
  }
}

class _OrderingStore extends FakeStore {
  _OrderingStore(super.data);
  final firstStarted = Completer<void>();
  final releaseFirst = Completer<void>();
  int calls = 0;
  @override
  Future<void> save(AppData value) async {
    calls++;
    if (calls == 1) {
      firstStarted.complete();
      await releaseFirst.future;
    }
    await super.save(value);
  }
}

AppData _fixture({bool longHistory = false}) {
  final data = buildSeedData();
  final thread = data.threadForRelationship('rel_gu')!;
  final start = DateTime.now().subtract(const Duration(days: 1));
  return data.copyWith(
    settings: data.settings.copyWith(
      provider: const ProviderConfig(
        kind: ProviderKind.openaiCompatible,
        baseUrl: 'https://fake.test',
        model: 'fake',
      ),
    ),
    threads: [
      for (final t in data.threads)
        t.id == thread.id
            ? t.copyWith(
                contextMemo: '旧摘要',
                contextMemoUpdatedAt: start,
                suppressedMemoryKeys: const ['deleted-fact'],
              )
            : t,
    ],
    messages: [
      ...data.messages,
      if (longHistory)
        for (var i = 0; i < 16; i++)
          Message(
            id: 'old-$i',
            threadId: thread.id,
            senderId: i.isEven ? 'owner' : 'char_gu',
            senderName: i.isEven ? '用户' : '顾言',
            text: '周末一起去看海 $i',
            fromAi: i.isOdd,
            createdAt: start.add(Duration(minutes: i)),
          ),
      Message(
        id: 'photo-a',
        threadId: thread.id,
        senderId: 'owner',
        senderName: '用户',
        text: '',
        kind: MessageKind.image,
        localPath: 'unique-image',
        createdAt: start,
      ),
      Message(
        id: 'photo-b',
        threadId: thread.id,
        senderId: 'owner',
        senderName: '用户',
        text: '',
        kind: MessageKind.image,
        localPath: 'shared-image',
        createdAt: start,
      ),
      Message(
        id: 'photo-other',
        threadId: 'thread_shen',
        senderId: 'owner',
        senderName: '用户',
        text: '',
        kind: MessageKind.image,
        localPath: 'shared-image',
        createdAt: start,
      ),
    ],
    memories: [
      ...data.memories,
      MemoryItem(
        id: 'auto-fact',
        relationshipId: 'rel_gu',
        type: MemoryType.userFact,
        title: '旧事实',
        content: '周末去看海',
        createdAt: start,
        autoGenerated: true,
        sourceThreadId: thread.id,
        sourceMessageId: 'msg_gu_1',
      ),
      MemoryItem(
        id: 'unrelated',
        relationshipId: 'rel_shen',
        type: MemoryType.userFact,
        title: '其他关系',
        content: '另一段记忆',
        createdAt: start,
        autoGenerated: true,
        sourceThreadId: 'thread_shen',
        sourceMessageId: 'msg_shen_1',
      ),
    ],
  );
}

Future<AppController> _start(
  FakeStore store, {
  _Attachments? attachments,
  _DeferredAi? ai,
}) async {
  final keys = FakeKeyStore()..value = 'fake-key';
  final controller = AppController(
    store: store,
    keyStore: keys,
    toolKeyStore: FakeKeyStore(),
    attachmentStore: attachments ?? _Attachments(),
    aiClient: ai,
  );
  addTearDown(controller.dispose);
  await Future<void>.delayed(Duration.zero);
  return controller;
}

void main() {
  test(
    'clear chat preserves relationship and facts, detaches sources, removes only unshared images',
    () async {
      final data = _fixture();
      final store = FakeStore(data);
      final files = _Attachments();
      final controller = await _start(store, attachments: files);
      await controller.clearChatHistory('thread_gu');
      final result = store.data!;
      expect(result.messages.any((m) => m.threadId == 'thread_gu'), isFalse);
      expect(result.relationships, data.relationships);
      expect(result.memories.map((m) => m.id), data.memories.map((m) => m.id));
      expect(
        result.memories
            .where((m) => m.relationshipId == 'rel_gu')
            .every((m) => m.sourceThreadId == null),
        isTrue,
      );
      expect(result.threadForRelationship('rel_gu')!.contextMemo, isEmpty);
      expect(
        result.threadForRelationship('rel_gu')!.contextMemoUpdatedAt,
        isNull,
      );
      expect(files.removed, ['unique-image']);
      expect(result.messages.any((m) => m.id == 'photo-other'), isTrue);
      expect(result.settings, data.settings);
    },
  );

  test(
    'restart resets only selected relationship and retains boundary, persona and director',
    () async {
      final data = _fixture();
      final store = FakeStore(data);
      final controller = await _start(store);
      final before = data.relationships.firstWhere((r) => r.id == 'rel_gu');
      await controller.restartRelationship('rel_gu');
      final after = store.data!;
      final relation = after.relationships.firstWhere((r) => r.id == 'rel_gu');
      expect(relation.metrics, {'好感': 12, '信任': 8, '心动': 10, '张力': 5});
      expect(relation.stage, '刚刚相遇');
      expect(relation.interactionCount, 0);
      expect(relation.lastMetricMessageId, isNull);
      expect(relation.lastInteractionAt, isNull);
      expect(relation.consent, before.consent);
      expect(relation.scene.director, before.scene.director);
      expect(relation.personaId, before.personaId);
      expect(after.characters, data.characters);
      expect(after.personas, data.personas);
      expect(
        after.memories
            .where((m) => m.relationshipId == 'rel_gu')
            .map((m) => m.type),
        [MemoryType.boundary],
      );
      expect(
        after.relationships.firstWhere((r) => r.id == 'rel_shen'),
        data.relationships.firstWhere((r) => r.id == 'rel_shen'),
      );
      expect(
        after.threadForRelationship('rel_gu')!.suppressedMemoryKeys,
        isEmpty,
      );
      expect(after.messages.any((m) => m.threadId == 'thread_gu'), isFalse);
    },
  );

  test('chat branch copies history and isolates later mutations', () async {
    final data = buildSeedData();
    final store = FakeStore(data);
    final controller = await _start(store);
    final branch = await controller.branchFromMessage(
      'thread_gu',
      'msg_gu_3',
    );
    final result = store.data!;
    expect(branch.parentThreadId, 'thread_gu');
    expect(branch.branchedFromMessageId, 'msg_gu_3');
    expect(branch.title, contains('分支'));
    final branchMessages = result.messages
        .where((message) => message.threadId == branch.id)
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    expect(branchMessages, hasLength(3));
    expect(branchMessages.map((message) => message.text), [
      '还没睡？窗边的灯一直亮着，我猜你又在赶东西。',
      '差一点。你怎么也还没睡？',
      '本来想等你先开口。后来发现，比起猜，我更想直接问你——今晚要不要我陪你一会儿？',
    ]);
    expect(branchMessages.map((message) => message.id).toSet(), hasLength(3));
    expect(
      result.messages.where((message) => message.threadId == 'thread_gu'),
      hasLength(5),
    );
    final branchRelationship = result.relationships.firstWhere(
      (relationship) => relationship.id == branch.relationshipId,
    );
    final sourceRelationship = data.relationships.firstWhere(
      (relationship) => relationship.id == 'rel_gu',
    );
    expect(branchRelationship.metrics, sourceRelationship.metrics);
    expect(branchRelationship.interactionCount, 1);
    final copiedMemory = result.memories.firstWhere(
      (memory) =>
          memory.relationshipId == branch.relationshipId && memory.id != '',
    );
    expect(copiedMemory.sourceThreadId, branch.id);

    await controller.deleteMessage(branchMessages.first.id);
    expect(
      store.data!.messages.where((message) => message.threadId == branch.id),
      hasLength(2),
    );
    expect(
      store.data!.messages.where((message) => message.threadId == 'thread_gu'),
      hasLength(5),
    );
  });

  test(
    'delete character cascades all owned records but not other relationships or personas',
    () async {
      final store = FakeStore(_fixture());
      final controller = await _start(store);
      await controller.deleteCharacter('char_gu');
      final result = store.data!;
      expect(result.characters.any((c) => c.id == 'char_gu'), isFalse);
      expect(
        result.relationships.any((r) => r.characterId == 'char_gu'),
        isFalse,
      );
      expect(result.threads.any((t) => t.id == 'thread_gu'), isFalse);
      expect(result.messages.any((m) => m.threadId == 'thread_gu'), isFalse);
      expect(result.memories.any((m) => m.relationshipId == 'rel_gu'), isFalse);
      expect(result.moments.any((m) => m.authorId == 'char_gu'), isFalse);
      expect(result.personas, isNotEmpty);
      expect(result.memories.any((m) => m.id == 'unrelated'), isTrue);
    },
  );

  test(
    'edit keeps id/time, clears derived memory, detaches manual source and persists edited marker',
    () async {
      final store = FakeStore(_fixture());
      final controller = await _start(store);
      final original = controller.state.data.messages.firstWhere(
        (m) => m.id == 'msg_gu_1',
      );
      final metrics = controller.state.data.relationships.first.metrics;
      await controller.editMessage(original.id, '我最近在学画画。');
      final edited = AppData.decode(
        store.data!.encode(),
      ).messages.firstWhere((m) => m.id == original.id);
      expect(edited.text, '我最近在学画画。');
      expect(edited.createdAt, original.createdAt);
      expect(edited.editedAt, isNotNull);
      expect(store.data!.memories.any((m) => m.id == 'auto-fact'), isFalse);
      expect(store.data!.memories.any((m) => m.id == 'unrelated'), isTrue);
      expect(
        store.data!.memories.firstWhere((m) => m.id == 'mem_1').sourceMessageId,
        isNull,
      );
      expect(store.data!.relationships.first.metrics, metrics);
      expect(
        store.data!.threadForRelationship('rel_gu')!.suppressedMemoryKeys,
        ['deleted-fact'],
      );
    },
  );

  test(
    'batch delete is isolated, idempotent and respects shared image references',
    () async {
      final store = FakeStore(_fixture());
      final files = _Attachments();
      final controller = await _start(store, attachments: files);
      await controller.deleteMessages({'photo-a', 'photo-b', 'missing'});
      expect(store.data!.messages.any((m) => m.id == 'photo-other'), isTrue);
      expect(files.removed, ['unique-image']);
      await controller.deleteMessages({'photo-a', 'photo-b'});
      expect(files.removed, ['unique-image']);
      await controller.deleteMessage('photo-other');
      expect(files.removed, ['unique-image', 'shared-image']);
    },
  );

  test(
    'empty text corrections are rejected while image captions may be empty',
    () async {
      final store = FakeStore(_fixture());
      final controller = await _start(store);
      await expectLater(
        controller.editMessage('msg_gu_1', '  '),
        throwsArgumentError,
      );
      await controller.editMessage('photo-a', '新标题');
      await controller.editMessage('photo-a', '');
      expect(
        store.data!.messages.firstWhere((m) => m.id == 'photo-a').isRenderable,
        isTrue,
      );
    },
  );

  test('renaming character updates all conversation titles', () async {
    final controller = await _start(FakeStore(_fixture()));
    controller.upsertCharacter(
      controller.state.data.characters.first.copyWith(name: '新名字'),
    );
    await controller.flush();
    expect(controller.state.data.threadForRelationship('rel_gu')!.title, '新名字');
  });

  test(
    'bound persona cannot be deleted; unbound selected persona falls back',
    () async {
      final store = FakeStore(_fixture());
      final controller = await _start(store);
      final bound = controller.state.data.relationships.first.personaId;
      await expectLater(controller.deletePersona(bound), throwsStateError);
      final extra = UserPersona(
        id: 'extra',
        name: '另一个我',
        age: '成年',
        pronouns: '她',
        appearance: '',
        personality: '',
        background: '',
        preferences: '',
        avatarColor: 1,
      );
      controller.upsertPersona(extra);
      controller.selectPersona(extra.id);
      await controller.deletePersona(extra.id);
      expect(store.data!.settings.currentPersonaId, isNot(extra.id));
      expect(store.data!.relationships.first.personaId, bound);
    },
  );

  test(
    'moments edit preserves reactions, denies AI edits and deletes comments independently',
    () async {
      final store = FakeStore(_fixture());
      final controller = await _start(store);
      final own = controller.state.data.moments.firstWhere((m) => !m.fromAi);
      await controller.editMoment(own.id, '换一种心情。');
      expect(
        store.data!.moments.firstWhere((m) => m.id == own.id).comments,
        own.comments,
      );
      expect(
        store.data!.moments.firstWhere((m) => m.id == own.id).likedBy,
        own.likedBy,
      );
      await expectLater(
        controller.editMoment('moment_1', '冒充角色'),
        throwsStateError,
      );
      controller.addMomentComment(own.id, '新评论');
      final ownComment = controller.state.data.moments
          .firstWhere((m) => m.id == own.id)
          .comments
          .last;
      await controller.editMomentComment(own.id, ownComment.id, '更正评论');
      expect(
        store.data!.moments
            .firstWhere((m) => m.id == own.id)
            .comments
            .last
            .content,
        '更正评论',
      );
      await controller.deleteMomentComment(own.id, ownComment.id);
      await controller.deleteMomentComment(own.id, own.comments.first.id);
      expect(
        store.data!.moments.firstWhere((m) => m.id == own.id).comments.length,
        own.comments.length - 1,
      );
      await controller.deleteMoment(own.id);
      expect(store.data!.moments.any((m) => m.id == own.id), isFalse);
    },
  );

  test(
    'older delayed snapshots finish before destructive writes instead of resurrecting history',
    () async {
      final store = _OrderingStore(_fixture());
      final controller = await _start(store);
      controller.updateOwner(
        controller.state.data.owner.copyWith(signature: '刚刚修改'),
      );
      final oldSave = controller.flush();
      await store.firstStarted.future;
      final clearing = controller.clearChatHistory('thread_gu');
      await Future<void>.delayed(Duration.zero);
      expect(store.calls, 1);
      store.releaseFirst.complete();
      await oldSave;
      await clearing;
      expect(store.calls, 2);
      expect(
        store.data!.messages.any((m) => m.threadId == 'thread_gu'),
        isFalse,
      );
      expect(store.data!.owner.signature, '刚刚修改');
    },
  );

  test(
    'failed attachment cleanup is retried without rolling back saved chat deletion',
    () async {
      final store = FakeStore(_fixture());
      final files = _Attachments()..fail = true;
      final controller = await _start(store, attachments: files);
      await controller.clearChatHistory('thread_gu');
      expect(
        store.data!.messages.any((m) => m.threadId == 'thread_gu'),
        isFalse,
      );
      expect(controller.state.error, contains('附件清理失败'));
      files.fail = false;
      await controller.flush();
      expect(files.removed, ['unique-image']);
    },
  );

  test(
    'failed durable save retains attachments and exposes retryable error',
    () async {
      final store = _FailingStore(_fixture());
      final files = _Attachments();
      final controller = await _start(store, attachments: files);
      store.fail = true;
      await expectLater(
        controller.clearChatHistory('thread_gu'),
        throwsStateError,
      );
      expect(files.removed, isEmpty);
      expect(controller.state.error, contains('保存失败'));
      expect(store.data!.messages.any((m) => m.id == 'photo-a'), isTrue);
      store.fail = false;
      await controller.flush();
      expect(files.removed, ['unique-image']);
      expect(
        store.data!.messages.any((m) => m.threadId == 'thread_gu'),
        isFalse,
      );
    },
  );

  for (final action in ['clear', 'restart', 'edit', 'delete']) {
    test('late quiet memory cannot resurrect data after $action', () async {
      final store = FakeStore(_fixture(longHistory: true));
      final ai = _DeferredAi();
      final controller = await _start(store, ai: ai);
      await controller.sendMessage('thread_gu', '后来怎么样了');
      await ai.summaryStarted.future;
      switch (action) {
        case 'clear':
          await controller.clearChatHistory('thread_gu');
        case 'restart':
          await controller.restartRelationship('rel_gu');
        case 'edit':
          await controller.editMessage('msg_gu_1', '更正后的事实');
        case 'delete':
          await controller.deleteCharacter('char_gu');
      }
      ai.summary.complete(
        const ConversationMemoryUpdate(summary: '不该回来的旧记忆', facts: []),
      );
      await Future<void>.delayed(Duration.zero);
      await controller.flush();
      expect(
        store.data!.threads.any((t) => t.contextMemo == '不该回来的旧记忆'),
        isFalse,
      );
    });
  }

  test(
    'retry preserves original image attachment, timestamp and edit marker without duplicating the user turn',
    () async {
      final initial = _fixture();
      final image = initial.messages.firstWhere((m) => m.id == 'photo-a');
      final store = FakeStore(initial.copyWith(messages: [image]));
      final files = _Attachments();
      final controller = await _start(
        store,
        attachments: files,
        ai: _DeferredAi(),
      );
      await controller.editMessage(image.id, '更正后的图片说明');
      final edited = controller.state.data.messages.single;
      await controller.retryLastTurn(image.threadId);
      final retried = controller.state.data.messages.singleWhere(
        (m) => m.id == image.id,
      );
      expect(retried.localPath, image.localPath);
      expect(retried.createdAt, image.createdAt);
      expect(retried.editedAt, edited.editedAt);
      expect(retried.text, '更正后的图片说明');
      expect(files.removed, isEmpty);
      await controller.regenerateLastReply(image.threadId);
      expect(
        controller.state.data.messages.where((m) => m.id == image.id).length,
        1,
      );
      expect(files.removed, isEmpty);
    },
  );

  test(
    'completed turns still count when all relationship metrics are saturated',
    () async {
      final initial = _fixture();
      final store = FakeStore(
        initial.copyWith(
          relationships: [
            for (final r in initial.relationships)
              r.id == 'rel_gu'
                  ? r.copyWith(
                      metrics: const {'好感': 100, '信任': 100, '心动': 100, '张力': 0},
                    )
                  : r,
          ],
        ),
      );
      final controller = await _start(store, ai: _DeferredAi());
      final before = controller.state.data.relationships.firstWhere(
        (r) => r.id == 'rel_gu',
      );
      await controller.sendMessage('thread_gu', '我今天学画画了');
      final after = controller.state.data.relationships.firstWhere(
        (r) => r.id == 'rel_gu',
      );
      expect(after.metrics, before.metrics);
      expect(after.interactionCount, before.interactionCount + 1);
      await controller.regenerateLastReply('thread_gu');
      expect(
        controller.state.data.relationships
            .firstWhere((r) => r.id == 'rel_gu')
            .interactionCount,
        after.interactionCount,
      );
    },
  );

  test(
    'late main stream cannot recreate messages or growth after restart',
    () async {
      final store = FakeStore(_fixture());
      final ai = _DeferredAi()..deferMain = true;
      final controller = await _start(store, ai: ai);
      final sending = controller.sendMessage('thread_gu', '我今天很想你');
      await ai.mainStarted.future;
      await controller.restartRelationship('rel_gu');
      ai.main.complete('过去的回复不能回来了。');
      await sending;
      await controller.flush();
      expect(
        store.data!.messages.any((m) => m.threadId == 'thread_gu'),
        isFalse,
      );
      expect(controller.state.generatingThreadId, isNull);
      expect(
        store.data!.relationships
            .firstWhere((r) => r.id == 'rel_gu')
            .interactionCount,
        0,
      );
    },
  );

  test(
    'edited text is used by retry and regeneration cannot farm scores',
    () async {
      final store = FakeStore(_fixture());
      final ai = _DeferredAi();
      final controller = await _start(store, ai: ai);
      await controller.sendMessage('thread_gu', '我今天很想你，周末一起去看书');
      final user = controller.state.data.messages.lastWhere(
        (m) => m.threadId == 'thread_gu' && !m.fromAi,
      );
      final metrics = Map.of(
        controller.state.data.relationships
            .firstWhere((r) => r.id == 'rel_gu')
            .metrics,
      );
      await controller.editMessage(user.id, '其实我今天去学画画了');
      await controller.regenerateLastReply('thread_gu');
      expect(ai.requests.last.last.content, contains('学画画'));
      expect(
        controller.state.data.messages.where((m) => m.id == user.id).length,
        1,
      );
      expect(
        controller.state.data.relationships
            .firstWhere((r) => r.id == 'rel_gu')
            .metrics,
        metrics,
      );
      // No history was long enough to request quiet summary in this test.
    },
  );
}
