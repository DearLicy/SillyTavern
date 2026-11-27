import 'dart:convert';
import 'dialogue.dart';
import 'search_source.dart';
export 'search_source.dart';

enum ContentLevel {
  sfw('SFW', '日常、冒险与剧情'),
  mature('Mature', '成熟主题与情感张力'),
  nsfw('NSFW', '成年人自愿成人角色扮演');

  const ContentLevel(this.label, this.description);

  final String label;
  final String description;

  static ContentLevel fromName(String? value) =>
      values.firstWhere((e) => e.name == value, orElse: () => ContentLevel.sfw);
}

enum AppThemeMode { system, light, dark }

enum ThreadType { direct, group }

enum MessageKind { text, image, voice, system }

enum MemoryType {
  userFact('用户信息'),
  relationship('关系'),
  experience('共同经历'),
  promise('承诺'),
  emotion('情绪记忆'),
  scene('剧情状态'),
  boundary('用户边界');

  const MemoryType(this.label);
  final String label;

  static MemoryType fromName(String? value) => values.firstWhere(
    (e) => e.name == value,
    orElse: () => MemoryType.userFact,
  );
}

enum Pacing { tender, normal, intense }

enum ProviderKind { openaiCompatible, anthropic }

class OwnerProfile {
  const OwnerProfile({
    required this.id,
    required this.displayName,
    required this.signature,
    required this.avatarColor,
    this.status = '在线',
    this.avatarReference,
  });

  final String? avatarReference;
  final String id;
  final String displayName;
  final String signature;
  final int avatarColor;
  final String status;

  OwnerProfile copyWith({
    String? avatarReference,
    bool clearAvatar = false,
    String? displayName,
    String? signature,
    int? avatarColor,
    String? status,
  }) => OwnerProfile(
    avatarReference: clearAvatar
        ? null
        : avatarReference ?? this.avatarReference,
    id: id,
    displayName: displayName ?? this.displayName,
    signature: signature ?? this.signature,
    avatarColor: avatarColor ?? this.avatarColor,
    status: status ?? this.status,
  );

  Map<String, dynamic> toJson() => {
    'avatarReference': avatarReference,
    'id': id,
    'displayName': displayName,
    'signature': signature,
    'avatarColor': avatarColor,
    'status': status,
  };

  factory OwnerProfile.fromJson(Map<String, dynamic> json) => OwnerProfile(
    avatarReference: json['avatarReference'] as String?,
    id: json['id'] as String? ?? 'owner',
    displayName: json['displayName'] as String? ?? '本地用户',
    signature: json['signature'] as String? ?? '保持好奇，继续探索。',
    avatarColor: (json['avatarColor'] as num?)?.toInt() ?? 0xFF5B7CFA,
    status: json['status'] as String? ?? '在线',
  );
}

class UserPersona {
  const UserPersona({
    required this.id,
    required this.name,
    required this.age,
    required this.pronouns,
    required this.appearance,
    required this.personality,
    required this.background,
    required this.preferences,
    required this.avatarColor,
    this.avatarReference,
  });

  final String? avatarReference;
  final String id;
  final String name;
  final String age;
  final String pronouns;
  final String appearance;
  final String personality;
  final String background;
  final String preferences;
  final int avatarColor;

  UserPersona copyWith({
    String? avatarReference,
    bool clearAvatar = false,
    String? name,
    String? age,
    String? pronouns,
    String? appearance,
    String? personality,
    String? background,
    String? preferences,
    int? avatarColor,
  }) => UserPersona(
    avatarReference: clearAvatar
        ? null
        : avatarReference ?? this.avatarReference,
    id: id,
    name: name ?? this.name,
    age: age ?? this.age,
    pronouns: pronouns ?? this.pronouns,
    appearance: appearance ?? this.appearance,
    personality: personality ?? this.personality,
    background: background ?? this.background,
    preferences: preferences ?? this.preferences,
    avatarColor: avatarColor ?? this.avatarColor,
  );

  Map<String, dynamic> toJson() => {
    'avatarReference': avatarReference,
    'id': id,
    'name': name,
    'age': age,
    'pronouns': pronouns,
    'appearance': appearance,
    'personality': personality,
    'background': background,
    'preferences': preferences,
    'avatarColor': avatarColor,
  };

  factory UserPersona.fromJson(Map<String, dynamic> json) => UserPersona(
    avatarReference: json['avatarReference'] as String?,
    id: json['id'] as String? ?? '',
    name: json['name'] as String? ?? '未命名用户人设',
    age: json['age'] as String? ?? '',
    pronouns: json['pronouns'] as String? ?? '她',
    appearance: json['appearance'] as String? ?? '',
    personality: json['personality'] as String? ?? '',
    background: json['background'] as String? ?? '',
    preferences: json['preferences'] as String? ?? '',
    avatarColor: (json['avatarColor'] as num?)?.toInt() ?? 0xFF9B7CF6,
  );
}

class Character {
  const Character({
    required this.id,
    required this.name,
    required this.handle,
    required this.age,
    required this.intro,
    required this.persona,
    required this.greeting,
    required this.avatarColor,
    required this.tags,
    this.voiceProfile = '',
    this.personalPreferences = '',
    this.avatarReference,
    this.alternateGreetings = const [],
    this.creator = '',
  });

  final String? avatarReference;
  final String id;
  final String name;
  final String handle;
  final String age;
  final String intro;
  final String persona;
  final String greeting;
  final int avatarColor;
  final List<String> tags;

  /// Optional concrete speech habits and phrases the character avoids.
  final String voiceProfile;

  /// Harmless tastes and opinions that make the character distinct.
  final String personalPreferences;

  /// SillyTavern alternate greetings. The primary greeting stays [greeting].
  final List<String> alternateGreetings;

  /// Original card creator, preserved across JSON/PNG round trips.
  final String creator;

  Character copyWith({
    String? avatarReference,
    bool clearAvatar = false,
    String? name,
    String? handle,
    String? age,
    String? intro,
    String? persona,
    String? greeting,
    int? avatarColor,
    List<String>? tags,
    String? voiceProfile,
    String? personalPreferences,
    List<String>? alternateGreetings,
    String? creator,
  }) => Character(
    avatarReference: clearAvatar
        ? null
        : avatarReference ?? this.avatarReference,
    id: id,
    name: name ?? this.name,
    handle: handle ?? this.handle,
    age: age ?? this.age,
    intro: intro ?? this.intro,
    persona: persona ?? this.persona,
    greeting: greeting ?? this.greeting,
    avatarColor: avatarColor ?? this.avatarColor,
    tags: tags ?? this.tags,
    voiceProfile: voiceProfile ?? this.voiceProfile,
    personalPreferences: personalPreferences ?? this.personalPreferences,
    alternateGreetings: alternateGreetings ?? this.alternateGreetings,
    creator: creator ?? this.creator,
  );

