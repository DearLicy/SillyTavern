import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../domain/models.dart';
import 'local_store_base.dart';

class IoLocalDataStore implements LocalDataStore {
  Database? _database;

  Future<Database> get _db async {
    final existing = _database;
    if (existing != null) return existing;
    final root = await getDatabasesPath();
    final db = await openDatabase(
      p.join(root, 'sillytavern_v2.db'),
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE app_state (
            id INTEGER PRIMARY KEY,
            payload TEXT NOT NULL,
            updated_at INTEGER NOT NULL
          )
        ''');
        await db.execute('''
          CREATE VIRTUAL TABLE memory_fts USING fts5(
            memory_id UNINDEXED,
            title,
            content
          )
        ''');
      },
    );
    _database = db;
    return db;
  }

  @override
  Future<AppData?> load() async {
    final db = await _db;
    final rows = await db.query(
      'app_state',
      columns: ['payload'],
      where: 'id = ?',
      whereArgs: [1],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final payload = rows.first['payload'] as String?;
    if (payload == null || payload.isEmpty) return null;
    return AppData.decode(payload);
  }

  @override
  Future<void> save(AppData data) async {
    final db = await _db;
    await db.transaction((txn) async {
      await txn.insert('app_state', {
        'id': 1,
        'payload': data.encode(),
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      await txn.delete('memory_fts');
      for (final memory in data.memories) {
        await txn.insert('memory_fts', {
          'memory_id': memory.id,
          'title': memory.title,
          'content': memory.content,
        });
      }
    });
  }

  @override
  Future<void> clear() async {
    final db = await _db;
    await db.transaction((txn) async {
      await txn.delete('app_state');
      await txn.delete('memory_fts');
    });
  }
}
