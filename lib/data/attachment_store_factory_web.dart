import 'dart:typed_data';

import 'package:idb_shim/idb_browser.dart';

import 'attachment_store_base.dart';

AttachmentStore createAttachmentStore() => _WebAttachmentStore();

class _WebAttachmentStore implements AttachmentStore {
  static const _databaseName = 'sillytavern.attachments';
  static const _storeName = 'images';
  Database? _database;

  Future<Database> _open() async {
    final existing = _database;
    if (existing != null) return existing;
    final database = await idbFactoryBrowser.open(
      _databaseName,
      version: 1,
      onUpgradeNeeded: (event) {
        final db = event.database;
        if (!db.objectStoreNames.contains(_storeName)) {
          db.createObjectStore(_storeName);
        }
      },
    );
    _database = database;
    return database;
  }

  @override
  Future<String> saveImage({
    required String id,
    required Uint8List bytes,
    required String mimeType,
  }) async {
    final db = await _open();
    final transaction = db.transaction(_storeName, idbModeReadWrite);
    await transaction.objectStore(_storeName).put({
      'bytes': bytes,
      'mimeType': mimeType,
    }, id);
    await transaction.completed;
    return id;
  }

  @override
  Future<Uint8List?> readImage(String reference) async {
    final db = await _open();
    final transaction = db.transaction(_storeName, idbModeReadOnly);
    final value = await transaction
        .objectStore(_storeName)
        .getObject(reference);
    await transaction.completed;
    if (value is! Map) return null;
    final bytes = value['bytes'];
    if (bytes is Uint8List) return bytes;
    if (bytes is List) {
      return Uint8List.fromList(bytes.whereType<int>().toList());
    }
    return null;
  }

  @override
  Future<void> delete(String reference) async {
    final db = await _open();
    final transaction = db.transaction(_storeName, idbModeReadWrite);
    await transaction.objectStore(_storeName).delete(reference);
    await transaction.completed;
  }

  @override
  Future<void> clear() async {
    final db = await _open();
    final transaction = db.transaction(_storeName, idbModeReadWrite);
    await transaction.objectStore(_storeName).clear();
    await transaction.completed;
  }
}