  Map<String, dynamic> toJson() => {
    'avatarReference': avatarReference,
    'id': id,
    'name': name,
    'handle': handle,
    'age': age,
    'intro': intro,
    'persona': persona,
    'greeting': greeting,
    'avatarColor': avatarColor,
    'tags': tags,
    'voiceProfile': voiceProfile,
    'personalPreferences': personalPreferences,
    'alternateGreetings': alternateGreetings,
    'creator': creator,
  };

  factory Character.fromJson(Map<String, dynamic> json) => Character(
    avatarReference: json['avatarReference'] as String?,
    id: json['id'] as String? ?? '',
    name: json['name'] as String? ?? '未命名角色',
    handle: json['handle'] as String? ?? '@character',
    age: json['age'] as String? ?? '成年',
    intro: json['intro'] as String? ?? '',
    persona: json['persona'] as String? ?? '',
    greeting: json['greeting'] as String? ?? '',
    avatarColor: (json['avatarColor'] as num?)?.toInt() ?? 0xFF4F7DF3,
    tags:
        (json['tags'] as List?)?.map((e) => e.toString()).toList() ?? const [],
    voiceProfile: json['voiceProfile'] as String? ?? '',
    personalPreferences: json['personalPreferences'] as String? ?? '',
    alternateGreetings:
        (json['alternateGreetings'] as List?)
            ?.map((e) => e.toString())
            .where((e) => e.trim().isNotEmpty)
            .toList() ??
        const [],
    creator: json['creator'] as String? ?? '',
  );
}

class DirectorConfig {
  const DirectorConfig({
    this.pacing = Pacing.normal,
    this.narration = 0.45,
    this.autonomy = 0.55,
    this.intimacy = 0.35,
    this.instructions = '',
  });

  final Pacing pacing;
  final double narration;
  final double autonomy;
  final double intimacy;
  final String instructions;

  DirectorConfig copyWith({
    Pacing? pacing,
    double? narration,
    double? autonomy,
    double? intimacy,
    String? instructions,
  }) => DirectorConfig(
    pacing: pacing ?? this.pacing,
    narration: narration ?? this.narration,
    autonomy: autonomy ?? this.autonomy,
    intimacy: intimacy ?? this.intimacy,
    instructions: instructions ?? this.instructions,
  );

  Map<String, dynamic> toJson() => {
    'pacing': pacing.name,
    'narration': narration,
    'autonomy': autonomy,
    'intimacy': intimacy,
    'instructions': instructions,
  };

  factory DirectorConfig.fromJson(Map<String, dynamic> json) => DirectorConfig(
    pacing: Pacing.values.firstWhere(
      (e) => e.name == json['pacing'],
      orElse: () => Pacing.normal,
    ),
    narration: (json['narration'] as num?)?.toDouble() ?? 0.45,
    autonomy: (json['autonomy'] as num?)?.toDouble() ?? 0.55,
    intimacy: (json['intimacy'] as num?)?.toDouble() ?? 0.35,
    instructions: json['instructions'] as String? ?? '',
  );
}

class SceneState {
  const SceneState({
    this.location = '城市夜色中的公寓',
    this.timeHint = '夜晚',
    this.outfit = '',
    this.mood = '平静而亲近',
    this.notes = '',
    this.director = const DirectorConfig(),
  });

  final String location;
  final String timeHint;
  final String outfit;
  final String mood;
  final String notes;
  final DirectorConfig director;

  SceneState copyWith({
    String? location,
    String? timeHint,
    String? outfit,
    String? mood,
    String? notes,
    DirectorConfig? director,
  }) => SceneState(
    location: location ?? this.location,
    timeHint: timeHint ?? this.timeHint,
    outfit: outfit ?? this.outfit,
    mood: mood ?? this.mood,
    notes: notes ?? this.notes,
    director: director ?? this.director,
  );

  Map<String, dynamic> toJson() => {
    'location': location,
    'timeHint': timeHint,
    'outfit': outfit,
    'mood': mood,
    'notes': notes,
    'director': director.toJson(),
  };

  factory SceneState.fromJson(Map<String, dynamic> json) => SceneState(
    location: json['location'] as String? ?? '',
    timeHint: json['timeHint'] as String? ?? '',
    outfit: json['outfit'] as String? ?? '',
    mood: json['mood'] as String? ?? '',
    notes: json['notes'] as String? ?? '',
    director: DirectorConfig.fromJson(
      Map<String, dynamic>.from(json['director'] as Map? ?? const {}),
    ),
  );
}

class ConsentProfile {
  const ConsentProfile({
    this.ceiling = ContentLevel.mature,
    this.allowedThemes = const ['日常互动', '剧情冒险'],
    this.blockedThemes = const ['强迫', '羞辱'],
    this.safeWord = 'red',
    this.paused = false,
  });

  final ContentLevel ceiling;
  final List<String> allowedThemes;
  final List<String> blockedThemes;
  final String safeWord;
  final bool paused;

  ConsentProfile copyWith({
    ContentLevel? ceiling,
    List<String>? allowedThemes,
    List<String>? blockedThemes,
    String? safeWord,
    bool? paused,
  }) => ConsentProfile(
    ceiling: ceiling ?? this.ceiling,
    allowedThemes: allowedThemes ?? this.allowedThemes,
    blockedThemes: blockedThemes ?? this.blockedThemes,
    safeWord: safeWord ?? this.safeWord,
    paused: paused ?? this.paused,
  );

  Map<String, dynamic> toJson() => {
    'ceiling': ceiling.name,
    'allowedThemes': allowedThemes,
    'blockedThemes': blockedThemes,
    'safeWord': safeWord,
    'paused': paused,
  };

  factory ConsentProfile.fromJson(Map<String, dynamic> json) => ConsentProfile(
    ceiling: ContentLevel.fromName(json['ceiling'] as String?),
    allowedThemes:
        (json['allowedThemes'] as List?)?.map((e) => e.toString()).toList() ??
        const [],
    blockedThemes:
        (json['blockedThemes'] as List?)?.map((e) => e.toString()).toList() ??
        const [],
    safeWord: json['safeWord'] as String? ?? 'red',
    paused: json['paused'] as bool? ?? false,
  );
}

class Relationship {
  const Relationship({
    required this.id,
    required this.characterId,
    required this.personaId,
    required this.stage,
    required this.nickname,
    required this.metrics,
    required this.consent,
    required this.scene,
    required this.updatedAt,
    this.replyEnergy = 55,
    this.lastInteractionAt,
    this.interactionCount = 0,
    this.lastMetricDelta = const {},
    this.lastMetricReason = '',
    this.lastMetricMessageId,
  });

  final String id;
  final String characterId;
  final String personaId;
  final String stage;
  final String nickname;
  final Map<String, int> metrics;
  final ConsentProfile consent;
  final SceneState scene;
  final DateTime updatedAt;

