import 'dart:convert';
import 'dart:typed_data';
import 'package:sillytavern_app/data/attachment_store_base.dart';
import 'package:sillytavern_app/data/local_store_base.dart';
import 'package:sillytavern_app/data/provider_key_store.dart';
import 'package:sillytavern_app/domain/models.dart';

class FakeStore implements LocalDataStore {
  FakeStore([this.data]);
  AppData? data;
  @override
  Future<AppData?> load() async => data;
  @override
  Future<void> save(AppData value) async {
    data = value;
  }

  @override
  Future<void> clear() async {
    data = null;
  }
}

class FakeKeyStore extends ProviderKeyStore {
  String? value;
  @override
  Future<String?> read({required bool persistent}) async => value;
  @override
  Future<void> write(String value, {required bool persistent}) async {
    this.value = value;
  }

  @override
  Future<void> clear() async {
    value = null;
  }
}

class MemoryAttachments implements AttachmentStore {
  static final pixel = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
  );
  final files = <String, Uint8List>{};
  final deleted = <String>[];
  @override
  Future<void> clear() async => files.clear();
  @override
  Future<void> delete(String reference) async {
    files.remove(reference);
    deleted.add(reference);
  }

  @override
  Future<Uint8List?> readImage(String reference) async => files[reference];
  @override
  Future<String> saveImage({
    required String id,
    required Uint8List bytes,
    required String mimeType,
  }) async {
    files[id] = bytes;
    return id;
  }
}
