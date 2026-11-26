import 'package:sillytavern_app/application/app_controller.dart';
import 'package:sillytavern_app/data/image_content.dart';
import 'package:sillytavern_app/domain/models.dart';
import 'package:sillytavern_app/router/app_router.dart';
import 'package:sillytavern_app/ui/components/dt_avatar.dart';
import 'package:sillytavern_app/ui/components/dt_avatar_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';

import 'fixtures/fake_store.dart';
import 'fixtures/sample_data.dart';
import 'widget_test.dart' as shared;

class _Picker extends ImagePickerPlatform {
  bool cancel = false;
  @override
  Future<XFile?> getImageFromSource({
    required ImageSource source,
    ImagePickerOptions options = const ImagePickerOptions(),
  }) async => cancel
      ? null
      : XFile.fromData(
          MemoryAttachments.pixel,
          mimeType: 'image/png',
          name: 'selected.png',
        );
}

AppData source() {
  final data = buildSeedData();
  return data.copyWith(settings: data.settings.copyWith(ageConfirmed: true));
}

void main() {
  late ImagePickerPlatform original;
  late _Picker picker;
  setUp(() {
    original = ImagePickerPlatform.instance;
    picker = _Picker();
    ImagePickerPlatform.instance = picker;
  });
  tearDown(() => ImagePickerPlatform.instance = original);

  testWidgets(
    'profile upload previews locally and updates drawer and stored avatar only on Save',
    (tester) async {
      final files = MemoryAttachments();
      final container = await shared.start(
        tester,
        source(),
        overrides: [attachmentStoreProvider.overrideWithValue(files)],
      );
      container.read(appRouterProvider).push('/profile');
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DtAvatarEditor));
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await tester.tap(find.text('从相册选择'));
        await Future<void>.delayed(const Duration(milliseconds: 800));
      });
      await tester.pumpAndSettle();
      expect(find.text('正在处理图片…'), findsNothing);
      expect(find.textContaining('无法读取图片'), findsNothing);
      await tester.pumpAndSettle();
      expect(
        container.read(appControllerProvider).data.owner.avatarReference,
        isNull,
      );
      expect(files.files, isEmpty);
      await tester.scrollUntilVisible(
        find.text('保存资料'),
        160,
        scrollable: find
            .descendant(
              of: find.byType(ListView).last,
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.tap(find.text('保存资料'));
      await tester.pumpAndSettle();
      final reference = container
          .read(appControllerProvider)
          .data
          .owner
          .avatarReference!;
      expect(files.files[reference], isNotNull);
      expect(find.byKey(ValueKey('avatar-$reference')), findsWidgets);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      container.dispose();
    },
  );

  testWidgets(
    'leaving unsaved avatar and picker cancellation persist no images',
    (tester) async {
      final files = MemoryAttachments();
      final container = await shared.start(
        tester,
        source(),
        overrides: [attachmentStoreProvider.overrideWithValue(files)],
      );
      final router = container.read(appRouterProvider);
      router.push('/profile');
      await tester.pumpAndSettle();
      picker.cancel = true;
      await tester.tap(find.byType(DtAvatarEditor));
      await tester.pumpAndSettle();
      await tester.tap(find.text('从相册选择'));
      await tester.pumpAndSettle();
      router.pop();
      await tester.pumpAndSettle();
      expect(files.files, isEmpty);
      expect(
        container.read(appControllerProvider).data.owner.avatarReference,
        isNull,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      container.dispose();
    },
  );

  testWidgets(
    'remove character avatar persists and all chat surfaces fall back',
    (tester) async {
      final files = MemoryAttachments()
        ..files['existing-avatar'] = MemoryAttachments.pixel;
      final initial = source();
      final data = initial.copyWith(
        characters: [
          for (final c in initial.characters)
            c.id == 'char_gu'
                ? c.copyWith(avatarReference: 'existing-avatar')
                : c,
        ],
      );
      final container = await shared.start(
        tester,
        data,
        overrides: [attachmentStoreProvider.overrideWithValue(files)],
      );
      container.read(appRouterProvider).push('/character-editor/char_gu');
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DtAvatarEditor));
      await tester.pumpAndSettle();
      await tester.tap(find.text('移除头像'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('保存角色'),
        250,
        scrollable: find
            .descendant(
              of: find.byType(ListView).last,
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.tap(find.text('保存角色'));
      await tester.pumpAndSettle();
      expect(
        container
            .read(appControllerProvider)
            .data
            .characters
            .first
            .avatarReference,
        isNull,
      );
      expect(files.deleted, contains('existing-avatar'));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      container.dispose();
    },
  );

  testWidgets(
    'relationship persona avatar appears in user bubbles, character avatar in reply',
    (tester) async {
      final files = MemoryAttachments()
        ..files['character-avatar'] = MemoryAttachments.pixel
        ..files['persona-avatar'] = MemoryAttachments.pixel;
      final initial = source();
      final data = initial.copyWith(
        personas: [
          for (final p in initial.personas)
            p.copyWith(avatarReference: 'persona-avatar'),
        ],
        characters: [
          for (final c in initial.characters)
            c.copyWith(avatarReference: 'character-avatar'),
        ],
      );
      final container = await shared.start(
        tester,
        data,
        overrides: [attachmentStoreProvider.overrideWithValue(files)],
      );
      container.read(appRouterProvider).push('/chat/thread_gu');
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('avatar-character-avatar')),
        findsWidgets,
      );
      expect(find.byKey(const ValueKey('avatar-persona-avatar')), findsWidgets);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      container.dispose();
    },
  );

  testWidgets('chat tools remain reachable while composing a draft', (
    tester,
  ) async {
    final container = await shared.start(tester, source());
    container.read(appRouterProvider).push('/chat/thread_gu');
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText).last, '还没有发出的草稿');
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('更多功能'));
    await tester.pumpAndSettle();
    expect(find.text('识别图片文字'), findsOneWidget);
    expect(find.text('开启联网搜索'), findsOneWidget);
    expect(find.text('语音转文字'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    container.dispose();
  });

  testWidgets(
    'avatar missing file or corrupt image falls back without breaking layout',
    (tester) async {
      final files = MemoryAttachments()
        ..files['bad-avatar'] = ImageContent(
          MemoryAttachments.pixel,
          'image/png',
        ).bytes;
      final initial = source();
      final data = initial.copyWith(
        owner: initial.owner.copyWith(avatarReference: 'missing-file'),
      );
      final container = await shared.start(
        tester,
        data,
        overrides: [attachmentStoreProvider.overrideWithValue(files)],
      );
      expect(find.byType(DtAvatar), findsWidgets);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      container.dispose();
    },
  );
}
