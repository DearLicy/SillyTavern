import '../domain/models.dart';
import '../domain/dialogue.dart';

/// A lightweight, deterministic turn plan. It constrains tone and length before
/// the provider sees the prompt instead of relying on broad personality prose.
enum ReplyAct { acknowledge, answer, comfort, continueScene, chat, staySilent }

enum ReplyLength { oneWord, short, medium, detailed }

class ReplyPlan {
  const ReplyPlan({
    required this.act,
    required this.length,
    required this.maxQuestions,
    required this.energy,
    required this.reason,
  });

  final ReplyAct act;
  final ReplyLength length;
  final int maxQuestions;
  final int energy;
  final String reason;

  bool get shouldReply => act != ReplyAct.staySilent;

  /// Apply the same display policy to partial and final output. Keep meaningful
  /// questions (especially consent checks); do not disguise them as statements.
  String prepareText(String raw) {
    var text = raw
        .replaceAll(RegExp(r'<think>[\s\S]*?(</think>|$)'), '')
        .replaceAll(
          RegExp(
            r'```[ \t]*(stats|remark|timeline|toy|json)[^\n]*\n[\s\S]*?(```|$)',
          ),
          '',
        )
        .trim();
    if (length == ReplyLength.oneWord) {
      text = DialogueParser.parse(text)
          .where((part) => part.kind == DialogueSegmentKind.speech)
          .map((part) => part.text)
          .join();
    }
    text = text
        .replaceFirst(
          RegExp(
            r'(?:如果还有(?:其他)?(?:问题|需要)[，, ]*(?:随时|可以随时)?(?:再)?(?:告诉我|问我|找我)|希望这(?:能|可以)?帮到你|还有什么(?:我)?(?:能|可以)帮(?:你)?(?:的)?吗)[！!。.?？]*$',
          ),
          '',
        )
        .trimRight();
    if (act == ReplyAct.acknowledge ||
        act == ReplyAct.chat ||
        act == ReplyAct.comfort ||
        act == ReplyAct.continueScene) {
      text = text
          .replaceFirst(
            RegExp(
              r'(?:你呢|你觉得呢|你说呢|对吧|是吧|要不要(?:我)?(?:陪你|帮你|一起)?(?:聊聊|看看|试试))\s*[?？]+\s*$',
            ),
            '',
          )
          .trimRight();
    }
    return text;
  }

  String toPromptInstruction() {
    final lengthRule = switch (length) {
      ReplyLength.oneWord => '最多 5 个字，不写旁白，接住即可。',
      ReplyLength.short => '最多 2 句，通常不超过 80 个字。',
      ReplyLength.medium => '通常 2–4 句，先回应重点，不扩写成文章。',
      ReplyLength.detailed => '用户明确要求细节时才分点或展开，内容说完即止。',
    };
    final actRule = switch (act) {
      ReplyAct.acknowledge => '接住这句短回应即可，不延伸成分析，也不硬找话题。',
      ReplyAct.answer => '直接回答用户问的事；只补充真正有用的内容。',
      ReplyAct.comfort => '先回应情绪，少讲道理，不急着追问或给一长串建议。',
      ReplyAct.continueScene => '顺着当前场景推进一小步，保留角色反应和留白。',
      ReplyAct.chat => '像熟悉的人自然接话，不总结对方，不套客服语气。',
      ReplyAct.staySilent => '用户明确表示此刻不用回复，保持留白。',
    };
    final energyRule = energy <= 28
        ? '本轮互动能量偏低：语气收一点，尊重留白，不讨好、不查岗。'
        : energy >= 72
        ? '本轮互动能量较高：可以更松弛亲近，但仍按角色自己的性格表达。'
        : '本轮保持角色一贯的自然节奏，不刻意拔高情绪。';
    return '''【本轮回复计划】
行动：${act.name}（$reason）
长度：${length.name}。$lengthRule
闲聊追问上限：$maxQuestions 个；不在结尾硬挂问号。完成当前诉求所必需的澄清和同意确认可以例外。
$energyRule
$actRule''';
  }
}

class ReplyPlanner {
  const ReplyPlanner._();

  static const _acknowledgements = {
    '牛逼',
    '厉害',
    '666',
    '6',
    '笑死',
    '哈哈',
    '哈哈哈',
    '好',
    '嗯',
    '哦',
    '行',
    '行吧',
    '知道了',
    '随便',
    '算了',
    '可以',
    '收到',
    '好吧',
    '无语',
  };
  static const _lowEnergyReplies = {
    '哦',
    '嗯',
    '行',
    '行吧',
    '好吧',
    '知道了',
    '随便',
    '算了',
    '没事',
    '无所谓',
  };
  static const _distressWords = [
    '难受',
    '崩溃',
    '委屈',
    '害怕',
    '焦虑',
    '撑不住',
    '很累',
    '想哭',
    '失望',
    '被骂',
    '失败了',
    '出事了',
  ];
  static const _detailWords = [
    '详细',
    '具体步骤',
    '展开说',
    '解释一下',
    '分析一下',
    '完整代码',
    '列出原因',
  ];
  static const _questionWords = [
    '吗',
    '怎么',
    '为什么',
    '什么',
    '哪一个',
    '能不能',
    '可不可以',
    '是否',
    '请问',
  ];

