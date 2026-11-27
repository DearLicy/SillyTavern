import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';

import '../../application/app_controller.dart';
import '../../data/png_character_card.dart';
import '../components/dt_controls.dart';
import '../components/dt_detail_page.dart';
import '../components/dt_edit_sheet.dart';

class CharacterCardsPage extends ConsumerWidget {
  const CharacterCardsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appControllerProvider);
    final controller = ref.read(appControllerProvider.notifier);
    final characters = state.data.characters;
    return DtDetailPage(
      title: '角色卡',
      subtitle: 'SillyTavern V2 JSON / PNG 导入与导出',
      actions: [
        DtIconButton(
          icon: Icons.file_download_outlined,
          tooltip: '导入角色卡',
          onTap: () => _showImport(context, controller),
        ),
      ],
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DtSurface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '角色卡兼容',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                const Text(
                  '支持 SillyTavern Character Card V2 JSON 和 PNG 元数据。导入时读取角色资料、首个问候、标签和 character_book 世界书；不会执行卡片里的脚本或远程资源。',
                  style: TextStyle(fontSize: 13, height: 1.6),
                ),
                const SizedBox(height: 12),
                DtButton(
                  label: '从剪贴板导入 JSON',
                  icon: Icons.content_paste_go_rounded,
                  onPressed: () => _showImport(context, controller),
                ),
                const SizedBox(height: 10),
                DtButton(
                  label: '选择 PNG 角色卡',
                  variant: DtButtonVariant.secondary,
                  icon: Icons.image_outlined,
                  onPressed: () => _pickPng(context, controller),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (characters.isEmpty)
            DtEmptyState(
              icon: Icons.badge_outlined,
              title: '还没有角色',
              body: '创建角色或导入一张 SillyTavern 角色卡。',
              action: DtButton(
                label: '创建角色',
                onPressed: () => context.push('/character/new'),
              ),
            )
          else
            for (final character in characters)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: DtSurface(
                  child: DtSettingRow(
                    icon: Icons.badge_outlined,
                    title: character.name,
                    subtitle: character.tags.isEmpty
                        ? '无标签 · ${character.handle}'
                        : '${character.tags.join('、')} · ${character.handle}',
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        DtIconButton(
                          icon: Icons.image_outlined,
                          tooltip: '导出 PNG 角色卡',
                          onTap: () => _exportPng(
                            context,
                            controller,
                            character.id,
                            character.name,
                          ),
                        ),
                        DtIconButton(
                          icon: Icons.copy_all_outlined,
                          tooltip: '复制角色卡 JSON',
                          onTap: () => _copyJson(context, controller, character.id),
                        ),
                      ],
                    ),
                    onTap: () => context.push('/character/${character.id}'),
                  ),
                ),
              ),
        ],
      ),
    );
  }

  Future<void> _copyJson(
    BuildContext context,
    AppController controller,
    String characterId,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final json = controller.exportCharacterCard(characterId);
      await Clipboard.setData(ClipboardData(text: json));
      messenger.showSnackBar(
        const SnackBar(content: Text('角色卡 JSON 已复制')),
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('导出失败，请重试')),
      );
    }
  }

  Future<void> _exportPng(
    BuildContext context,
    AppController controller,
    String characterId,
    String characterName,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final pngBytes = await controller.exportPngCharacterCard(characterId);
      final safeName = characterName
          .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
          .trim();
      final fileName =
          '${safeName.isEmpty ? 'character' : safeName}_SillyTavernCard.png';
      final box = context.findRenderObject() as RenderBox?;
      final origin = box == null
          ? null
          : box.localToGlobal(Offset.zero) & box.size;
      final result = await SharePlus.instance.share(
        ShareParams(
          files: [XFile.fromData(pngBytes, mimeType: 'image/png')],
          fileNameOverrides: [fileName],
          subject: '$characterName 角色卡',
          text: '由 SillyTavern APP 导出的角色卡',
          sharePositionOrigin: origin,
        ),
      );
      if (!context.mounted) return;
      if (result.status == ShareResultStatus.unavailable) {
        final kb = (pngBytes.length / 1024).toStringAsFixed(1);
        messenger.showSnackBar(
          SnackBar(
            content: Text('当前环境不支持系统分享，PNG 已生成 ($kb KB)。可改用复制 JSON。'),
            action: SnackBarAction(
              label: '复制 JSON',
              onPressed: () => _copyJson(context, controller, characterId),
            ),
          ),
        );
      }
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('PNG 导出失败：$error')),
      );
    }
  }

  Future<void> _showImport(
    BuildContext context,
    AppController controller, {
    String initialText = '',
  }) {
    return showDtEditSheet(
      context: context,
      title: '导入角色卡',
      description:
          '粘贴 SillyTavern Character Card V2 JSON。导入会新增角色和一段关系，不会覆盖现有角色。',
      actionLabel: '导入',
      initialText: initialText,
      onSubmit: (text) async {
        await controller.importCharacterCard(text);
      },
    );
  }

  Future<void> _pickPng(BuildContext context, AppController controller) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        requestFullMetadata: false,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      final json = const PngCharacterCard().extractJson(bytes);
      if (!context.mounted) return;
      await _showImport(context, controller, initialText: json);
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            error is FormatException ? error.message : 'PNG 角色卡读取失败，请检查文件。',
          ),
        ),
      );
    }
  }
}