  /// Local conversational pace only; it is not a relationship score.
  final int replyEnergy;
  final DateTime? lastInteractionAt;
  final int interactionCount;
  final Map<String, int> lastMetricDelta;
  final String lastMetricReason;
  final String? lastMetricMessageId;

  Relationship copyWith({
    String? personaId,
    String? stage,
    String? nickname,
    Map<String, int>? metrics,
    ConsentProfile? consent,
    SceneState? scene,
    DateTime? updatedAt,
    int? replyEnergy,
    DateTime? lastInteractionAt,
    bool clearLastInteractionAt = false,
    int? interactionCount,
    Map<String, int>? lastMetricDelta,
    String? lastMetricReason,
    String? lastMetricMessageId,
    bool clearLastMetricMessageId = false,
  }) => Relationship(
    id: id,
    characterId: characterId,
    personaId: personaId ?? this.personaId,
    stage: stage ?? this.stage,
    nickname: nickname ?? this.nickname,
    metrics: metrics ?? this.metrics,
    consent: consent ?? this.consent,
    scene: scene ?? this.scene,
    updatedAt: updatedAt ?? this.updatedAt,
    replyEnergy: replyEnergy ?? this.replyEnergy,
    lastInteractionAt: clearLastInteractionAt
        ? null
        : lastInteractionAt ?? this.lastInteractionAt,
    interactionCount: interactionCount ?? this.interactionCount,
    lastMetricDelta: lastMetricDelta ?? this.lastMetricDelta,
    lastMetricReason: lastMetricReason ?? this.lastMetricReason,
    lastMetricMessageId: clearLastMetricMessageId
        ? null
        : lastMetricMessageId ?? this.lastMetricMessageId,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'characterId': characterId,
    'personaId': personaId,
    'stage': stage,
    'nickname': nickname,
    'metrics': metrics,
    'consent': consent.toJson(),
    'scene': scene.toJson(),
    'updatedAt': updatedAt.toIso8601String(),
    'replyEnergy': replyEnergy,
    'lastInteractionAt': lastInteractionAt?.toIso8601String(),
    'interactionCount': interactionCount,
    'lastMetricDelta': lastMetricDelta,
    'lastMetricReason': lastMetricReason,
    'lastMetricMessageId': lastMetricMessageId,
  };

  factory Relationship.fromJson(Map<String, dynamic> json) => Relationship(
    id: json['id'] as String? ?? '',
    characterId: json['characterId'] as String? ?? '',
    personaId: json['personaId'] as String? ?? '',
    stage: json['stage'] as String? ?? '正在靠近',
    nickname: json['nickname'] as String? ?? '你',
    metrics: Map<String, dynamic>.from(
      json['metrics'] as Map? ?? const {},
    ).map((key, value) => MapEntry(key, (value as num?)?.toInt() ?? 0)),
    consent: ConsentProfile.fromJson(
      Map<String, dynamic>.from(json['consent'] as Map? ?? const {}),
    ),
    scene: SceneState.fromJson(
      Map<String, dynamic>.from(json['scene'] as Map? ?? const {}),
    ),
    updatedAt:
        DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? DateTime.now(),
    replyEnergy: ((json['replyEnergy'] as num?)?.toInt() ?? 55).clamp(0, 100),
    lastInteractionAt: DateTime.tryParse(
      json['lastInteractionAt'] as String? ?? '',
    ),
    interactionCount: (json['interactionCount'] as num?)?.toInt() ?? 0,
    lastMetricDelta: Map<String, dynamic>.from(
      json['lastMetricDelta'] as Map? ?? const {},
    ).map((key, value) => MapEntry(key, (value as num?)?.toInt() ?? 0)),
    lastMetricReason: json['lastMetricReason'] as String? ?? '',
    lastMetricMessageId: json['lastMetricMessageId'] as String?,
  );
}

class Message {
  const Message({
    required this.id,
    required this.threadId,
    required this.senderId,
    required this.senderName,
    required this.text,
    required this.createdAt,
    this.kind = MessageKind.text,
    this.fromAi = false,
    this.localPath,
    this.interrupted = false,
    this.editedAt,
    this.sources = const [],
    this.searchWeb = false,
  });

  final String id;
  final String threadId;
  final String senderId;
  final String senderName;
  final String text;
  final DateTime createdAt;
  final MessageKind kind;
  final bool fromAi;
  final String? localPath;
  final bool interrupted;
  final DateTime? editedAt;
  final List<SearchSource> sources;
  final bool searchWeb;

  Message copyWith({
    String? text,
    bool? interrupted,
    DateTime? editedAt,
    List<SearchSource>? sources,
    String? senderId,
    String? senderName,
  }) => Message(
    id: id,
    threadId: threadId,
    senderId: senderId ?? this.senderId,
    senderName: senderName ?? this.senderName,
    text: text ?? this.text,
    createdAt: createdAt,
    kind: kind,
    fromAi: fromAi,
    localPath: localPath,
    interrupted: interrupted ?? this.interrupted,
    editedAt: editedAt ?? this.editedAt,
    sources: sources ?? this.sources,
    searchWeb: searchWeb,
  );

  bool get isRenderable =>
      (localPath?.trim().isNotEmpty ?? false) ||
      (fromAi
          ? DialogueParser.parse(text).isNotEmpty
          : text.replaceAll(RegExp(r'[\s\u200B-\u200D\uFEFF]'), '').isNotEmpty);

  Map<String, dynamic> toJson() => {
    'id': id,
    'threadId': threadId,
    'senderId': senderId,
    'senderName': senderName,
    'text': text,
    'createdAt': createdAt.toIso8601String(),
    'kind': kind.name,
    'fromAi': fromAi,
    'localPath': localPath,
    'interrupted': interrupted,
    'editedAt': editedAt?.toIso8601String(),
    'sources': sources.map((s) => s.toJson()).toList(),
    'searchWeb': searchWeb,
  };

  factory Message.fromJson(Map<String, dynamic> json) => Message(
    id: json['id'] as String? ?? '',
    threadId: json['threadId'] as String? ?? '',
    senderId: json['senderId'] as String? ?? '',
    senderName: json['senderName'] as String? ?? '',
    text: json['text'] as String? ?? '',
    createdAt:
        DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
    kind: MessageKind.values.firstWhere(
      (e) => e.name == json['kind'],
      orElse: () => MessageKind.text,
    ),
    fromAi: json['fromAi'] as bool? ?? false,
    localPath: json['localPath'] as String?,
    interrupted: json['interrupted'] as bool? ?? false,
    editedAt: DateTime.tryParse(json['editedAt'] as String? ?? ''),
    searchWeb: json['searchWeb'] as bool? ?? false,
    sources:
        (json['sources'] as List?)
            ?.whereType<Map>()
            .map((s) => SearchSource.fromJson(Map<String, dynamic>.from(s)))
            .toList() ??
        const [],
  );
}

