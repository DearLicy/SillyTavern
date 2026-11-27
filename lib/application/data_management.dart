part of 'app_controller.dart';

/// Destructive changes invalidate both visible streaming and quiet memory work
/// before mutating local _snapshot. They never call a model or touch another chat.
extension DataManagement on AppController {
  void _invalidateThread(String threadId) {
    _threadRevisions[threadId] = (_threadRevisions[threadId] ?? 0) + 1;
    if (_snapshot.generatingThreadId == threadId) _stopActiveGeneration();
    final abort = _summaryAbortTriggers[threadId];
    if (abort != null && !abort.isCompleted) abort.complete();
    _summaryRetryAfter.remove(threadId);
  }

  ChatThread _withoutMemo(ChatThread thread) => thread.copyWith(
    contextMemo: '',
    clearContextMemoUpdatedAt: true,
    clearSummarizedThroughMessageId: true,
  );

  /// Commit the database first. A failed save must never destroy attachments
  /// still referenced by the last durable snapshot. Shared files stay alive.
  Future<void> _saveManagementChange(AppData before, AppData after) async {
    final kept = after.attachmentReferences;
    _pendingAttachmentDeletes.addAll(
      before.attachmentReferences.where((path) => !kept.contains(path)),
    );
    _commit(after);
    try {
      await flush();
    } catch (_) {
      _snapshot = _snapshot.copyWith(error: '保存失败，请重试。附件尚未删除。');
      throw StateError('保存失败，请重试。附件尚未删除。');
    }
  }

  Future<void> _cleanupAttachments(AppData durable) async {
    final persisted = durable.attachmentReferences;
    for (final reference in List<String>.of(_pendingAttachmentDeletes)) {
      if (persisted.contains(reference) ||
          _snapshot.data.attachmentReferences.contains(reference)) {
        continue;
      }
      try {
        await _attachmentStore?.delete(reference);
        _pendingAttachmentDeletes.remove(reference);
      } catch (_) {
        // Keep the reference queued; the next successful save retries cleanup.
        _snapshot = _snapshot.copyWith(error: '数据已保存，但部分附件清理失败，下次保存时将重试。');
      }
    }
  }

  /// Clear the transcript and rolling recap; deliberately retain learned facts,
  /// boundaries and relationship scores. Restart is a separate explicit action.
  Future<void> clearChatHistory(String threadId) async {
    if (!_snapshot.data.threads.any((t) => t.id == threadId)) return;
    _invalidateThread(threadId);
    final before = _snapshot.data;
    await _saveManagementChange(
      before,
      before.copyWith(
        messages: before.messages.where((m) => m.threadId != threadId).toList(),
        threads: [
          for (final t in before.threads)
            t.id == threadId
                ? _withoutMemo(t).copyWith(unread: 0, updatedAt: DateTime.now())
                : t,
        ],
        memories: [
          for (final m in before.memories)
            m.sourceThreadId == threadId ? m.copyWith(clearSource: true) : m,
        ],
      ),
    );
  }

  /// Start this persona's relationship again. Keep the authored character,
  /// persona and explicit user-authored boundary memories.
  Future<void> restartRelationship(String relationshipId) async {
    final relationship = _snapshot.data.relationships
        .where((r) => r.id == relationshipId)
        .firstOrNull;
    if (relationship == null) return;
    final ids = _snapshot.data.threads
        .where((t) => t.relationshipId == relationshipId)
        .map((t) => t.id)
        .toSet();
    for (final id in ids) {
      _invalidateThread(id);
    }
    final before = _snapshot.data;
    final now = DateTime.now();
    await _saveManagementChange(
      before,
      before.copyWith(
        messages: before.messages
            .where((m) => !ids.contains(m.threadId))
            .toList(),
        memories: [
          for (final m in before.memories)
            if (m.relationshipId != relationshipId)
              m
            else if (m.type == MemoryType.boundary)
              m.copyWith(clearSource: true),
        ],
        threads: [
          for (final t in before.threads)
            ids.contains(t.id)
                ? _withoutMemo(t).copyWith(
                    unread: 0,
                    updatedAt: now,
                    suppressedMemoryKeys: const [],
                  )
                : t,
        ],
        relationships: [
          for (final r in before.relationships)
            r.id == relationshipId
                ? r.copyWith(
                    replyEnergy: 55,
                    clearLastInteractionAt: true,
                    updatedAt: now,
                  )
                : r,
        ],
      ),
    );
  }

