import 'dart:async';
import 'dart:typed_data';

import 'package:sillytavern_app/application/app_controller.dart';
import 'package:sillytavern_app/data/image_content.dart';
import 'package:sillytavern_app/domain/models.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures/fake_store.dart';
import 'fixtures/sample_data.dart';

class _DelayedAttachments extends MemoryAttachments {
  final started = Completer<void>(), release = Completer<void>();
  @override
  Future<String> saveImage({
    required String id,
    required Uint8List bytes,
    required String mimeType,
  }) async {
    if (!started.isCompleted) started.complete();
    await release.future;
    return super.saveImage(id: id, bytes: bytes, mimeType: mimeType);
  }
}

class _RetryStore extends FakeStore {
  _RetryStore(super.data);
  bool fail = true;
  @override
  Future<void> save(AppData data) async {
    if (fail) throw StateError('cannot save');
    await super.save(data);
  }
}

Future<AppController> start(FakeStore store, MemoryAttachments files) async {
  final c = AppController(
    store: store,
    keyStore: FakeKeyStore(),
    toolKeyStore: FakeKeyStore(),
    attachmentStore: files,
  );
  addTearDown(c.dispose);
  await Future<void>.delayed(Duration.zero);
  return c;
}

void main() {
  final avatar = AvatarChange.replace(
    ImageContent(MemoryAttachments.pixel, 'image/png'),
  );
  test(
    'slow owner avatar selection cannot resurrect old profile after full reset',
    () async {
      final files = _DelayedAttachments();
      final c = await start(FakeStore(buildSeedData()), files);
      final saving = c.saveOwnerProfile(
        c.state.data.owner.copyWith(displayName: '旧姓名'),
        avatar: avatar,
      );
      await files.started.future;
      await c.resetData();
      files.release.complete();
      await expectLater(saving, throwsStateError);
      expect(c.state.data.owner.displayName, isNot('旧姓名'));
      expect(files.files, isEmpty);
    },
  );
  test(
    'slow character avatar save cannot resurrect a deleted character or leak new image',
    () async {
      final files = _DelayedAttachments();
      final c = await start(FakeStore(buildSeedData()), files);
      final character = c.state.data.characters.first;
      final saving = c.saveCharacterProfile(character, avatar: avatar);
      await files.started.future;
      await c.deleteCharacter(character.id);
      files.release.complete();
      await expectLater(saving, throwsStateError);
      expect(c.state.data.characters.any((v) => v.id == character.id), isFalse);
      expect(files.files, isEmpty);
    },
  );
  test(
    'retrying failed character creation preserves one relationship and one character',
    () async {
      final store = _RetryStore(buildSeedData());
      final c = await start(store, MemoryAttachments());
      c.selectPersona(c.state.data.personas.first.id);
      final character = Character(
        id: 'stable-draft',
        name: '新角色',
        handle: '@new',
        age: '成年',
        intro: '',
        persona: '',
        greeting: '',
        avatarColor: 1,
        tags: const [],
      );
      await expectLater(
        c.saveCharacterProfile(character, create: true),
        throwsStateError,
      );
      store.fail = false;
      final thread = await c.saveCharacterProfile(character, create: true);
      expect(thread, isNotNull);
      expect(
        store.data!.characters.where((v) => v.id == character.id).length,
        1,
      );
      expect(
        store.data!.relationships
            .where((v) => v.characterId == character.id)
            .length,
        1,
      );
    },
  );
}