class ChatThread {
  const ChatThread({
    required this.id,
    required this.relationshipId,
    required this.type,
    required this.title,
    required this.updatedAt,
    this.unread = 0,
    this.pinned = false,
    this.muted = false,
    this.participantIds = const [],
    this.contextMemo = '',
    this.contextMemoUpdatedAt,
    this.summarizedThroughMessageId,
    this.suppressedMemoryKeys = const [],
    this.variables = const {},
    this.parentThreadId,
    this.branchedFromMessageId,
  });

  final String id;
  final String relationshipId;
  final ThreadType type;
  final String title;
  final DateTime updatedAt;
  final int unread;
  final bool pinned;
  final bool muted;
  final List<String> participantIds;

  /// Rolling, locally persisted narrative memory for this conversation only.
  final String contextMemo;
  final DateTime? contextMemoUpdatedAt;

  /// The last message covered by [contextMemo], used for incremental updates.
  final String? summarizedThroughMessageId;
  final List<String> suppressedMemoryKeys;

  /// Chat-scoped macro variables (SillyTavern-compatible getvar/setvar/etc.).
  final Map<String, String> variables;

  /// Set when this conversation is an independent branch of another thread.
  final String? parentThreadId;
  final String? branchedFromMessageId;

  ChatThread copyWith({
    String? title,
    DateTime? updatedAt,
    int? unread,
    bool? pinned,
    bool? muted,
    List<String>? participantIds,
    String? contextMemo,
    DateTime? contextMemoUpdatedAt,
    bool clearContextMemoUpdatedAt = false,
    String? summarizedThroughMessageId,
    bool clearSummarizedThroughMessageId = false,
    List<String>? suppressedMemoryKeys,
    Map<String, String>? variables,
    String? parentThreadId,
    String? branchedFromMessageId,
  }) => ChatThread(
    id: id,
    relationshipId: relationshipId,
    type: type,
    title: title ?? this.title,
    updatedAt: updatedAt ?? this.updatedAt,
    unread: unread ?? this.unread,
    pinned: pinned ?? this.pinned,
    muted: muted ?? this.muted,
    participantIds: participantIds ?? this.participantIds,
    contextMemo: contextMemo ?? this.contextMemo,
    contextMemoUpdatedAt: clearContextMemoUpdatedAt
        ? null
        : contextMemoUpdatedAt ?? this.contextMemoUpdatedAt,
    summarizedThroughMessageId: clearSummarizedThroughMessageId
        ? null
        : summarizedThroughMessageId ?? this.summarizedThroughMessageId,
    suppressedMemoryKeys: suppressedMemoryKeys ?? this.suppressedMemoryKeys,
    variables: variables ?? this.variables,
    parentThreadId: parentThreadId ?? this.parentThreadId,
    branchedFromMessageId:
        branchedFromMessageId ?? this.branchedFromMessageId,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'relationshipId': relationshipId,
    'type': type.name,
    'title': title,
    'updatedAt': updatedAt.toIso8601String(),
    'unread': unread,
    'pinned': pinned,
    'muted': muted,
    'participantIds': participantIds,
    'contextMemo': contextMemo,
    'contextMemoUpdatedAt': contextMemoUpdatedAt?.toIso8601String(),
    'summarizedThroughMessageId': summarizedThroughMessageId,
    'suppressedMemoryKeys': suppressedMemoryKeys,
    'variables': variables,
    'parentThreadId': parentThreadId,
    'branchedFromMessageId': branchedFromMessageId,
  };

  factory ChatThread.fromJson(Map<String, dynamic> json) => ChatThread(
    id: json['id'] as String? ?? '',
    relationshipId: json['relationshipId'] as String? ?? '',
    type: ThreadType.values.firstWhere(
      (e) => e.name == json['type'],
      orElse: () => ThreadType.direct,
    ),
    title: json['title'] as String? ?? '',
    updatedAt:
        DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? DateTime.now(),
    unread: (json['unread'] as num?)?.toInt() ?? 0,
    pinned: json['pinned'] as bool? ?? false,
    muted: json['muted'] as bool? ?? false,
    participantIds:
        (json['participantIds'] as List?)?.map((e) => e.toString()).toList() ??
        const [],
    contextMemo: json['contextMemo'] as String? ?? '',
    contextMemoUpdatedAt: DateTime.tryParse(
      json['contextMemoUpdatedAt'] as String? ?? '',
    ),
    summarizedThroughMessageId: json['summarizedThroughMessageId'] as String?,
    suppressedMemoryKeys:
        (json['suppressedMemoryKeys'] as List?)?.whereType<String>().toList() ??
        const [],
    variables: json['variables'] is Map
        ? Map<String, dynamic>.from(json['variables'] as Map).map(
            (key, value) => MapEntry(key, value?.toString() ?? ''),
          )
        : const {},
    parentThreadId: json['parentThreadId'] as String?,
    branchedFromMessageId: json['branchedFromMessageId'] as String?,
  );
}

class MemoryItem {
  const MemoryItem({
    required this.id,
    required this.relationshipId,
    required this.type,
    required this.title,
    required this.content,
    required this.createdAt,
    this.sourceThreadId,
    this.sourceMessageId,
    this.pinned = false,
    this.autoGenerated = false,
  });

  final String id;
  final String relationshipId;
  final MemoryType type;
  final String title;
  final String content;
  final DateTime createdAt;
  final String? sourceThreadId;
  final String? sourceMessageId;
  final bool pinned;
  final bool autoGenerated;

  MemoryItem copyWith({
    MemoryType? type,
    String? title,
    String? content,
    bool? pinned,
    bool? autoGenerated,
    String? sourceMessageId,
    bool clearSource = false,
  }) => MemoryItem(
    id: id,
    relationshipId: relationshipId,
    type: type ?? this.type,
    title: title ?? this.title,
    content: content ?? this.content,
    createdAt: createdAt,
    sourceThreadId: clearSource ? null : sourceThreadId,
    sourceMessageId: clearSource
        ? null
        : sourceMessageId ?? this.sourceMessageId,
    pinned: pinned ?? this.pinned,
    autoGenerated: autoGenerated ?? this.autoGenerated,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'relationshipId': relationshipId,
    'type': type.name,
    'title': title,
    'content': content,
    'createdAt': createdAt.toIso8601String(),
    'sourceThreadId': sourceThreadId,
    'sourceMessageId': sourceMessageId,
    'pinned': pinned,
    'autoGenerated': autoGenerated,
  };

