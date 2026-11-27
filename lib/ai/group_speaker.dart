import '../domain/models.dart';

class GroupSpeakerResult {
  const GroupSpeakerResult({required this.character, required this.text});

  final Character character;
  final String text;
}

/// Deterministic speaker attribution for multi-character replies.
///
/// The model is asked to prefix replies with `【角色名】`. When no valid prefix
/// is present we fall back to the participant who spoke least recently, which
/// keeps turns rotating without letting the model invent new characters.
class GroupSpeaker {
  const GroupSpeaker._();

  static final RegExp _bracketPrefix = RegExp(
    r'^\s*[【\[]\s*([^】\]\n]{1,32}?)\s*[】\]]\s*',
  );
  static final RegExp _colonPrefix = RegExp(r'^\s*([^：:\n]{1,32})\s*[：:]\s*');

  /// Removes a leading `【角色名】` / `[角色名]` marker for live previews.
  static String stripPrefix(String text) =>
      text.replaceFirst(_bracketPrefix, '').trim();

  static GroupSpeakerResult resolve({
    required String raw,
    required List<Character> participants,
    required List<Message> history,
  }) {
    final text = raw.trim();
    if (participants.isEmpty) {
      throw const FormatException('群聊没有可用角色');
    }
    for (final pattern in [_bracketPrefix, _colonPrefix]) {
      final match = pattern.firstMatch(text);
      if (match == null) continue;
      final name = match.group(1)!.trim();
      final character = participants
          .where((item) => item.name.trim() == name)
          .firstOrNull;
      if (character == null) continue;
      final body = text.substring(match.end).trim();
      if (body.isEmpty) continue;
      return GroupSpeakerResult(character: character, text: body);
    }
    return GroupSpeakerResult(
      character: _leastRecent(participants: participants, history: history),
      text: text,
    );
  }

  static Character _leastRecent({
    required List<Character> participants,
    required List<Message> history,
  }) {
    final lastSpoken = <String, int>{};
    for (var i = 0; i < history.length; i++) {
      final message = history[i];
      if (message.fromAi) lastSpoken[message.senderId] = i;
    }
    Character? chosen;
    var chosenIndex = -1;
    for (final participant in participants) {
      final index = lastSpoken[participant.id] ?? -1;
      if (chosen == null || index < chosenIndex) {
        chosen = participant;
        chosenIndex = index;
      }
    }
    return chosen ?? participants.first;
  }
}