  /// Create an independent SillyTavern-style chat branch ending at [messageId].
  /// The source chat remains untouched; messages, recap state and relationship
  /// binding is copied so the branch can continue without sharing mutations.
  Future<ChatThread> branchFromMessage(
    String threadId,
    String messageId,
  ) async {
    final before = _snapshot.data;
    final sourceThread = before.threads
        .where((thread) => thread.id == threadId)
        .firstOrNull;
    if (sourceThread == null) throw StateError('原会话不存在');
    if (sourceThread.type != ThreadType.direct) {
      throw StateError('群聊分支暂未开放，请先使用单聊');
    }
    final sourceRelationship = before.relationships
        .where((relationship) => relationship.id == sourceThread.relationshipId)
        .firstOrNull;
    if (sourceRelationship == null) throw StateError('原关系不存在');

    final ordered =
        before.messages
            .where((message) => message.threadId == threadId)
            .toList()
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final pivotIndex = ordered.indexWhere((message) => message.id == messageId);
    if (pivotIndex < 0) throw StateError('分支消息不存在');
    final sourceMessages = ordered.take(pivotIndex + 1).toList();
    final pivot = sourceMessages.last;
    final relationshipId = 'rel_${_uuid.v4()}';
    final branchThreadId = 'thread_${_uuid.v4()}';
    final messageIds = <String, String>{};
    final branchMessages = <Message>[];
    for (final message in sourceMessages) {
      final id = 'msg_${_uuid.v4()}';
      messageIds[message.id] = id;
      branchMessages.add(
        Message(
          id: id,
          threadId: branchThreadId,
          senderId: message.senderId,
          senderName: message.senderName,
          text: message.text,
          createdAt: message.createdAt,
          kind: message.kind,
          fromAi: message.fromAi,
          localPath: message.localPath,
          interrupted: message.interrupted,
          editedAt: message.editedAt,
          sources: message.sources,
          searchWeb: message.searchWeb,
        ),
      );
    }

    final relationship = Relationship(
      id: relationshipId,
      characterId: sourceRelationship.characterId,
      personaId: sourceRelationship.personaId,
      updatedAt: pivot.createdAt,
      replyEnergy: sourceRelationship.replyEnergy,
      lastInteractionAt: pivot.createdAt,
    );
    final thread = ChatThread(
      id: branchThreadId,
      relationshipId: relationshipId,
      type: ThreadType.direct,
      title: '${sourceThread.title} · 分支',
      updatedAt: DateTime.now(),
      participantIds: sourceThread.participantIds,
      variables: Map<String, String>.of(sourceThread.variables),
      parentThreadId: sourceThread.id,
      branchedFromMessageId: pivot.id,
    );
    final copiedMemories = <MemoryItem>[];
    for (final memory in before.memories) {
      if (memory.relationshipId != sourceThread.relationshipId) continue;
      final belongsToSourceThread = memory.sourceThreadId == sourceThread.id;
      final copiedSourceMessageId = messageIds[memory.sourceMessageId];
      copiedMemories.add(
        MemoryItem(
          id: 'mem_${_uuid.v4()}',
          relationshipId: relationshipId,
          type: memory.type,
          title: memory.title,
          content: memory.content,
          createdAt: memory.createdAt,
          sourceThreadId: belongsToSourceThread
              ? (copiedSourceMessageId == null ? null : branchThreadId)
              : memory.sourceThreadId,
          sourceMessageId: belongsToSourceThread
              ? copiedSourceMessageId
              : memory.sourceMessageId,
          pinned: memory.pinned,
          autoGenerated: memory.autoGenerated,
        ),
      );
    }

    await _saveManagementChange(
      before,
      before.copyWith(
        relationships: [...before.relationships, relationship],
        threads: [...before.threads, thread],
        messages: [...before.messages, ...branchMessages],
        memories: [...before.memories, ...copiedMemories],
      ),
    );
    return thread;
  }