  factory MemoryItem.fromJson(Map<String, dynamic> json) => MemoryItem(
    id: json['id'] as String? ?? '',
    relationshipId: json['relationshipId'] as String? ?? '',
    type: MemoryType.fromName(json['type'] as String?),
    title: json['title'] as String? ?? '',
    content: json['content'] as String? ?? '',
    createdAt:
        DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
    sourceThreadId: json['sourceThreadId'] as String?,
    sourceMessageId: json['sourceMessageId'] as String?,
    pinned: json['pinned'] as bool? ?? false,
    autoGenerated: json['autoGenerated'] as bool? ?? false,
  );
}

class MomentComment {
  const MomentComment({
    required this.id,
    required this.authorName,
    required this.content,
    required this.createdAt,
    this.fromAi = false,
  });

  final String id;
  final String authorName;
  final String content;
  final DateTime createdAt;
  final bool fromAi;

  MomentComment copyWith({String? content}) => MomentComment(
    id: id,
    authorName: authorName,
    content: content ?? this.content,
    createdAt: createdAt,
    fromAi: fromAi,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'authorName': authorName,
    'content': content,
    'createdAt': createdAt.toIso8601String(),
    'fromAi': fromAi,
  };

  factory MomentComment.fromJson(Map<String, dynamic> json) => MomentComment(
    id: json['id'] as String? ?? '',
    authorName: json['authorName'] as String? ?? '',
    content: json['content'] as String? ?? '',
    createdAt:
        DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
    fromAi: json['fromAi'] as bool? ?? false,
  );
}

class Moment {
  const Moment({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.content,
    required this.createdAt,
    this.fromAi = false,
    this.avatarColor = 0xFF5B7CFA,
    this.likedBy = const [],
    this.comments = const [],
  });

  final String id;
  final String authorId;
  final String authorName;
  final String content;
  final DateTime createdAt;
  final bool fromAi;
  final int avatarColor;
  final List<String> likedBy;
  final List<MomentComment> comments;

  Moment copyWith({
    String? content,
    List<String>? likedBy,
    List<MomentComment>? comments,
  }) => Moment(
    id: id,
    authorId: authorId,
    authorName: authorName,
    content: content ?? this.content,
    createdAt: createdAt,
    fromAi: fromAi,
    avatarColor: avatarColor,
    likedBy: likedBy ?? this.likedBy,
    comments: comments ?? this.comments,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'authorId': authorId,
    'authorName': authorName,
    'content': content,
    'createdAt': createdAt.toIso8601String(),
    'fromAi': fromAi,
    'avatarColor': avatarColor,
    'likedBy': likedBy,
    'comments': comments.map((e) => e.toJson()).toList(),
  };

  factory Moment.fromJson(Map<String, dynamic> json) => Moment(
    id: json['id'] as String? ?? '',
    authorId: json['authorId'] as String? ?? '',
    authorName: json['authorName'] as String? ?? '',
    content: json['content'] as String? ?? '',
    createdAt:
        DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
    fromAi: json['fromAi'] as bool? ?? false,
    avatarColor: (json['avatarColor'] as num?)?.toInt() ?? 0xFF5B7CFA,
    likedBy:
        (json['likedBy'] as List?)?.map((e) => e.toString()).toList() ??
        const [],
    comments:
        (json['comments'] as List?)
            ?.whereType<Map>()
            .map((e) => MomentComment.fromJson(Map<String, dynamic>.from(e)))
            .toList() ??
        const [],
  );
}

class ProviderConfig {
  const ProviderConfig({
    this.kind = ProviderKind.openaiCompatible,
    this.baseUrl = 'https://api.deepseek.com',
    this.model = '',
    this.models = const [],
    this.rememberKey = false,
    this.temperature = 0.85,
    this.topP = 1,
    this.frequencyPenalty = 0,
    this.presencePenalty = 0,
    this.maxOutputTokens,
    this.stopSequences = const [],
  });

  final ProviderKind kind;
  final String baseUrl;
  final String model;
  final bool rememberKey;
  final List<String> models;
  final double temperature;
  final double topP;
  final double frequencyPenalty;
  final double presencePenalty;
  final int? maxOutputTokens;
  final List<String> stopSequences;

  bool get isOfficialDeepSeek {
    final uri = Uri.tryParse(baseUrl.trim());
    return uri != null &&
        uri.scheme == 'https' &&
        uri.host.toLowerCase() == 'api.deepseek.com' &&
        uri.userInfo.isEmpty &&
        !uri.hasPort &&
        !uri.hasQuery &&
        !uri.hasFragment;
  }

  /// Root, /v1 and completion/catalog URLs may name the same API. A different
  /// origin or tenant path must never inherit another supplier's saved key.
  bool sharesCredentialScopeWith(ProviderConfig other) {
    String? scope(String value) {
      final uri = Uri.tryParse(value.trim());
      if (uri == null ||
          !['http', 'https'].contains(uri.scheme) ||
          uri.host.isEmpty ||
          uri.userInfo.isNotEmpty ||
          uri.hasQuery ||
          uri.hasFragment) {
        return null;
      }
      var path = uri.path.replaceAll(RegExp(r'/+$'), '');
      path = path.replaceFirst(
        RegExp(r'/(chat/completions|messages|models)$'),
        '',
      );
      path = path.replaceFirst(RegExp(r'/v1$'), '');
      if (uri.host.toLowerCase() == 'api.deepseek.com' &&
          path == '/anthropic') {
        path = '';
      }
      return '${uri.scheme}://${uri.host.toLowerCase()}:${uri.port}$path';
    }

    final current = scope(baseUrl);
    return current != null && current == scope(other.baseUrl);
  }

  ProviderConfig copyWith({
    ProviderKind? kind,
    String? baseUrl,
    String? model,
    List<String>? models,
    bool? rememberKey,
    double? temperature,
    double? topP,
    double? frequencyPenalty,
    double? presencePenalty,
    int? maxOutputTokens,
    bool clearMaxOutputTokens = false,
    List<String>? stopSequences,
  }) => ProviderConfig(
    kind: kind ?? this.kind,
    baseUrl: baseUrl ?? this.baseUrl,
    model: model ?? this.model,
    models: models ?? this.models,
    rememberKey: rememberKey ?? this.rememberKey,
    temperature: temperature ?? this.temperature,
    topP: topP ?? this.topP,
    frequencyPenalty: frequencyPenalty ?? this.frequencyPenalty,
    presencePenalty: presencePenalty ?? this.presencePenalty,
    maxOutputTokens: clearMaxOutputTokens
        ? null
        : maxOutputTokens ?? this.maxOutputTokens,
    stopSequences: stopSequences ?? this.stopSequences,
  );

  bool hasSameRequestSettingsAs(ProviderConfig other) =>
      kind == other.kind &&
      baseUrl == other.baseUrl &&
      model == other.model &&
      temperature == other.temperature &&
      topP == other.topP &&
      frequencyPenalty == other.frequencyPenalty &&
      presencePenalty == other.presencePenalty &&
      maxOutputTokens == other.maxOutputTokens &&
      stopSequences.join('\u0000') == other.stopSequences.join('\u0000');

