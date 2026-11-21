part of 'app_controller.dart';

extension PortableBackup on AppController {
  Future<String> exportPortableBackup() async {
    await flush();
    final snapshot = _snapshot.data;
    final files = <String, String>{};
    var total = 0;
    for (final reference in snapshot.attachmentReferences) {
      final bytes = await _attachmentStore?.readImage(reference);
      if (bytes == null) throw StateError('部分附件已丢失，无法生成完整备份。请先移除失效图片或头像。');
      total += bytes.length;
      if (total > 48 * 1024 * 1024) {
        throw StateError('附件超过 48 MB，暂不支持复制到剪贴板，请先减少图片。');
      }
      files[reference] = base64Encode(bytes);
    }
    return jsonEncode({
      'format': 'dreamtide.media.v1',
      'data': snapshot.toJson(),
      'attachments': files,
    });
  }

  Future<void> _importPortableBackup(Map<String, dynamic> envelope) async {
    final epoch = _lifecycleGeneration;
    final raw = envelope['data'];
    final files = envelope['attachments'];
    if (raw is! Map || files is! Map || files.length > 2000) {
      throw const FormatException('备份格式不正确');
    }
    final data = AppData.fromJson(Map<String, dynamic>.from(raw));
    if (data.schemaVersion != 2) throw const FormatException('只支持 V2 备份');
    final decoded = <String, ImageContent>{};
    var total = 0;
    for (final reference in data.attachmentReferences) {
      final encoded = files[reference];
      if (encoded is! String) throw const FormatException('备份缺少附件，未修改当前数据');
      if (encoded.length > 14 * 1024 * 1024) {
        throw const FormatException('备份单个附件过大');
      }
      final bytes = base64Decode(encoded);
      total += bytes.length;
      if (total > 48 * 1024 * 1024) throw const FormatException('备份附件超过 48 MB');
      decoded[reference] = ImageContent.parse(bytes);
    }
    final store = _attachmentStore;
    if (decoded.isNotEmpty && store == null) throw StateError('附件存储不可用');
    final replacements = <String, String>{};
    try {
      for (final entry in decoded.entries) {
        replacements[entry.key] = await store!.saveImage(
          id: 'restore_${_uuid.v4()}',
          bytes: entry.value.bytes,
          mimeType: entry.value.mimeType,
        );
      }
      if (!mounted || epoch != _lifecycleGeneration) {
        throw StateError('数据已变化，请重试恢复。');
      }
      // Remap only known local reference fields, never arbitrary user text.
      final json = data.toJson();
      void mapAvatar(dynamic item) {
        if (item is Map && item['avatarReference'] is String) {
          item['avatarReference'] = replacements[item['avatarReference']];
        }
      }

      mapAvatar(json['owner']);
      for (final item in json['personas'] as List) {
        mapAvatar(item);
      }
      for (final item in json['characters'] as List) {
        mapAvatar(item);
      }
      for (final message in json['messages'] as List) {
        if (message is Map && message['localPath'] is String) {
          message['localPath'] = replacements[message['localPath']];
        }
      }
      final restored = AppData.fromJson(json);
      await _withBackupProvider(restored, () async {
        ++_generation;
        ++_lifecycleGeneration;
        _summaryRetryAfter.clear();
        _snapshot = _snapshot.copyWith(clearGenerating: true);
        final before = _snapshot.data;
        await _saveManagementChange(before, restored);
      });
    } catch (_) {
      // Do not remove references already accepted into the live state.
      for (final reference in replacements.values) {
        if (!mounted ||
            !_snapshot.data.attachmentReferences.contains(reference)) {
          await store?.delete(reference);
        }
      }
      rethrow;
    }
  }
}