  Future<void> deleteCharacter(String characterId) async {
    final before = _snapshot.data;
    final relationshipIds = before.relationships
        .where((r) => r.characterId == characterId)
        .map((r) => r.id)
        .toSet();
    final threadIds = before.threads
        .where((t) => relationshipIds.contains(t.relationshipId))
        .map((t) => t.id)
        .toSet();
    for (final id in threadIds) {
      _invalidateThread(id);
    }
    final current = _snapshot.data;
    await _saveManagementChange(
      current,
      current.copyWith(
        characters: current.characters
            .where((c) => c.id != characterId)
            .toList(),
        relationships: current.relationships
            .where((r) => !relationshipIds.contains(r.id))
            .toList(),
        threads: current.threads
            .where((t) => !threadIds.contains(t.id))
            .toList(),
        messages: current.messages
            .where((m) => !threadIds.contains(m.threadId))
            .toList(),
        memories: current.memories
            .where((m) => !relationshipIds.contains(m.relationshipId))
            .toList(),
      ),
    );
  }

  Future<void> deletePersona(String personaId) async {
    if (_snapshot.data.relationships.any((r) => r.personaId == personaId)) {
      throw StateError('这个用户人设仍被会话使用，请先切换或删除相关角色。');
    }
    final before = _snapshot.data;
    final remaining = before.personas.where((p) => p.id != personaId).toList();
    await _saveManagementChange(
      before,
      before.copyWith(
        personas: remaining,
        settings: before.settings.currentPersonaId == personaId
            ? before.settings.copyWith(
                currentPersonaId: remaining.firstOrNull?.id ?? '',
              )
            : before.settings,
      ),
    );
  }

  /// Manual transcript corrections clear derived summaries/facts. User-authored
  /// memories are retained with deleted/edited source links detached.
  Future<void> editMessage(String messageId, String text) async {
    final message = _snapshot.data.messages
        .where((m) => m.id == messageId)
        .firstOrNull;
    if (message == null || text.trim() == message.text) return;
    if (!message.copyWith(text: text.trim()).isRenderable) {
      throw ArgumentError('消息不能为空；如需移除请使用删除。');
    }
    await _changeMessages({messageId}, text: text.trim());
  }

  Future<void> deleteMessage(String messageId) => _changeMessages({messageId});

  Future<void> deleteMessages(Set<String> ids) => _changeMessages(ids);

  Future<void> _changeMessages(
    Set<String> messageIds, {
    String? text,
    Set<String> preserveMessageIds = const {},
  }) async {
    final affected = _snapshot.data.messages
        .where((m) => messageIds.contains(m.id))
        .map((m) => m.threadId)
        .toSet();
    if (affected.isEmpty) return;
    for (final id in affected) {
      _invalidateThread(id);
    }
    final before = _snapshot.data;
    final remaining = <Message>[
      for (final m in before.messages)
        if (!messageIds.contains(m.id) || preserveMessageIds.contains(m.id))
          m
        else if (text != null)
          m.copyWith(text: text, editedAt: DateTime.now()),
    ];
    final now = DateTime.now();
    await _saveManagementChange(
      before,
      before.copyWith(
        messages: remaining,
        threads: [
          for (final t in before.threads)
            if (affected.contains(t.id))
              _withoutMemo(t).copyWith(
                unread: 0,
                updatedAt:
                    remaining
                        .where((m) => m.threadId == t.id)
                        .lastOrNull
                        ?.createdAt ??
                    now,
              )
            else
              t,
        ],
        memories: [
          for (final m in before.memories)
            if (!(m.autoGenerated && affected.contains(m.sourceThreadId)))
              messageIds.contains(m.sourceMessageId) &&
                      !preserveMessageIds.contains(m.sourceMessageId)
                  ? m.copyWith(clearSource: true)
                  : m,
        ],
      ),
    );
  }