  Map<String, dynamic> toJson() => {
    'kind': kind.name,
    'baseUrl': baseUrl,
    'model': model,
    'models': models,
    'rememberKey': rememberKey,
    'temperature': temperature,
    'topP': topP,
    'frequencyPenalty': frequencyPenalty,
    'presencePenalty': presencePenalty,
    'maxOutputTokens': maxOutputTokens,
    'stopSequences': stopSequences,
  };

  factory ProviderConfig.fromJson(Map<String, dynamic> json) => ProviderConfig(
    kind: ProviderKind.values.firstWhere(
      (e) => e.name == json['kind'],
      orElse: () => ProviderKind.openaiCompatible,
    ),
    baseUrl: json['baseUrl'] as String? ?? 'https://api.deepseek.com',
    model: json['model'] as String? ?? '',
    models: (json['models'] as List?)?.whereType<String>().toList() ?? const [],
    rememberKey: json['rememberKey'] as bool? ?? false,
    temperature: ((json['temperature'] as num?)?.toDouble() ?? 0.85).clamp(
      0,
      2,
    ),
    topP: ((json['topP'] as num?)?.toDouble() ?? 1).clamp(0, 1),
    frequencyPenalty:
        ((json['frequencyPenalty'] as num?)?.toDouble() ?? 0).clamp(-2, 2),
    presencePenalty:
        ((json['presencePenalty'] as num?)?.toDouble() ?? 0).clamp(-2, 2),
    maxOutputTokens: switch ((json['maxOutputTokens'] as num?)?.toInt()) {
      final int value when value > 0 => value.clamp(1, 131072),
      _ => null,
    },
    stopSequences:
        (json['stopSequences'] as List?)
            ?.whereType<String>()
            .map((value) => value.trim())
            .where((value) => value.isNotEmpty)
            .take(4)
            .toList() ??
        const [],
  );
}

/// Configuration only. Credentials live in a separate secure/session store.
class DeepSeekToolConfig {
  const DeepSeekToolConfig({this.useChatKey = true, this.rememberKey = false});

  final bool useChatKey;
  final bool rememberKey;

  Map<String, dynamic> toJson() => {
    'useChatKey': useChatKey,
    'rememberKey': rememberKey,
  };

  factory DeepSeekToolConfig.fromJson(Map<String, dynamic> json) =>
      DeepSeekToolConfig(
        useChatKey: json['useChatKey'] as bool? ?? true,
        rememberKey: json['rememberKey'] as bool? ?? false,
      );
}

enum RegexTarget {
  userInput('用户输入'),
  aiOutput('AI 输出');

  const RegexTarget(this.label);
  final String label;

  static RegexTarget fromName(String? value) => values.firstWhere(
    (e) => e.name == value,
    orElse: () => RegexTarget.aiOutput,
  );
}

/// Power-user text transformation. Patterns are regex only; no JavaScript,
/// shell, network or arbitrary code execution is supported.
class RegexRule {
  const RegexRule({
    required this.id,
    required this.name,
    required this.pattern,
    required this.replacement,
    this.target = RegexTarget.aiOutput,
    this.enabled = true,
    this.caseSensitive = false,
    this.multiline = true,
    this.dotAll = true,
    this.order = 100,
  });

  final String id;
  final String name;
  final String pattern;
  final String replacement;
  final RegexTarget target;
  final bool enabled;
  final bool caseSensitive;
  final bool multiline;
  final bool dotAll;
  final int order;

  RegexRule copyWith({
    String? name,
    String? pattern,
    String? replacement,
    RegexTarget? target,
    bool? enabled,
    bool? caseSensitive,
    bool? multiline,
    bool? dotAll,
    int? order,
  }) => RegexRule(
    id: id,
    name: name ?? this.name,
    pattern: pattern ?? this.pattern,
    replacement: replacement ?? this.replacement,
    target: target ?? this.target,
    enabled: enabled ?? this.enabled,
    caseSensitive: caseSensitive ?? this.caseSensitive,
    multiline: multiline ?? this.multiline,
    dotAll: dotAll ?? this.dotAll,
    order: order ?? this.order,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'pattern': pattern,
    'replacement': replacement,
    'target': target.name,
    'enabled': enabled,
    'caseSensitive': caseSensitive,
    'multiline': multiline,
    'dotAll': dotAll,
    'order': order,
  };

  factory RegexRule.fromJson(Map<String, dynamic> json) => RegexRule(
    id: json['id'] as String? ?? '',
    name: json['name'] as String? ?? '未命名规则',
    pattern: json['pattern'] as String? ?? '',
    replacement: json['replacement'] as String? ?? '',
    target: RegexTarget.fromName(json['target'] as String?),
    enabled: json['enabled'] as bool? ?? true,
    caseSensitive: json['caseSensitive'] as bool? ?? false,
    multiline: json['multiline'] as bool? ?? true,
    dotAll: json['dotAll'] as bool? ?? true,
    order: (json['order'] as num?)?.toInt() ?? 100,
  );
}

class PromptConfig {
  const PromptConfig({
    this.systemPrefix = '',
    this.postHistoryInstructions = '',
    this.rules = const [],
  });

  final String systemPrefix;
  final String postHistoryInstructions;
  final List<RegexRule> rules;

  PromptConfig copyWith({
    String? systemPrefix,
    String? postHistoryInstructions,
    List<RegexRule>? rules,
  }) => PromptConfig(
    systemPrefix: systemPrefix ?? this.systemPrefix,
    postHistoryInstructions:
        postHistoryInstructions ?? this.postHistoryInstructions,
    rules: rules ?? this.rules,
  );

  Map<String, dynamic> toJson() => {
    'systemPrefix': systemPrefix,
    'postHistoryInstructions': postHistoryInstructions,
    'rules': rules.map((e) => e.toJson()).toList(),
  };

  factory PromptConfig.fromJson(Map<String, dynamic> json) => PromptConfig(
    systemPrefix: json['systemPrefix'] as String? ?? '',
    postHistoryInstructions: json['postHistoryInstructions'] as String? ?? '',
    rules:
        (json['rules'] as List?)
            ?.whereType<Map>()
            .map((e) => RegexRule.fromJson(Map<String, dynamic>.from(e)))
            .toList() ??
        const [],
  );
}

class AppSettings {
  const AppSettings({
    this.themeMode = AppThemeMode.system,
    this.ageConfirmed = false,
    this.onboardingComplete = false,
    this.currentPersonaId = '',
    this.provider = const ProviderConfig(),
    this.tools = const DeepSeekToolConfig(),
    this.prompts = const PromptConfig(),
    this.contentCeiling = ContentLevel.mature,
  });

