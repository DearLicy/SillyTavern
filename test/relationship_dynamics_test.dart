import 'package:sillytavern_app/ai/relationship_dynamics.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures/sample_data.dart';

void main() {
  test('warm disclosure grows affinity, trust and heart', () {
    final relationship = buildSeedData().relationships.first;
    final before = relationship.metrics;
    final result = RelationshipDynamics.evaluate(
      relationship: relationship,
      userText: '今天工作好累，不过有点想你。周末一起出去吧。',
      assistantReply: '（放下手里的东西）那就别硬撑了。周末我来安排。',
      userMessageId: 'turn-1',
      isImage: false,
    );

    expect(result.metrics['好感']!, greaterThan(before['好感']!));
    expect(result.metrics['信任']!, greaterThan(before['信任']!));
    expect(result.metrics['心动']!, greaterThan(before['心动']!));
    expect(result.delta['好感'], greaterThan(0));
    expect(result.reason, contains('真实近况'));
    expect(result.changed, isTrue);
  });

  test('the same completed user turn never grows the relationship twice', () {
    final relationship = buildSeedData().relationships.first.copyWith(
      lastMetricMessageId: 'same-turn',
      lastMetricReason: '上一轮已结算',
    );
    final result = RelationshipDynamics.evaluate(
      relationship: relationship,
      userText: '想你',
      assistantReply: '知道了。',
      userMessageId: 'same-turn',
      isImage: false,
    );

    expect(result.changed, isFalse);
    expect(result.metrics, relationship.metrics);
  });

  test('hostile language raises tension instead of farming affection', () {
    final relationship = buildSeedData().relationships.first;
    final result = RelationshipDynamics.evaluate(
      relationship: relationship,
      userText: '闭嘴，烦死你了',
      assistantReply: '……行，我先不说了。',
      userMessageId: 'hostile',
      isImage: false,
    );

    expect(result.metrics['张力']!, greaterThan(relationship.metrics['张力']!));
    expect(result.metrics['好感']!, lessThan(relationship.metrics['好感']!));
  });

  test('stage advances from the combined relationship score', () {
    expect(
      RelationshipDynamics.stageFor(const {
        '好感': 25,
        '信任': 22,
        '心动': 18,
        '张力': 5,
      }),
      '初步认识',
    );
    expect(
      RelationshipDynamics.stageFor(const {
        '好感': 70,
        '信任': 75,
        '心动': 80,
        '张力': 10,
      }),
      '关系稳固',
    );
  });
}