  /// Clears chat-scoped macro variables without touching messages or memory.
  Future<void> clearThreadVariables(String threadId) async {
    final before = _snapshot.data;
    if (!before.threads.any((t) => t.id == threadId)) return;
    await _saveManagementChange(
      before,
      before.copyWith(
        threads: [
          for (final thread in before.threads)
            thread.id == threadId
                ? thread.copyWith(variables: const {})
                : thread,
        ],
      ),
    );
  }

  /// Starts an empty chat with a chosen (primary or alternate) greeting.
  /// Does nothing once the thread already has a transcript, so it can never
  /// overwrite or duplicate an existing conversation.
  Future<void> startWithGreeting(String threadId, String greeting) async {
    final trimmed = greeting.trim();
    if (trimmed.isEmpty) return;
    final data = _snapshot.data;
    final thread = data.threads.where((t) => t.id == threadId).firstOrNull;
    if (thread == null) return;
    if (data.messages.any((m) => m.threadId == threadId)) return;
    final relationship = data.relationshipForThread(thread);
    final character = relationship == null
        ? null
        : data.characterForRelationship(relationship);
    if (character == null) return;
    _invalidateThread(threadId);
    final message = Message(
      id: _uuid.v4(),
      threadId: threadId,
      senderId: character.id,
      senderName: character.name,
      text: trimmed,
      createdAt: DateTime.now(),
      fromAi: true,
    );
    _appendMessages([message], threadId);
    await flush();
  }

  /// Creates (or reuses) a multi-character group chat. All participants share
  /// this thread, while scene/consent defaults come from the first character.
  Future<ChatThread> createGroupChat({
    required List<String> characterIds,
    String? title,
  }) async {
    final data = _snapshot.data;
    final ids = <String>[];
    for (final id in characterIds) {
      if (!ids.contains(id)) ids.add(id);
    }
    if (ids.length < 2) throw StateError('请选择至少两个角色');
    final characters = <Character>[];
    for (final id in ids) {
      final character = data.characters
          .where((item) => item.id == id)
          .firstOrNull;
      if (character == null) throw StateError('角色不存在');
      characters.add(character);
    }
    final existing = data.threads
        .where(
          (thread) =>
              thread.type == ThreadType.group &&
              thread.participantIds.length == ids.length &&
              thread.participantIds.every(ids.contains),
        )
        .firstOrNull;
    if (existing != null) return existing;

    final personaId = data.settings.currentPersonaId;
    Relationship? host;
    for (final relationship in data.relationships) {
      if (relationship.characterId != characters.first.id) continue;
      if (relationship.personaId == personaId) {
        host = relationship;
        break;
      }
      host ??= relationship;
    }
    if (host == null) {
      throw StateError('请先和第一位角色建立关系，再创建群聊');
    }
    final now = DateTime.now();
    final thread = ChatThread(
      id: 'thread_${_uuid.v4()}',
      relationshipId: host.id,
      type: ThreadType.group,
      title: title?.trim().isNotEmpty == true
          ? title!.trim()
          : '${characters.take(3).map((item) => item.name).join('、')} · 群聊',
      updatedAt: now,
      participantIds: [for (final character in characters) character.id],
    );
    final before = _snapshot.data;
    await _saveManagementChange(
      before,
      before.copyWith(threads: [...before.threads, thread]),
    );
    return thread;
  }
}
