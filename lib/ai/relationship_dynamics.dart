import '../domain/models.dart';

class RelationshipAdjustment {
  const RelationshipAdjustment({
    required this.metrics,
    required this.delta,
    required this.stage,
    required this.reason,
  });

  final Map<String, int> metrics;
  final Map<String, int> delta;
  final String stage;
  final String reason;

  bool get changed => delta.values.any((value) => value != 0);
}

/// Derives relationship movement from an actually completed exchange. Values
/// are intentionally explainable: every delta has a local, inspectable reason.
class RelationshipDynamics {
  const RelationshipDynamics._();

  static const metricOrder = ['好感', '信任', '心动', '张力'];

  static String displayLabel(String key) => switch (key) {
    '好感' => '亲近',
    '心动' => '共鸣',
    _ => key,
  };

  static RelationshipAdjustment evaluate({
    required Relationship relationship,
    required String userText,
    required String assistantReply,
    required String userMessageId,
    required bool isImage,
  }) {
    final current = _normalizedMetrics(relationship.metrics);
    if (relationship.lastMetricMessageId == userMessageId) {
      return RelationshipAdjustment(
        metrics: current,
        delta: const {},
        stage: relationship.stage,
        reason: relationship.lastMetricReason,
      );
    }

    final input = userText.trim().toLowerCase();
    final reply = assistantReply.trim();
    final hostile = RegExp(r'(滚|闭嘴|恶心|废物|蠢货|傻逼|去死|烦死你)').hasMatch(input);
    final cold = RegExp(r'^(哦|嗯|行吧|好吧|随便|算了|没事|无所谓)[。.!！?？]*$').hasMatch(input);
    final personalShare = RegExp(
      r'(我今天|我最近|我其实|说实话|跟你说|我有件事|我有点|我好累|我难过|我害怕|我开心|我焦虑|小时候|以前|老板|工作|家里|考试|面试|生病)',
    ).hasMatch(input);
    final affection = RegExp(
      r'(想你|喜欢你|抱抱|亲亲|想见你|陪你|晚安|早安|宝贝|亲爱的)',
    ).hasMatch(input);
    final sharedFuture = RegExp(r'(下次|以后|周末|一起|约定|将来|明天见)').hasMatch(input);
    final playfulConflict = RegExp(r'(笨蛋|欠揍|讨厌|不理你|生气|吃醋|欺负)').hasMatch(input);
    final meaningful =
        isImage || input.replaceAll(RegExp(r'\s+'), '').length >= 2;
    final deepConversation = input.runes.length >= 18 || reply.runes.length >= 60;
    final vulnerable = RegExp(
      r'(害怕|孤独|委屈|压力|失眠|哭|崩溃|不安|想念|紧张|心烦|疲惫|难受)',
    ).hasMatch(input);
    final grateful = RegExp(r'(谢谢|谢啦|多亏你|辛苦了|感动|暖)').hasMatch(input);
    final curious = RegExp(r'(你呢|你觉得|你喜欢|你为什么|你会不会|告诉我|想听你)').hasMatch(input);

    var affectionRaw = 0;
    var trustRaw = 0;
    var heartRaw = 0;
    var tensionRaw = 0;
    final reasons = <String>[];

    if (hostile) {
      affectionRaw -= 2;
      heartRaw -= 1;
      tensionRaw += 4;
      reasons.add('刚才的话让气氛明显变紧');
    } else {
      if (meaningful) {
        affectionRaw += 1;
        reasons.add('认真接住了这次互动');
      }
      if (deepConversation) {
        affectionRaw += 1;
        trustRaw += 1;
        reasons.add('聊得更深入了一些');
      }
      if (personalShare) {
        trustRaw += 2;
        affectionRaw += 1;
        reasons.add('你分享了真实近况');
      }
      if (vulnerable) {
        trustRaw += 1;
        heartRaw += 1;
        reasons.add('愿意把脆弱的一面说出来');
      }
      if (affection) {
        heartRaw += 2;
        affectionRaw += 1;
        reasons.add('表达了明确的亲近');
      }
      if (sharedFuture) {
        heartRaw += 1;
        trustRaw += 1;
        reasons.add('出现了共同的未来安排');
      }
      if (grateful) {
        affectionRaw += 1;
        trustRaw += 1;
        reasons.add('这句感谢让彼此更贴近');
      }
      if (curious) {
        heartRaw += 1;
        reasons.add('主动想更了解对方');
      }
      if (playfulConflict) {
        tensionRaw += 2;
        heartRaw += 1;
        reasons.add('玩笑式拉扯让张力升温');
      } else if (cold) {
        tensionRaw += 1;
        reasons.add('你暂时收回了话题');
      } else {
        tensionRaw -= 1;
      }
      if (reply.runes.length >= 80 && input.runes.length >= 20) {
        trustRaw += 1;
      }
    }

    final next = <String, int>{
      '好感': _adjust(current['好感']!, affectionRaw),
      '信任': _adjust(current['信任']!, trustRaw),
      '心动': _adjust(current['心动']!, heartRaw),
      '张力': _adjust(current['张力']!, tensionRaw),
    };
    final delta = <String, int>{
      for (final key in metricOrder) key: next[key]! - current[key]!,
    };
    final stage = stageFor(next);
    final reason = reasons.isEmpty ? '维持了一次日常互动' : reasons.join('；');
    return RelationshipAdjustment(
      metrics: next,
      delta: delta,
      stage: stage,
      reason: reason,
    );
  }

  static String stageFor(Map<String, int> metrics) {
    final affection = metrics['好感'] ?? 0;
    final trust = metrics['信任'] ?? 0;
    final heart = metrics['心动'] ?? 0;
    final affinity = affection * 0.4 + trust * 0.35 + heart * 0.25;
    if (affinity >= 84) return '高度默契';
    if (affinity >= 68) return '关系稳固';
    if (affinity >= 50) return '互相信任';
    if (affinity >= 32) return '逐渐熟悉';
    if (affinity >= 18) return '初步认识';
    return '刚刚相遇';
  }

  static Map<String, int> _normalizedMetrics(Map<String, int> source) => {
    for (final key in metricOrder) key: (source[key] ?? 0).clamp(0, 100),
  };

  static int _adjust(int current, int raw) {
    if (raw == 0) return current;
    if (raw < 0) return (current + raw).clamp(0, 100);
    if (current >= 100) return current;
    // Positive movement stays visible but slows near the top of the scale.
    final scaled = raw * (1 - current / 120);
    return (current + (scaled < 1 ? 1 : scaled.round())).clamp(0, 100);
  }
}
