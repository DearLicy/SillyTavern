part of 'app_controller.dart';

/// World Book and Author's Note management. Pure local data, no network calls.
extension WorldBookManagement on AppController {
  Future<void> saveWorldBook(WorldBook book, {bool create = false}) async {
    final before = _snapshot.data;
    final exists = before.worldBooks.any((e) => e.id == book.id);
    if (create || !exists) {
      if (exists) throw StateError('世界书已存在');
      await _saveManagementChange(
        before,
        before.copyWith(worldBooks: [...before.worldBooks, book]),
      );
      return;
    }
    await _saveManagementChange(
      before,
      before.copyWith(
        worldBooks: [
          for (final item in before.worldBooks)
            item.id == book.id ? book : item,
        ],
      ),
    );
  }

  Future<void> deleteWorldBook(String id) async {
    final before = _snapshot.data;
    if (!before.worldBooks.any((e) => e.id == id)) return;
    await _saveManagementChange(
      before,
      before.copyWith(
        worldBooks: before.worldBooks.where((e) => e.id != id).toList(),
      ),
    );
  }
}
