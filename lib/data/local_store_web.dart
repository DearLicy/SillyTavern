import 'package:shared_preferences/shared_preferences.dart';

import '../domain/models.dart';
import 'local_store_base.dart';

class WebLocalDataStore implements LocalDataStore {
  static const _key = 'sillytavern.v2.state';

  @override
  Future<AppData?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return null;
    return AppData.decode(raw);
  }

  @override
  Future<void> save(AppData data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, data.encode());
  }

  @override
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
