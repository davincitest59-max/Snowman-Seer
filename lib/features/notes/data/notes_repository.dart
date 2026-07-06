import 'dart:convert';

import '../../../core/database/app_database.dart';
import '../domain/note.dart';

class NotesRepository {
  const NotesRepository(this._database);

  final AppDatabase _database;

  Future<Note> create({
    required String title,
    required String content,
    required String folder,
    String imagePath = '',
    List<String> imagePaths = const [],
  }) async {
    final updatedAt = DateTime.now();
    final storedImagePaths = _encodeImagePaths(
      imagePath: imagePath,
      imagePaths: imagePaths,
    );
    final id = await _database.db.insert('notes', {
      'title': title,
      'content': content,
      'folder': folder,
      'pinned': 0,
      'image_path': storedImagePaths,
      'updated_at': updatedAt.toIso8601String(),
    });
    return Note(
      id: id,
      title: title,
      content: content,
      folder: folder,
      pinned: false,
      imagePaths: _decodeImagePaths(storedImagePaths),
      updatedAt: updatedAt,
    );
  }

  Future<List<Note>> listRecent() async {
    final rows = await _database.db.query(
      'notes',
      orderBy: 'pinned DESC, updated_at DESC',
    );
    return rows.map(_fromRow).toList();
  }

  Future<void> update({
    required int id,
    required String title,
    required String content,
    required String folder,
    String imagePath = '',
    List<String> imagePaths = const [],
  }) async {
    final storedImagePaths = _encodeImagePaths(
      imagePath: imagePath,
      imagePaths: imagePaths,
    );
    await _database.db.update(
      'notes',
      {
        'title': title,
        'content': content,
        'folder': folder,
        'image_path': storedImagePaths,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> setPinned(int id, bool pinned) async {
    await _database.db.update(
      'notes',
      {
        'pinned': pinned ? 1 : 0,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Note>> search(String keyword) async {
    final query = keyword.trim();
    if (query.isEmpty) return listRecent();
    final rows = await _database.db.query(
      'notes',
      where: 'title LIKE ? OR content LIKE ? OR folder LIKE ?',
      whereArgs: ['%$query%', '%$query%', '%$query%'],
      orderBy: 'pinned DESC, updated_at DESC',
    );
    return rows.map(_fromRow).toList();
  }

  Future<void> delete(int id) async {
    await _database.db.delete('notes', where: 'id = ?', whereArgs: [id]);
  }

  Note _fromRow(Map<String, Object?> row) {
    return Note(
      id: row['id'] as int,
      title: row['title'] as String,
      content: row['content'] as String,
      folder: row['folder'] as String,
      pinned: row['pinned'] == 1,
      imagePaths: _decodeImagePaths(row['image_path'] as String? ?? ''),
      updatedAt: DateTime.parse(row['updated_at'] as String),
    );
  }

  String _encodeImagePaths({
    required String imagePath,
    required List<String> imagePaths,
  }) {
    final normalized = imagePaths
        .map((path) => path.trim())
        .where((path) => path.isNotEmpty)
        .toList();
    if (normalized.length > 1) return jsonEncode(normalized);
    if (normalized.length == 1) return normalized.single;
    return imagePath.trim();
  }

  List<String> _decodeImagePaths(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return const [];
    if (!trimmed.startsWith('[')) return [trimmed];
    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is! List) return [trimmed];
      return decoded
          .whereType<String>()
          .map((path) => path.trim())
          .where((path) => path.isNotEmpty)
          .toList();
    } on FormatException {
      return [trimmed];
    }
  }
}
