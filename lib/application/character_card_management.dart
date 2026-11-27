part of 'app_controller.dart';

/// Import/export SillyTavern Character Card V2 JSON. Cards are treated as
/// untrusted data: only known fields are mapped, no scripts or external
/// resources are executed.
extension CharacterCardManagement on AppController {
  Future<ChatThread> importCharacterCard(String raw) async {
    final data = _snapshot.data;
    if (data.personaById(data.settings.currentPersonaId) == null) {
      throw StateError('请先创建并选择用户人设，再导入角色卡');
    }
    final decoded = const CharacterCardCodec().decode(
      raw,
      id: 'char_${_uuid.v4()}',
    );
    final before = _snapshot.data;
    final thread = addCharacterWithRelationship(decoded.character);
    final worldBook = decoded.worldBook;
    if (worldBook != null) {
      await _saveManagementChange(
        before,
        _snapshot.data.copyWith(
          worldBooks: [..._snapshot.data.worldBooks, worldBook],
        ),
      );
    } else {
      await flush();
    }
    return thread;
  }

  String exportCharacterCard(String characterId) {
    final data = _snapshot.data;
    final character = data.characters
        .where((e) => e.id == characterId)
        .firstOrNull;
    if (character == null) throw StateError('角色不存在');
    final relatedBook = _worldBookForCharacter(character);
    return const CharacterCardCodec().encode(character, worldBook: relatedBook);
  }

  WorldBook? _worldBookForCharacter(Character character) {
    final books = _snapshot.data.worldBooks;
    if (books.isEmpty) return null;
    final name = character.name.toLowerCase();
    for (final book in books) {
      if (book.name.toLowerCase().contains(name)) return book;
    }
    return books.length == 1 ? books.first : null;
  }

  /// Exports a character card as a PNG file with embedded V2 metadata.
  Future<Uint8List> exportPngCharacterCard(String characterId) async {
    final data = _snapshot.data;
    final character = data.characters
        .where((e) => e.id == characterId)
        .firstOrNull;
    if (character == null) throw StateError('角色不存在');
    final pngJson = const CharacterCardCodec().encode(
      character,
      worldBook: _worldBookForCharacter(character),
    );
    final reference = character.avatarReference;
    if (reference != null && reference.trim().isNotEmpty) {
      final avatar = await _attachmentStore?.readImage(reference);
      if (avatar != null) {
        final embedded = PngCharacterCard.embedJson(avatar, pngJson);
        if (embedded != null) return embedded;
      }
    }
    return PngCharacterCard.encodePng(pngJson);
  }
}
