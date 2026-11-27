import 'fixtures/sample_data.dart';
import 'package:sillytavern_app/domain/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('V2 state survives a JSON round trip', () {
    final source = buildSeedData();
    final firstThread = source.threads.first;
    final memoDate = DateTime.utc(2026, 11, 20, 12, 30);
    final withMemo = source.copyWith(
      threads: [
        firstThread.copyWith(
          contextMemo: '他们约好周末一起去看海。',
          contextMemoUpdatedAt: memoDate,
          summarizedThroughMessageId: 'message-42',
          suppressedMemoryKeys: const ['promise:过期计划'],
        ),
        ...source.threads.skip(1),
      ],
      characters: [
        source.characters.first.copyWith(
          voiceProfile: '少用客套收尾。',
          personalPreferences: '不喜欢香菜。',
        ),
        ...source.characters.skip(1),
      ],
      relationships: [
        source.relationships.first.copyWith(
          replyEnergy: 32,
          lastInteractionAt: memoDate,
          interactionCount: 7,
          lastMetricDelta: const {'好感': 2, '信任': 1},
          lastMetricReason: '你分享了真实近况',
          lastMetricMessageId: 'message-42',
        ),
        ...source.relationships.skip(1),
      ],
    );
    final restored = AppData.decode(withMemo.encode());

    expect(restored.schemaVersion, 2);
    expect(restored.characters.length, source.characters.length);
    expect(restored.threads.length, source.threads.length);
    expect(restored.messages.length, source.messages.length);
    expect(restored.memories.length, source.memories.length);
    expect(restored.moments.length, source.moments.length);
    expect(restored.threads.first.contextMemo, '他们约好周末一起去看海。');
    expect(restored.threads.first.contextMemoUpdatedAt, memoDate);
    expect(restored.threads.first.summarizedThroughMessageId, 'message-42');
    expect(restored.threads.first.suppressedMemoryKeys, ['promise:过期计划']);
    expect(restored.characters.first.voiceProfile, '少用客套收尾。');
    expect(restored.characters.first.personalPreferences, '不喜欢香菜。');
    expect(restored.relationships.first.replyEnergy, 32);
    expect(restored.relationships.first.lastInteractionAt, memoDate);
    expect(restored.relationships.first.interactionCount, 7);
    expect(restored.relationships.first.lastMetricDelta, {'好感': 2, '信任': 1});
    expect(restored.relationships.first.lastMetricReason, '你分享了真实近况');
    expect(restored.relationships.first.lastMetricMessageId, 'message-42');
  });

  test('empty messages are never renderable', () {
    final message = Message(
      id: 'empty',
      threadId: 'thread',
      senderId: 'character',
      senderName: '顾言',
      text: '  \n ',
      createdAt: DateTime.now(),
      fromAi: true,
    );

    expect(message.isRenderable, isFalse);
  });

  test('relationship and thread helpers resolve the bound character', () {
    final data = buildSeedData();
    final thread = data.threads.firstWhere((e) => e.id == 'thread_gu');
    final relationship = data.relationshipForThread(thread);

    expect(relationship, isNotNull);
    expect(data.characterForRelationship(relationship!)?.name, '顾言');
    expect(data.personaById(relationship.personaId)?.name, '林澈');
  });

  test('provider generation parameters survive backup JSON', () {
    const provider = ProviderConfig(
      model: 'model',
      temperature: 0.35,
      topP: 0.8,
      frequencyPenalty: 0.25,
      presencePenalty: -0.15,
      maxOutputTokens: 2048,
      stopSequences: ['END', '---'],
    );
    final data = buildSeedData().copyWith(
      settings: buildSeedData().settings.copyWith(provider: provider),
    );
    final restored = AppData.fromJson(data.toJson()).settings.provider;
    expect(restored.temperature, 0.35);
    expect(restored.topP, 0.8);
    expect(restored.frequencyPenalty, 0.25);
    expect(restored.presencePenalty, -0.15);
    expect(restored.maxOutputTokens, 2048);
    expect(restored.stopSequences, ['END', '---']);
  });
}