  final AppThemeMode themeMode;
  final bool ageConfirmed;
  final bool onboardingComplete;
  final String currentPersonaId;
  final ProviderConfig provider;
  final DeepSeekToolConfig tools;
  final PromptConfig prompts;
  final ContentLevel contentCeiling;

  AppSettings copyWith({
    AppThemeMode? themeMode,
    bool? ageConfirmed,
    bool? onboardingComplete,
    String? currentPersonaId,
    ProviderConfig? provider,
    DeepSeekToolConfig? tools,
    PromptConfig? prompts,
    ContentLevel? contentCeiling,
  }) => AppSettings(
    themeMode: themeMode ?? this.themeMode,
    ageConfirmed: ageConfirmed ?? this.ageConfirmed,
    onboardingComplete: onboardingComplete ?? this.onboardingComplete,
    currentPersonaId: currentPersonaId ?? this.currentPersonaId,
    provider: provider ?? this.provider,
    tools: tools ?? this.tools,
    prompts: prompts ?? this.prompts,
    contentCeiling: contentCeiling ?? this.contentCeiling,
  );

  Map<String, dynamic> toJson() => {
    'themeMode': themeMode.name,
    'ageConfirmed': ageConfirmed,
    'onboardingComplete': onboardingComplete,
    'currentPersonaId': currentPersonaId,
    'provider': provider.toJson(),
    'tools': tools.toJson(),
    'prompts': prompts.toJson(),
    'contentCeiling': contentCeiling.name,
  };

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
    themeMode: AppThemeMode.values.firstWhere(
      (e) => e.name == json['themeMode'],
      orElse: () => AppThemeMode.system,
    ),
    ageConfirmed: json['ageConfirmed'] as bool? ?? false,
    onboardingComplete: json['onboardingComplete'] as bool? ?? false,
    currentPersonaId: json['currentPersonaId'] as String? ?? '',
    provider: ProviderConfig.fromJson(
      Map<String, dynamic>.from(json['provider'] as Map? ?? const {}),
    ),
    tools: DeepSeekToolConfig.fromJson(
      Map<String, dynamic>.from(json['tools'] as Map? ?? const {}),
    ),
    prompts: PromptConfig.fromJson(
      Map<String, dynamic>.from(json['prompts'] as Map? ?? const {}),
    ),
    contentCeiling: ContentLevel.fromName(json['contentCeiling'] as String?),
  );
}

enum WorldInfoMode {
  keyword('关键词'),
  constant('常驻');

  const WorldInfoMode(this.label);
  final String label;

  static WorldInfoMode fromName(String? value) => values.firstWhere(
    (e) => e.name == value,
    orElse: () => WorldInfoMode.keyword,
  );
}

/// World Info / World Book entry, compatible with the core SillyTavern idea:
/// keyword-triggered lore injected into the system prompt before the chat.
class WorldInfoEntry {
  const WorldInfoEntry({
    required this.id,
    required this.keys,
    required this.content,
    this.comment = '',
    this.mode = WorldInfoMode.keyword,
    this.order = 100,
    this.probability = 100,
    this.recursive = false,
    this.enabled = true,
    this.secondaryKeys = const [],
    this.caseSensitive = false,
    this.depth = 4,
  });

  final String id;
  final List<String> keys;
  final String content;
  final String comment;
  final WorldInfoMode mode;
  final int order;
  final int probability;
  final bool recursive;
  final bool enabled;

  /// SillyTavern secondary keys: when present, at least one must also match.
  final List<String> secondaryKeys;
  final bool caseSensitive;
  final int depth;

  WorldInfoEntry copyWith({
    List<String>? keys,
    String? content,
    String? comment,
    WorldInfoMode? mode,
    int? order,
    int? probability,
    bool? recursive,
    bool? enabled,
    List<String>? secondaryKeys,
    bool? caseSensitive,
    int? depth,
  }) => WorldInfoEntry(
    id: id,
    keys: keys ?? this.keys,
    content: content ?? this.content,
    comment: comment ?? this.comment,
    mode: mode ?? this.mode,
    order: order ?? this.order,
    probability: probability ?? this.probability,
    recursive: recursive ?? this.recursive,
    enabled: enabled ?? this.enabled,
    secondaryKeys: secondaryKeys ?? this.secondaryKeys,
    caseSensitive: caseSensitive ?? this.caseSensitive,
    depth: depth ?? this.depth,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'keys': keys,
    'content': content,
    'comment': comment,
    'mode': mode.name,
    'order': order,
    'probability': probability,
    'recursive': recursive,
    'enabled': enabled,
    'secondaryKeys': secondaryKeys,
    'caseSensitive': caseSensitive,
    'depth': depth,
  };

  factory WorldInfoEntry.fromJson(Map<String, dynamic> json) => WorldInfoEntry(
    id: json['id'] as String? ?? '',
    keys:
        (json['keys'] as List?)?.map((e) => e.toString()).toList() ?? const [],
    content: json['content'] as String? ?? '',
    comment: json['comment'] as String? ?? '',
    mode: WorldInfoMode.fromName(json['mode'] as String?),
    order: (json['order'] as num?)?.toInt() ?? 100,
    probability: (json['probability'] as num?)?.toInt() ?? 100,
    recursive: json['recursive'] as bool? ?? false,
    enabled: json['enabled'] as bool? ?? true,
    secondaryKeys:
        (json['secondaryKeys'] as List?)
            ?.map((e) => e.toString())
            .toList() ??
        const [],
    caseSensitive: json['caseSensitive'] as bool? ?? false,
    depth: (json['depth'] as num?)?.toInt() ?? 4,
  );
}

class WorldBook {
  const WorldBook({
    required this.id,
    required this.name,
    required this.entries,
    this.authorNote = '',
    this.authorNoteDepth = 2,
    this.enabled = true,
    this.scanDepth = 4,
    this.maxEntries = 4,
    this.recursionDepth = 2,
  });

  final String id;
  final String name;
  final List<WorldInfoEntry> entries;
  final String authorNote;
  final int authorNoteDepth;
  final bool enabled;
  final int scanDepth;
  final int maxEntries;
  final int recursionDepth;

  WorldBook copyWith({
    String? name,
    List<WorldInfoEntry>? entries,
    String? authorNote,
    int? authorNoteDepth,
    bool? enabled,
    int? scanDepth,
    int? maxEntries,
    int? recursionDepth,
  }) => WorldBook(
    id: id,
    name: name ?? this.name,
    entries: entries ?? this.entries,
    authorNote: authorNote ?? this.authorNote,
    authorNoteDepth: authorNoteDepth ?? this.authorNoteDepth,
    enabled: enabled ?? this.enabled,
    scanDepth: scanDepth ?? this.scanDepth,
    maxEntries: maxEntries ?? this.maxEntries,
    recursionDepth: recursionDepth ?? this.recursionDepth,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'entries': entries.map((e) => e.toJson()).toList(),
    'authorNote': authorNote,
    'authorNoteDepth': authorNoteDepth,
    'enabled': enabled,
    'scanDepth': scanDepth,
    'maxEntries': maxEntries,
    'recursionDepth': recursionDepth,
  };