  static ReplyPlan plan({
    required Character character,
    required Relationship relationship,
    required String userInput,
    DateTime? now,
  }) {
    final clock = now ?? DateTime.now();
    final input = userInput.trim();
    final compact = input.replaceAll(RegExp(r'[\s，。！？,.!?~～…、]+'), '');
    final hasQuestion =
        input.contains('?') ||
        input.contains('？') ||
        _questionWords.any(input.contains);
    final runes = compact.runes.length;
    final distress = _distressWords.any(input.contains);
    final explicitDetail = _detailWords.any(input.contains);
    final sceneLike = RegExp(r'[（(].{1,80}[）)]').hasMatch(input);
    var energy = relationship.replyEnergy.clamp(15, 90);

    if (clock.difference(relationship.lastInteractionAt ?? clock) >=
        const Duration(days: 3)) {
      energy = energy < 45 ? 45 : energy;
    }

    energy = nextEnergy(energy, input);
    final lastInteraction = relationship.lastInteractionAt;
    if (lastInteraction != null &&
        clock.difference(lastInteraction).inSeconds >= 0 &&
        clock.difference(lastInteraction).inSeconds < 45 &&
        !_lowEnergyReplies.contains(compact) &&
        !distress) {
      energy = (energy + 2).clamp(15, 90);
    }

    final ReplyAct act;
    final ReplyLength length;
    final String reason;
    if (!distress &&
        !hasQuestion &&
        const ['不用回', '不用回复', '不必回复', '先不聊了', '暂停一下'].any(compact.contains)) {
      act = ReplyAct.staySilent;
      length = ReplyLength.oneWord;
      reason = '尊重用户明确要求的安静';
    } else if (_acknowledgements.contains(compact) && runes <= 8) {
      act = ReplyAct.acknowledge;
      length = ReplyLength.oneWord;
      reason = '用户只给了简短反应';
    } else if (distress) {
      act = ReplyAct.comfort;
      length = runes > 80 ? ReplyLength.medium : ReplyLength.short;
      reason = '用户正在表达明显情绪';
    } else if (hasQuestion || explicitDetail) {
      act = ReplyAct.answer;
      length = explicitDetail
          ? ReplyLength.detailed
          : (runes > 70 ? ReplyLength.medium : ReplyLength.short);
      reason = '优先回答用户本轮诉求';
    } else if (sceneLike) {
      act = ReplyAct.continueScene;
      length = runes < 16 ? ReplyLength.short : ReplyLength.medium;
      reason = '延续当前场景但只推进一小步';
    } else {
      act = ReplyAct.chat;
      length = runes <= 14
          ? ReplyLength.short
          : runes > 90
          ? ReplyLength.medium
          : (energy >= 65 ? ReplyLength.medium : ReplyLength.short);
      reason = '按本轮消息长度和互动能量自然接话';
    }

    // 终结“不想聊了”、“没事了”等极短无意义回复的长篇大论生成
    if (act == ReplyAct.chat && length == ReplyLength.medium && runes < 24) {
      // 降短，改用短回复或沉默
      return ReplyPlan(
        act: ReplyAct.chat,
        length: ReplyLength.short,
        maxQuestions: 0,
        energy: energy,
        reason: '$reason；输入过短已降为单句/留白处理',
      );
    }

    if (character.voiceProfile.contains(RegExp(r'寡言|少说话|短句|冷淡')) &&
        length == ReplyLength.medium) {
      return ReplyPlan(
        act: act,
        length: ReplyLength.short,
        maxQuestions: 0,
        energy: energy,
        reason: '$reason；遵循角色偏短句的语言习惯',
      );
    }

    return ReplyPlan(
      act: act,
      length: length,
      maxQuestions: 0,
      energy: energy,
      reason: reason,
    );
  }

  static int nextEnergy(int current, String userInput) {
    final compact = userInput.trim().replaceAll(RegExp(r'\s+'), '');
    var energy = current;
    if (_lowEnergyReplies.contains(compact)) {
      energy -= 14;
    } else if (compact.runes.length >= 36 &&
        !_distressWords.any(compact.contains)) {
      energy += 5;
    } else if (compact.contains('谢谢') ||
        compact.contains('想你') ||
        compact.contains('喜欢你')) {
      energy += 7;
    }
    if (RegExp(r'[!！]{2,}').hasMatch(compact) &&
        !_distressWords.any(compact.contains)) {
      energy += 2;
    }
    return energy.clamp(15, 90);
  }
}
