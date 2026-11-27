part of 'app_controller.dart';

extension ProfileManagement on AppController {
  Future<void> _ensureProfileWrite(int epoch, String? reference) async {
    if (mounted && epoch == _lifecycleGeneration) return;
    if (reference != null &&
        (!mounted ||
            !_snapshot.data.attachmentReferences.contains(reference))) {
      await _attachmentStore?.delete(reference);
    }
    throw StateError('数据已被重置或恢复，请重新打开资料后再保存。');
  }

  Future<String?> _avatarReference(
    String? current,
    AvatarChange? change,
  ) async {
    if (change == null) return current;
    final image = change.image;
    if (image == null) return null;
    final store = _attachmentStore;
    if (store == null) throw StateError('本地图片存储不可用，请重试。');
    return store.saveImage(
      id: 'avatar_${_uuid.v4()}',
      bytes: image.bytes,
      mimeType: image.mimeType,
    );
  }

  Future<void> saveOwnerProfile(
    OwnerProfile profile, {
    AvatarChange? avatar,
  }) async {
    final epoch = _lifecycleGeneration;
    final reference = await _avatarReference(profile.avatarReference, avatar);
    await _ensureProfileWrite(epoch, reference);
    final before = _snapshot.data;
    await _saveManagementChange(
      before,
      before.copyWith(
        owner: profile.copyWith(
          avatarReference: reference,
          clearAvatar: reference == null,
        ),
      ),
    );
  }

  Future<void> savePersonaProfile(
    UserPersona persona, {
    AvatarChange? avatar,
  }) async {
    final epoch = _lifecycleGeneration;
    final existed = _snapshot.data.personas.any((p) => p.id == persona.id);
    final reference = await _avatarReference(persona.avatarReference, avatar);
    await _ensureProfileWrite(epoch, reference);
    if (existed && !_snapshot.data.personas.any((p) => p.id == persona.id)) {
      if (reference != null &&
          !_snapshot.data.attachmentReferences.contains(reference)) {
        await _attachmentStore?.delete(reference);
      }
      throw StateError('这个用户人设已被删除。');
    }
    final saved = persona.copyWith(
      avatarReference: reference,
      clearAvatar: reference == null,
    );
    final before = _snapshot.data;
    await _saveManagementChange(
      before,
      before.copyWith(
        personas: [
          for (final p in before.personas)
            if (p.id != saved.id) p,
          saved,
        ],
        settings: before.settings.currentPersonaId.isEmpty
            ? before.settings.copyWith(currentPersonaId: saved.id)
            : before.settings,
      ),
    );
  }

  Future<ChatThread?> saveCharacterProfile(
    Character character, {
    AvatarChange? avatar,
    bool create = false,
  }) async {
    final epoch = _lifecycleGeneration;
    final reference = await _avatarReference(character.avatarReference, avatar);
    await _ensureProfileWrite(epoch, reference);
    final saved = character.copyWith(
      avatarReference: reference,
      clearAvatar: reference == null,
    );
    final before = _snapshot.data;
    if (create && !before.characters.any((c) => c.id == character.id)) {
      final thread = addCharacterWithRelationship(saved);
      await _saveManagementChange(before, _snapshot.data);
      return thread;
    }
    if (!before.characters.any((c) => c.id == character.id)) {
      if (reference != null &&
          !before.attachmentReferences.contains(reference)) {
        await _attachmentStore?.delete(reference);
      }
      throw StateError('这个角色已被删除。');
    }
    await _saveManagementChange(
      before,
      before.copyWith(
        characters: [
          for (final c in before.characters) c.id == saved.id ? saved : c,
        ],
        threads: [
          for (final t in before.threads)
            before.relationshipForThread(t)?.characterId == saved.id
                ? t.copyWith(title: saved.name)
                : t,
        ],
      ),
    );
    return create
        ? _snapshot.data.threads
              .where(
                (t) =>
                    _snapshot.data.relationshipForThread(t)?.characterId ==
                    character.id,
              )
              .firstOrNull
        : null;
  }
}
