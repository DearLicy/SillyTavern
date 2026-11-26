import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract interface class ApiKeyStore {
  Future<String?> read({required bool persistent});

  Future<void> write(String value, {required bool persistent});

  Future<void> clear();
}

class ProviderKeyStore implements ApiKeyStore {
  ProviderKeyStore({this.storageKey = 'sillytavern.provider.apiKey'});

  final String storageKey;
  String get _webKey => '$storageKey.web';
  static final FlutterSecureStorage _secure = const FlutterSecureStorage();

  String? _sessionKey;

  @override
  Future<String?> read({required bool persistent}) async {
    if (kIsWeb) {
      if (!persistent) return _sessionKey;
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_webKey);
    }
    if (!persistent) return _sessionKey;
    return _secure.read(key: storageKey);
  }

  @override
  Future<void> write(String value, {required bool persistent}) async {
    if (kIsWeb) {
      _sessionKey = value;
      final prefs = await SharedPreferences.getInstance();
      if (persistent) {
        await prefs.setString(_webKey, value);
      } else {
        await prefs.remove(_webKey);
      }
      return;
    }
    _sessionKey = value.isEmpty ? null : value;
    if (!persistent || value.isEmpty) {
      await _secure.delete(key: storageKey);
    } else {
      await _secure.write(key: storageKey, value: value);
    }
  }

  @override
  Future<void> clear() async {
    _sessionKey = null;
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_webKey);
      return;
    }
    await _secure.delete(key: storageKey);
  }
}