  factory WorldBook.fromJson(Map<String, dynamic> json) => WorldBook(
    id: json['id'] as String? ?? '',
    name: json['name'] as String? ?? '默认世界书',
    entries:
        (json['entries'] as List?)
            ?.whereType<Map>()
            .map((e) => WorldInfoEntry.fromJson(Map<String, dynamic>.from(e)))
            .toList() ??
        const [],
    authorNote: json['authorNote'] as String? ?? '',
    authorNoteDepth: (json['authorNoteDepth'] as num?)?.toInt() ?? 2,
    enabled: json['enabled'] as bool? ?? true,
    scanDepth: (json['scanDepth'] as num?)?.toInt() ?? 4,
    maxEntries: (json['maxEntries'] as num?)?.toInt() ?? 4,
    recursionDepth: (json['recursionDepth'] as num?)?.toInt() ?? 2,
  );
}

class AppData {
  const AppData({
    required this.schemaVersion,
    required this.owner,
    required this.settings,
    required this.personas,
    required this.characters,
    required this.relationships,
    required this.threads,
    required this.messages,
    required this.memories,
    required this.moments,
    required this.worldBooks,
  });

  final int schemaVersion;
  final OwnerProfile owner;
  final AppSettings settings;
  final List<UserPersona> personas;
  final List<Character> characters;
  final List<Relationship> relationships;
  final List<ChatThread> threads;
  final List<Message> messages;
  final List<MemoryItem> memories;
  final List<Moment> moments;
  final List<WorldBook> worldBooks;

  AppData copyWith({
    OwnerProfile? owner,
    AppSettings? settings,
    List<UserPersona>? personas,
    List<Character>? characters,
    List<Relationship>? relationships,
    List<ChatThread>? threads,
    List<Message>? messages,
    List<MemoryItem>? memories,
    List<Moment>? moments,
    List<WorldBook>? worldBooks,
  }) => AppData(
    schemaVersion: schemaVersion,
    owner: owner ?? this.owner,
    settings: settings ?? this.settings,
    personas: personas ?? this.personas,
    characters: characters ?? this.characters,
    relationships: relationships ?? this.relationships,
    threads: threads ?? this.threads,
    messages: messages ?? this.messages,
    memories: memories ?? this.memories,
    moments: moments ?? this.moments,
    worldBooks: worldBooks ?? this.worldBooks,
  );

  Map<String, dynamic> toJson() => {
    'schemaVersion': schemaVersion,
    'owner': owner.toJson(),
    'settings': settings.toJson(),
    'personas': personas.map((e) => e.toJson()).toList(),
    'characters': characters.map((e) => e.toJson()).toList(),
    'relationships': relationships.map((e) => e.toJson()).toList(),
    'threads': threads.map((e) => e.toJson()).toList(),
    'messages': messages.map((e) => e.toJson()).toList(),
    'memories': memories.map((e) => e.toJson()).toList(),
    'moments': moments.map((e) => e.toJson()).toList(),
    'worldBooks': worldBooks.map((e) => e.toJson()).toList(),
  };

  factory AppData.fromJson(Map<String, dynamic> json) => AppData(
    schemaVersion: (json['schemaVersion'] as num?)?.toInt() ?? 2,
    owner: OwnerProfile.fromJson(
      Map<String, dynamic>.from(json['owner'] as Map? ?? const {}),
    ),
    settings: AppSettings.fromJson(
      Map<String, dynamic>.from(json['settings'] as Map? ?? const {}),
    ),
    personas:
        (json['personas'] as List?)
            ?.whereType<Map>()
            .map((e) => UserPersona.fromJson(Map<String, dynamic>.from(e)))
            .toList() ??
        const [],
    characters:
        (json['characters'] as List?)
            ?.whereType<Map>()
            .map((e) => Character.fromJson(Map<String, dynamic>.from(e)))
            .toList() ??
        const [],
    relationships:
        (json['relationships'] as List?)
            ?.whereType<Map>()
            .map((e) => Relationship.fromJson(Map<String, dynamic>.from(e)))
            .toList() ??
        const [],
    threads:
        (json['threads'] as List?)
            ?.whereType<Map>()
            .map((e) => ChatThread.fromJson(Map<String, dynamic>.from(e)))
            .toList() ??
        const [],
    messages:
        (json['messages'] as List?)
            ?.whereType<Map>()
            .map((e) => Message.fromJson(Map<String, dynamic>.from(e)))
            .toList() ??
        const [],
    memories:
        (json['memories'] as List?)
            ?.whereType<Map>()
            .map((e) => MemoryItem.fromJson(Map<String, dynamic>.from(e)))
            .toList() ??
        const [],
    moments:
        (json['moments'] as List?)
            ?.whereType<Map>()
            .map((e) => Moment.fromJson(Map<String, dynamic>.from(e)))
            .toList() ??
        const [],
    worldBooks:
        (json['worldBooks'] as List?)
            ?.whereType<Map>()
            .map((e) => WorldBook.fromJson(Map<String, dynamic>.from(e)))
            .toList() ??
        const [],
  );

  Set<String> get attachmentReferences => {
    if (owner.avatarReference != null) owner.avatarReference!,
    for (final persona in personas)
      if (persona.avatarReference != null) persona.avatarReference!,
    for (final character in characters)
      if (character.avatarReference != null) character.avatarReference!,
    for (final message in messages)
      if (message.localPath != null) message.localPath!,
  };

  String encode() => jsonEncode(toJson());

  factory AppData.decode(String source) =>
      AppData.fromJson(Map<String, dynamic>.from(jsonDecode(source) as Map));

  Character? characterForRelationship(Relationship relationship) {
    for (final character in characters) {
      if (character.id == relationship.characterId) return character;
    }
    return null;
  }

  Relationship? relationshipForThread(ChatThread thread) {
    for (final relationship in relationships) {
      if (relationship.id == thread.relationshipId) return relationship;
    }
    return null;
  }

  /// Finds a character's relationship, preferring the active persona.
  Relationship? relationshipForCharacter(
    String characterId, {
    String? personaId,
  }) {
    Relationship? fallback;
    for (final relationship in relationships) {
      if (relationship.characterId != characterId) continue;
      if (personaId == null || relationship.personaId == personaId) {
        return relationship;
      }
      fallback ??= relationship;
    }
    return fallback;
  }

  ChatThread? threadForRelationship(String relationshipId) {
    for (final thread in threads) {
      if (thread.relationshipId == relationshipId) return thread;
    }
    return null;
  }

  UserPersona? personaById(String id) {
    for (final persona in personas) {
      if (persona.id == id) return persona;
    }
    return null;
  }
}
